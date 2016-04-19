#!/usr/bin/perl -I..

################################################################
#
#  Author(s) - Mark M. Gosink, Ph.D.
#  Company -   DSRD, Pfizer Inc.
#
#  Creation Date - Mon May 10 13:15:54 EDT 2010
#  Modified - 
#
#  Function - Link OMIM Xrefs to toxicity based on publications cited
#
################################################################

use conf::ToxGene_Defaults;

use DBI;

use Getopt::Long;

$result = GetOptions ('user=s'			=> \$username,
								'pass=s'			=> \$password,
								'directory=s'	=>	\$parsed_mesh_dir);

#	Required files
$ga_file = $SetupFiles{GEN_ASSOC_FILE};
$ga_file_list = `ls -l $ga_file`;
$ga_file_list =~ s/[\n\r\f]+//g;
open(FILE, $ga_file);
$line = <FILE>;
$line =~ s/[\n\r\f]+//g;
$update = "";
if ($line =~ /Last update:\s*(\S+)/) { $update = $1 }
$ga_file_desc = "Genetic Associations built using file '$ga_file_list' (Updated: $update).";

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
while ($line = <FILE>) {
	if ($line !~ /^\d+/) { next }
	$line =~ s/[\n\r\f]+//g;
	my @Vals = split(/\t/, $line);
	my $association = $Vals[1];
	my $locus_num = $Vals[22];
	my $gene_id = "";
	
	if ($association ne 'Y') { next } 	#	skip line with no disease association
	if (not(defined($Entrez2Gene{$locus_num}))) { next } 	#	skip lines with no ToxGene gene entry
	else {
		$gene_id = $Entrez2Gene{$locus_num};
		if ($gene_id !~ /^\d+$/) { next }
	}

	my $genet_assoc_id = $Vals[0];
	$Gene_Assoc{$gene_id}{$genet_assoc_id} = 'T';
	
	my $disease_class = $Vals[3];
	my $mesh_diseases = $Vals[5];
	$Entry_2_Disease{$genet_assoc_id}{DISEASE_CLASS} = $disease_class;
	$Entry_2_Disease{$genet_assoc_id}{MESH_DISEASES} = $mesh_diseases;

	my $pmid = $Vals[13];
	$All_PMIDs{$pmid} = 'T';
	my $title = $Vals[27];
	my $reference = $Vals[12];
	my $journal = $Vals[26];
	$Entry_2_Disease{$genet_assoc_id}{PMID} = $pmid;
	$Entry_2_Disease{$genet_assoc_id}{REFERENCE} = "$title\; $reference\; $journal";

#	my $broad_phenotype = $Vals[2];
#	my $disease_class_code = $Vals[4];
#	my $chromosome = $Vals[6];
#	my $chr_band = $Vals[7];
#	my $gene_symbol = $Vals[8];
#	my $dna_start = $Vals[9];
#	my $dna_end = $Vals[10];
#	my $p_val = $Vals[11];
#	my $allele_author = $Vals[14];
#	my $allele_func = $Vals[15];
#	my $polymorph_class = $Vals[16];
#	my $gene_name = $Vals[17];
#	my $refseq = $Vals[18];
#	my $population = $Vals[19];
#	my $mesh_location = $Vals[20];
#	my $submitter = $Vals[21];
#	my $unigene = $Vals[23];
#	my $narrow_pheno = $Vals[24];
#	my $mol_pheno = $Vals[25];
#	my $rs_num = $Vals[28];
#	my $omim_id = $Vals[29];
#	my $year = $Vals[30];
#	my $conclusion = $Vals[31];
#	my $study_info = $Vals[32];
#	my $env_factor = $Vals[33];
#	my $gi_gene_a = $Vals[34];
#	my $gi_gene_a_allele = $Vals[35];
#	my $gi_gene_b = $Vals[36];
#	my $gi_gene_b_allele = $Vals[37];
#	my $gi_gene_c = $Vals[38];
#	my $gi_gene_c_allele = $Vals[39];
#	my $gi_assoc = $Vals[40];
#	my $gi_comb_env_fact = $Vals[41];
#	my $gi_rel_2_disease = $Vals[42];
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
	$file = $parsed_mesh_dir .'/' . $file;
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
#	Build $Entry_2_Disease{$genet_assoc_id}{TOXTERMID} using the DISEASE_CLASS links
	if ($Entry_2_Disease{$genet_assoc_id}{DISEASE_CLASS} eq 'CANCER') {
		my $evid = "Genetic Association annotated as belonging in the disease class 'CANCER'.\n";
		$Entry_2_Disease{$genet_assoc_id}{TOXTERMID}{$ToxNative_2_ID{'PT:0000021'}} .= $evid;	#	Carcinogenicity
	}
	elsif ($Entry_2_Disease{$genet_assoc_id}{DISEASE_CLASS} eq 'CARDIOVASCULAR') {
		my $evid = "Genetic Association annotated as belonging in the disease class 'CARDIOVASCULAR'.\n";
		$Entry_2_Disease{$genet_assoc_id}{TOXTERMID}{$ToxNative_2_ID{'PT:0000004'}} .= $evid;	#	Cardiovascular_System
	}
	elsif ($Entry_2_Disease{$genet_assoc_id}{DISEASE_CLASS} eq 'DEVELOPMENTAL') {
		my $evid = "Genetic Association annotated as belonging in the disease class 'DEVELOPMENTAL'.\n";
		$Entry_2_Disease{$genet_assoc_id}{TOXTERMID}{$ToxNative_2_ID{'PT:0000010'}} .= $evid;	#	Reproductive_System
	}
	elsif ($Entry_2_Disease{$genet_assoc_id}{DISEASE_CLASS} eq 'REPRODUCTION') {
		my $evid = "Genetic Association annotated as belonging in the disease class 'REPRODUCTION'.\n";
		$Entry_2_Disease{$genet_assoc_id}{TOXTERMID}{$ToxNative_2_ID{'PT:0000010'}} .= $evid;	#	Reproductive_System
	}
	elsif ($Entry_2_Disease{$genet_assoc_id}{DISEASE_CLASS} eq 'IMMUNE') {
		my $evid = "Genetic Association annotated as belonging in the disease class 'IMMUNE'.\n";
		$Entry_2_Disease{$genet_assoc_id}{TOXTERMID}{$ToxNative_2_ID{'PT:0000009'}} .= $evid;	#	Immune_SystemStep_93_LinkGeneticAssoc
	}
	elsif ($Entry_2_Disease{$genet_assoc_id}{DISEASE_CLASS} eq 'INFECTION') {
		my $evid = "Genetic Association annotated as belonging in the disease class 'INFECTION'.\n";
		$Entry_2_Disease{$genet_assoc_id}{TOXTERMID}{$ToxNative_2_ID{'PT:0000009'}} .= $evid;	#	Immune_System
	}
	elsif ($Entry_2_Disease{$genet_assoc_id}{DISEASE_CLASS} eq 'NEUROLOGICAL') {
		my $evid = "Genetic Association annotated as belonging in the disease class 'NEUROLOGICAL'.\n";
		$Entry_2_Disease{$genet_assoc_id}{TOXTERMID}{$ToxNative_2_ID{'PT:0000005'}} .= $evid;	#	Nervous_System
	}
	elsif ($Entry_2_Disease{$genet_assoc_id}{DISEASE_CLASS} eq 'PSYCH') {
		my $evid = "Genetic Association annotated as belonging in the disease class 'PSYCH'.\n";
		$Entry_2_Disease{$genet_assoc_id}{TOXTERMID}{$ToxNative_2_ID{'PT:0000005'}} .= $evid;	#	Nervous_System
	}
	elsif ($Entry_2_Disease{$genet_assoc_id}{DISEASE_CLASS} eq 'RENAL') {
		my $evid = "Genetic Association annotated as belonging in the disease class 'RENAL'.\n";
		$Entry_2_Disease{$genet_assoc_id}{TOXTERMID}{$ToxNative_2_ID{'PT:0000006'}} .= $evid;	#	Renal_System
	}
	elsif ($Entry_2_Disease{$genet_assoc_id}{DISEASE_CLASS} eq 'MITOCHONDRIAL') {
		my $evid = "Genetic Association annotated as belonging in the disease class 'MITOCHONDRIAL'.\n";
		$Entry_2_Disease{$genet_assoc_id}{TOXTERMID}{$ToxNative_2_ID{'PT:0000023'}} .= $evid;	#	Mitochondrial_Toxicity
	}
	elsif ($Entry_2_Disease{$genet_assoc_id}{DISEASE_CLASS} eq 'VISION') {
		my $evid = "Genetic Association annotated as belonging in the disease class 'VISION'.\n";
		$Entry_2_Disease{$genet_assoc_id}{TOXTERMID}{$ToxNative_2_ID{'PT:0000014'}} .= $evid;	#	Ocular
	}
	elsif ($Entry_2_Disease{$genet_assoc_id}{DISEASE_CLASS} eq 'HEMATOLOGICAL') {
		my $evid = "Genetic Association annotated as belonging in the disease class 'HEMATOLOGICAL'.\n";
		$Entry_2_Disease{$genet_assoc_id}{TOXTERMID}{$ToxNative_2_ID{'PT:0000013'}} .= $evid;	#	Hemolymphatic
	}
#	PHARMACOGENOMIC




#	Build $Entry_2_Disease{$genet_assoc_id}{TOXTERMID} using the MESH_DISEASES links
	my $mesh_diseases = $Entry_2_Disease{$genet_assoc_id}{MESH_DISEASES};
	my @MeshDiseases = split(/\|/, $mesh_diseases);
	foreach $mesh_dis (@MeshDiseases) {
		if ($mesh_dis =~ /\S+/) {
			my $tox_id = $ClassName_2_ToxID{$mesh_dis};
			if ($tox_id !~ /\d+/) { log_err("Couldn't find a Pfizer Tox code for '$mesh_dis'.") }
			else {
				my $evid = "Genetic Association annotated as linked to the MESH disease '$mesh_dis'.\n";
				$Entry_2_Disease{$genet_assoc_id}{TOXTERMID}{$tox_id} .= $evid;
			}
		}
	}


#	Build $Entry_2_Disease{$genet_assoc_id}{TOXTERMID} using the PMID links and their annotations
	my $pmid = $Entry_2_Disease{$genet_assoc_id}{PMID};
	if (defined $PubMed_2_Tox{$pmid}) {
		foreach $tox_id (keys(%{$PubMed_2_Tox{$pmid}})) {
			my @Mesh_Evid = keys(%{$PubMed_2_Tox{$pmid}{$tox_id}});
			my $evid = "Genetic Association as described in '" . $Entry_2_Disease{$genet_assoc_id}{REFERENCE} . "' is annotated with the MESH term(s): " . join(", ", @Mesh_Evid) . "\n";
			$Entry_2_Disease{$genet_assoc_id}{TOXTERMID}{$tox_id} .= $evid;
		}	
	}

}


#	Create an entry in the Class_System table for MESH
my $class_sys_name = make_sql_safe('Genetic Association Database');
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
$sql_file = './tmp_files/Genet_Assoc_1.sql';
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
$sql_file = './tmp_files/Genet_Assoc_2.sql';
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
$sql_file = './tmp_files/Genet_Assoc_3.sql';
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

$sql_file = './tmp_files/Genet_Assoc_4.sql';
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

