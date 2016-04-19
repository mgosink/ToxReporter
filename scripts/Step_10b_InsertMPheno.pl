#!/usr/bin/perl -I..

################################################################
#
#  Author(s) - Mark M. Gosink, Ph.D.
#  Company     Pfizer Inc
#
#  Creation Date - March 20, 2009
#  Modified -
#
#  Function - load Mouse Mutant Phenotype classes into ToxGene
#					part 'b' loads the gene to class relationship and
#						the evidence
#
################################################################

use lib ("/home/gosinm/CGI/perl_lib", "/cssi/data/neusentis_data1/cgi/comptoxdev.pfizer.com/perl_lib", ".", "..");

use conf::ToxGene_Defaults;

use DBI;

use Getopt::Long;

$result = GetOptions ('user=s'		=> \$username,
								'pass=s'		=> \$password);
if (($username eq "") || ($password eq "")) {
	die "\nUSAGE:\n\t$0 -u(ser) username -p(ass) password\n\n";
}

#	Required Files
$mouse_phenotypes_file = $SetupFiles{MOUPHENOS};

if ((not(-s $mouse_phenotypes_file)) || (not(-T $mouse_phenotypes_file))) {
	die "\n\tRequired Mouse gene phenotypes file not found or in wrong format at '$mouse_phenotypes_file'!\n\n";
}

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

$date = `date`;
chomp($date);
log_err("Running '$0' on '$date'.");

#	Load a hash of EntrezID's to ToxGene idGene's
%MGI2Gene = ();
my $sql = "SELECT Xref_ID, idGene FROM Xref WHERE Xref_Source = 'MGI'";
$statement = $db_handle->prepare($sql);
$statement->execute();
while (@row = $statement->fetchrow_array) {
	$MGI2Gene{$row[0]} = $row[1];
}

#	build a hash mapping the Phenotype IDs to the database IDs
my %NativeID_to_DBid = ();
my $class_sys_name = make_sql_safe('Mouse Mutant Phenotypes');
my $sql = "SELECT idClass_System FROM Class_System WHERE Class_Sys_Name = '$class_sys_name'";
$statement = $db_handle->prepare($sql);
$statement->execute();
@row = $statement->fetchrow_array;
$class_sys_id = $row[0];
my $sql = "SELECT Class_Native_ID, idClass FROM Class WHERE idClass_System = '$class_sys_id'";
$statement = $db_handle->prepare($sql);
$statement->execute();
while(@row = $statement->fetchrow_array) {
	$NativeID_to_DBid{$row[0]} = $row[1];
}

#	Create and run SQL to load Gene to Class links
$sql_file = './tmp_files/MousePheno_b_1.sql';
open(OUTFILE, ">$sql_file");
print OUTFILE "use $db_name;\n";
print OUTFILE "SET autocommit=0;\n";
print OUTFILE "START TRANSACTION;\n";
%SeenBefore = ();
%SeenIDerrorBefore = ();
open (FILE, $mouse_phenotypes_file);
while ($line = <FILE>) {
	chomp($line);
	my ($allele, $allele_symbol, $strain_bkgrd, $phenotype, $pubmed, $mgi_genes) = split(/\t/, $line);
	my @MGIs = split(/,/, $mgi_genes);
	my $id_class = $NativeID_to_DBid{$phenotype};
	if ($id_class eq "") {
			log_err("ERROR ($0) - Couldn't find MGI Class ID for '$phenotype' in NativeID_to_DBid lookup table.");
			next;	
	}
	foreach $mgi (@MGIs) {
		$mgi =~ s/^MGI://;
		my $id_gene = $MGI2Gene{$mgi};
		if ($id_gene ne "") {
			if ($SeenBefore{$id_gene}{$id_class} ne 'T') {
				print OUTFILE "INSERT INTO Gene_Class (idGene, idClass) VALUES ('$id_gene', '$id_class');\n";
				$SeenBefore{$id_gene}{$id_class} = 'T';
			}
		}
		else {
			if ($SeenIDerrorBefore{$mgi}) { next }
			log_err("ERROR ($0) - Couldn't find MGI ID '$mgi' in MGI2Gene lookup table. Skipping all for this entry.");
			$SeenIDerrorBefore{$mgi} = 'T';
			next;	
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

#	Build a 2D hash to lookup idGene_Class
%GeneClass = ();
my $sql = "SELECT idGene, idClass, idGene_Class FROM Gene_Class;";
$statement = $db_handle->prepare($sql);
$statement->execute();
while(@row = $statement->fetchrow_array) {
	$GeneClass{$row[0]}{$row[1]} = $row[2];
}
$statement->finish;
$db_handle->disconnect;


#	Create and run SQL to load evidence for Gene to Class links
$sql_file = './tmp_files/MousePheno_b_2.sql';
open(OUTFILE, ">$sql_file");
print OUTFILE "use $db_name;\n";
print OUTFILE "SET autocommit=0;\n";
print OUTFILE "START TRANSACTION;\n";
open (FILE, $mouse_phenotypes_file);
while ($line = <FILE>) {
	chomp($line);
	my ($allele, $allele_symbol, $strain_bkgrd, $phenotype, $pubmed, $mgi_genes) = split(/\t/, $line);
	my @MGIs = split(/,/, $mgi_genes);
	my $id_class = $NativeID_to_DBid{$phenotype};	
	if ($id_class eq "") {
			log_err("ERROR ($0) - Couldn't find MGI Class ID for '$Vals[2]' in NativeID_to_DBid lookup table.");
			next;	
	}
	foreach $mgi (@MGIs) {
		$mgi =~ s/^MGI://;
		my $id_gene = $MGI2Gene{$mgi};
		if ($id_gene eq '') { next }
		my $id_gene_class = $GeneClass{$id_gene}{$id_class};
		if ($id_gene_class ne "") {
			my $evidence = make_sql_safe("PubMed\|$pubmed\|\|Allele\|$allele\|\|Strain\|$strain_bkgrd");
			$evid_type = 'Mouse_Mutant';
			print OUTFILE "INSERT INTO Class_Evid (idGene_Class, Evid_Type, Evidence, Create_Date, Update_Date)"
								. " VALUES ('$id_gene_class', '$evid_type', '$evidence', NOW(), NOW());\n";
		}
		else {
			log_err("ERROR ($0) - Couldn't find idGene_ClassID for Gene '$id_gene' / Class '$id_class' in GeneClass lookup table.");
			next;	
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

$date = `date`;
chomp($date);
log_err("Finished '$0' on '$date'.");

exit;

sub make_sql_safe {
	my $term = $_[0];
	$term =~ s/\\/\\\\/g;
	$term =~ s/'/\\'/g;
	$term =~ s/"/\\"/g;
	return $term;
}

sub log_err {
	my $msg = $_[0];
	my $log_file = $0 . ".log";
	open (LOG, ">>$log_file");
	print LOG "$msg\n";
	close(LOG);
}
