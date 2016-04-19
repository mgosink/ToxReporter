#!/usr/bin/perl -I..

################################################################
#
#  Author(s) - Mark M. Gosink, Ph.D.
#  Company -   DSRD, Pfizer Inc.
#
#  Creation Date - Mon May 10 13:15:54 EDT 2010
#  Modified - 
#
#  Function - Link gwas catalog data from http://www.genome.gov/gwastudies/
#
################################################################

use conf::ToxGene_Defaults;

use DBI;

use Getopt::Long;

$result = GetOptions ('user=s'			=> \$username,
								'pass=s'			=> \$password,
								'directory=s'	=>	\$parsed_mesh_dir);

#	Required files
$ga_file = $SetupFiles{GWASCATALOG};
$ga_file_list = `ls -l $ga_file`;
$ga_file_list =~ s/[\n\r\f]+//g;

open(FILE, $ga_file);
$line = <FILE>;
$line =~ s/[\n\r\f]+//g;
$update = "";
if ($line =~ /Last update:\s*(\S+)/) { $update = $1 }
$ga_file_desc = "Genome-Wide Association Studys built using file '$ga_file_list' (Updated: $update).";

#	Set up mysql command and DBI mysql connection string
$dsn = "";
$mysql_cmd = "";
$db_name = $MiscVariables{DATABASE_NAME};
if ($MiscVariables{DATABASE_SOCKET} ne '') {
	$dsn = $MiscVariables{DATABASE_TYPE}
		. ':database=' . $MiscVariables{DATABASE_NAME}
		. ':mysql_socket=' . $MiscVariables{DATABASE_SOCKET};
	$mysql_cmd = 'mysql -S' . $MiscVariables{DATABASE_SOCKET} . ' -u' . $username . ' -p' . $password;
}
else {
	$dsn = $MiscVariables{DATABASE_TYPE};
	my $host = $MiscVariables{DATABASE_HOST};
	my $port = $MiscVariables{DATABASE_PORT}
			. ':database=' . $MiscVariables{DATABASE_NAME}
			. ';host=' . $MiscVariables{DATABASE_HOST}
			. ';port=' . $MiscVariables{DATABASE_PORT};
	$mysql_cmd = 'mysql -P' . $port . ' -h' . $host . ' -u' . $username . ' -p' . $password;
}
$db_handle = DBI->connect( $dsn, $username, $password, { PrintError => 1 })
					or die "Can't connect to the database!!\n\n";

if (($username eq "") || ($password eq "") || ($parsed_mesh_dir eq "")) {
	die "\nUSAGE:\n\t$0 -u(ser) username -p(ass) password -f(ile) filename -d(irectory) directory_of_mesh_parsed_medline\n\n";
}

$date = `date`;
chomp($date);
log_err("Running '$0' on '$date'.");

#	Load a hash of EntrezID's to ToxGene idGene's
$entrez2geneid = './tmp_files/Entrez_2_idGene.tmp';
log_err("\t...parsing '$entrez2geneid'.");
%Entrez2Gene = ();
open(FILE, $entrez2geneid);
while ($line = <FILE>) {
	if ($line =~ /^#/) { next }	#	skip comment lines
	chomp($line);
	my ($entrez, $gene) = split(/\t/, $line);
	$Entrez2Gene{$entrez} = $gene;
}
close(FILE);

#	Parse the all.txt file from the Genetic Association DB to find positive associations
%Gene_Assoc = ();
%Entry_2_Disease = ();
%All_PMIDs = ();
open (FILE, $ga_file);
log_err("\t...parsing '$ga_file'.");
$gwas_cntr_id = 0;
$line = <FILE>;
@Headers = split(/\t/, $line);
for ($idx = 0; $idx <= $#Headers; $idx++) {
	if ($Headers[$idx] eq 'PUBMEDID') { $pmid_idx = $idx }
	elsif ($Headers[$idx] eq 'SNP_GENE_IDS') { $intergene_id_idx = $idx }
	elsif ($Headers[$idx] eq 'UPSTREAM_GENE_ID') { $upstream_gene_id_idx = $idx }
	elsif ($Headers[$idx] eq 'DOWNSTREAM_GENE_ID') { $downstream_gene_id_idx = $idx }
	elsif ($Headers[$idx] eq 'FIRST AUTHOR') { $first_author_idx = $idx }
	elsif ($Headers[$idx] eq 'JOURNAL') { $journal_idx = $idx }
	elsif ($Headers[$idx] eq 'STUDY') { $title_idx = $idx }
	elsif ($Headers[$idx] eq 'DISEASE/TRAIT') { $trait_idx = $idx }
	elsif ($Headers[$idx] eq 'P-VALUE') { $pval_idx = $idx }

}
while ($line = <FILE>) {
	if ($line !~ /^\d+/) { next }
	$line =~ s/[\n\r\f]+//g;
	$gwas_cntr_id++;
	my @Vals = split(/\t/, $line);

	my $pmid = $Vals[$pmid_idx];
	my $genet_assoc_id = $pmid . ':' . $gwas_cntr_id;
	my $intergene_id = $Vals[$intergene_id_idx];
	my $upstream_gene_id = $Vals[$upstream_gene_id_idx];
	my $downstream_gene_id = $Vals[$downstream_gene_id_idx];

	my $found_gene_flag = 'F';
	my $marker_location = '';
	if ($intergene_id =~ /^\d+$/) {
		my $gene_id = $Entrez2Gene{$intergene_id};
		if ($gene_id =~ /^\d+$/) {
			$Gene_Assoc{$gene_id}{$genet_assoc_id} = 'T';
			$found_gene_flag = 'T';
			$marker_location = 'internal';
		}
	}
	else {
		my $up_gene = $Entrez2Gene{$upstream_gene_id};
		if ($up_gene =~ /^\d+$/) {
			$Gene_Assoc{$up_gene}{$genet_assoc_id} = 'T';
			$found_gene_flag = 'T';
			$marker_location = 'nearby';
		}
		my $down_gene = $Entrez2Gene{$downstream_gene_id};
		if ($down_gene =~ /^\d+$/) {
			$Gene_Assoc{$down_gene}{$genet_assoc_id} = 'T';
			$found_gene_flag = 'T';
			$marker_location = 'nearby';
		}
	}
	if ($found_gene_flag eq 'F') { next }

	$All_PMIDs{$pmid} = 'T';
	my $first_author = $Vals[$first_author_idx];
	my $journal = $Vals[$journal_idx];
	my $title = $Vals[$title_idx];
	my $trait = $Vals[$trait_idx];
	my $pval = $Vals[$pval_idx];
	$Entry_2_Disease{$genet_assoc_id}{PMID} = $pmid;
	$Entry_2_Disease{$genet_assoc_id}{REFERENCE} = "$first_author found '$trait' associated with $marker_location GWAS peak (p-val:$pval) in '$title' ($journal)";

}
close(FILE);

%ToxNative_2_ID = ();
my $sql = "SELECT Tox_Native_ID, idToxTerm FROM ToxTerm";
$statement = $db_handle->prepare($sql);
$statement->execute;
while (@row = $statement->fetchrow_array) {
	$ToxNative_2_ID{$row[0]} = $row[1];
}

%ClassName_2_ToxID = ();
my $sql = "SELECT C.Class_Name, T.idToxTerm FROM ToxLink T, Class C"
				. " WHERE T.Class_idClass = C.idClass"
				. " AND C.idClass_System IN"
				. " (SELECT idClass_System FROM Class_System WHERE Class_Sys_Name = 'MESH Trees')";
$statement = $db_handle->prepare($sql);
$statement->execute;
while (@row = $statement->fetchrow_array) {
	$ClassName_2_ToxID{$row[0]} = $row[1];
}
%PubMed_2_Tox = ();
foreach $classname (keys(%ClassName_2_ToxID)) {
	my $file = $classname;
	$file = $parsed_mesh_dir .'/MESH/' . $file;
	$file =~ s/\s+/_/g;
	if ((-e $file) && (-s $file)) {
		log_err("\t...parsing '$file'.");
		open(FILE, $file);
		while ($line = <FILE>) {
			chomp($line);
			my @Entries = split(/:[mM]\|/, $line);
			foreach $entry (@Entries) {
				if (($entry =~ /^\d+$/) && (defined ($All_PMIDs{$entry}))) {
					$PubMed_2_Tox{$entry}{$ClassName_2_ToxID{$classname}}{$classname} = 'T';
				}
			}
		}
		close(FILE);
	}
}

foreach $genet_assoc_id (keys(%Entry_2_Disease)) {
#	Build $Entry_2_Disease{$genet_assoc_id}{TOXTERMID} using the PMID links and their annotations
	my $pmid = $Entry_2_Disease{$genet_assoc_id}{PMID};
	if (defined $PubMed_2_Tox{$pmid}) {
		foreach $tox_id (keys(%{$PubMed_2_Tox{$pmid}})) {
			my @Mesh_Evid = keys(%{$PubMed_2_Tox{$pmid}{$tox_id}});
			my $evid = $Entry_2_Disease{$genet_assoc_id}{REFERENCE} . "' which is annotated with the MESH term(s): " . join(", ", @Mesh_Evid) . "\n";
			$Entry_2_Disease{$genet_assoc_id}{TOXTERMID}{$tox_id} .= $evid;
		}	
	}
}

#	Create an entry in the Class_System table for MESH
my $class_sys_name = make_sql_safe('Genome-Wide Association Studies');
my $class_sys_desc = make_sql_safe($ga_file_desc);
my $sql = "INSERT INTO Class_System (Class_Sys_Name, Class_Sys_Desc) VALUES ('$class_sys_name', '$class_sys_desc')";
$statement = $db_handle->prepare($sql);
$statement->execute();
my $sql = "SELECT idClass_System FROM Class_System WHERE Class_Sys_Name = '$class_sys_name'";
$statement = $db_handle->prepare($sql);
$statement->execute();
@row = $statement->fetchrow_array;
$class_sys_id = $row[0];
if ($class_sys_id !~ /^\d+$/) { die "Can't find the ID number for '$class_sys_name'\n\n" }

#	Load the Genetic Association Database IDs
$sql_file = './tmp_files/GWAS_1.sql';
open(OUTFILE, ">$sql_file");
print OUTFILE "use $db_name;\n";
print OUTFILE "SET autocommit=0;\n";
print OUTFILE "START TRANSACTION;\n";
foreach $genet_assoc_id (keys %Entry_2_Disease) {
	print OUTFILE "INSERT INTO Class (Class_Name, Class_Native_ID, idClass_System) VALUES ('$genet_assoc_id', '$genet_assoc_id', '$class_sys_id');\n";
}
print OUTFILE "COMMIT;\n";
close(OUTFILE);
$date = `date`;
chomp($date);
log_err("\t... loading '$sql_file' on '$date'.");
$cmd = $mysql_cmd . ' < ' . $sql_file;
`$cmd`;

#	Create a lookup hash table of Gen Assoc IDs to idClass
%NativeClass_2_idClass = ();
my $sql = "SELECT Class_Native_ID, idClass FROM Class WHERE idClass_System = '$class_sys_id'";
$statement = $db_handle->prepare($sql);
$statement->execute;
while (@row = $statement->fetchrow_array) {
	$NativeClass_2_idClass{$row[0]} = $row[1];
}

#	Connect gene to their genetic associations
$sql_file = './tmp_files/GWAS_2.sql';
open(OUTFILE, ">$sql_file");
print OUTFILE "use $db_name;\n";
print OUTFILE "SET autocommit=0;\n";
print OUTFILE "START TRANSACTION;\n";
foreach $gene_id (keys %Gene_Assoc) {
	foreach $genet_assoc_id (keys(%{$Gene_Assoc{$gene_id}})) {
		my $class_id = $NativeClass_2_idClass{$genet_assoc_id};
		print OUTFILE "INSERT INTO Gene_Class (idGene, idClass) VALUES ('$gene_id', '$class_id');\n";
	}
}
print OUTFILE "COMMIT;\n";
close(OUTFILE);
$date = `date`;
chomp($date);
log_err("\t... loading '$sql_file' on '$date'.");
$cmd = $mysql_cmd . ' < ' . $sql_file;
`$cmd`;


#	Connect genetic associations to their toxicities
$sql_file = './tmp_files/GWAS_3.sql';
open(OUTFILE, ">$sql_file");
print OUTFILE "use $db_name;\n";
print OUTFILE "SET autocommit=0;\n";
print OUTFILE "START TRANSACTION;\n";
foreach $genet_assoc_id (keys(%Entry_2_Disease)) {
	my $class_id = $NativeClass_2_idClass{$genet_assoc_id};
	my @ToxIDs = keys(%{$Entry_2_Disease{$genet_assoc_id}{TOXTERMID}});
	foreach $tox_id (@ToxIDs) {
		print OUTFILE "INSERT INTO ToxLink (idToxTerm, Class_idClass) VALUES ('$tox_id', '$class_id');\n";
	}
}
print OUTFILE "COMMIT;\n";
close(OUTFILE);
$date = `date`;
chomp($date);
log_err("\t... loading '$sql_file' on '$date'.");
$cmd = $mysql_cmd . ' < ' . $sql_file;
`$cmd`;


#	Build a 2D hash to lookup idGene_Class
$db_handle = DBI->connect( $dsn, $username, $password, { PrintError => 1 }) or die "Can't connect!!\n\n";
$db_handle->{'mysql_use_result'} = 1;
%ClassTox = ();
$sql = "SELECT Class_idClass, idToxTerm, idToxLink FROM ToxLink;";
$statement = $db_handle->prepare($sql);
$statement->execute();
while(@row = $statement->fetchrow_array) {
	$ClassTox{$row[0]}{$row[1]} = $row[2];
}
$db_handle->{'mysql_use_result'}=0;
$statement->finish;
$db_handle->disconnect;

$sql_file = './tmp_files/GWAS_4.sql';
open(OUTFILE, ">$sql_file");
print OUTFILE "use $db_name;\n";
print OUTFILE "SET autocommit=0;\n";
print OUTFILE "START TRANSACTION;\n";
foreach $genet_assoc_id (keys(%Entry_2_Disease)) {
	my $class_id = $NativeClass_2_idClass{$genet_assoc_id};
	my @ToxIDs = keys(%{$Entry_2_Disease{$genet_assoc_id}{TOXTERMID}});
	foreach $tox_id (@ToxIDs) {
		my $toxlink_id = $ClassTox{$class_id}{$tox_id};
		my @Evids = split(/\n/, $Entry_2_Disease{$genet_assoc_id}{TOXTERMID}{$tox_id});
		foreach $evid (@Evids) {
			$evid = make_sql_safe($evid);
			print OUTFILE "INSERT INTO ToxLink_Evid (idToxLink, Tox_Evidence, Create_Date, Update_Date) VALUES ('$toxlink_id', '$evid', NOW(), NOW());\n";
		}
	}
}
print OUTFILE "COMMIT;\n";
close(OUTFILE);
$date = `date`;
chomp($date);
log_err("\t... loading '$sql_file' on '$date'.");
$cmd = $mysql_cmd . ' < ' . $sql_file;
`$cmd`;

$statement->finish;
$db_handle->disconnect;

$date = `date`;
chomp($date);
log_err("Finished '$0' on '$date'.");

exit;


sub log_err {
	my $msg = $_[0];
	my $log_file = $0 . ".log";
	open (LOG, ">>$log_file");
	print LOG "$msg\n";
	close(LOG);
}

sub make_sql_safe {
	my $term = $_[0];
	$term =~ s/\\/\\\\/g;
	$term =~ s/'/\\'/g;
	$term =~ s/"/\\"/g;
	return $term;
}

