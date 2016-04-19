#!/usr/bin/perl -I..

################################################################
#
#  Author(s) - Mark M. Gosink, Ph.D.
#  Company     Pfizer Inc
#
#  Creation Date - March 17, 2009
#  Modified -
#
#  Function - load Gene Ontology classes into ToxGene
#					part 'b' loads the gene to class relationship and
#						the evidence
#
################################################################

use conf::ToxGene_Defaults;

use DBI;

use Getopt::Long;

$result = GetOptions ('user=s'		=> \$username,
								'pass=s'		=> \$password);
if (($username eq "") || ($password eq "")) {
	die "\nUSAGE:\n\t$0 -u(ser) username -p(ass) password \n\n";
}

#	Required Files
$gene2go_file = $SetupFiles{GENE2GO};

if ((not(-s $gene2go_file)) || (not(-T $gene2go_file))) {
	die "\n\tRequired gene2go file not found or in wrong format at '$gene2go_file'!\n\n";
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
$entrez2geneid = './tmp_files/Entrez_2_idGene.tmp';
$date = `date`;
chomp($date);
log_err("Running '$0' on '$date'.");

#	Load a hash of ToxGene species
my $sql = "SELECT ncbiTaxID, idSpecies FROM Species";
$statement = $db_handle->prepare($sql);
$statement->execute();
while(@row = $statement->fetchrow_array) {
	$Species{$row[0]} = $row[1];
}

#	Load a hash of EntrezID's to ToxGene idGene's
%Entrez2Gene = ();
open(FILE, $entrez2geneid);
while ($line = <FILE>) {
	if ($line =~ /^#/) { next }	#	skip comment lines
	chomp($line);
	my ($entrez, $gene) = split(/\t/, $line);
	$Entrez2Gene{$entrez} = $gene;
}
close(FILE);

#	build a hash mapping the GO IDs to the database IDs
my %NativeID_to_DBid = ();
my $class_sys_name = make_sql_safe('Gene Ontologies');
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
$sql_file = './tmp_files/go_b_1.sql';
open(OUTFILE, ">$sql_file");
print OUTFILE "use $db_name;\n";
print OUTFILE "SET autocommit=0;\n";
print OUTFILE "START TRANSACTION;\n";
%SeenBefore = ();
open (FILE, $gene2go_file);
while ($line = <FILE>) {
	chomp($line);
	my ($tax_id, $entrez, $go_id, $evidence, $qualifier, $go_term, $pubmed_ids, $go_catagory) = split(/\t/, $line);
	$go_id =~ s/^GO:0*//;
	if (not defined $Species{$tax_id}) { next }			#	skip other species
	if ($entrez !~ /^\d+$/) { next }							#	skip non-Entrez IDs
	if (not defined $Entrez2Gene{$entrez}) {		#	skip genes with no entry in ToxGene
		log_err("ERROR ($0) - Couldn't find EntrezID '$entrez' in Entrez2Gene lookup table.");
		next;
	}
	if (not defined $NativeID_to_DBid{$go_id}) {		#	skip go terms with no entry in ToxGene
		log_err("ERROR ($0) - Couldn't find GO ID '$go_id' in NativeID_to_DBid lookup table.");
		next;
	}
	my $id_gene = $Entrez2Gene{$entrez};
	my $id_class = $NativeID_to_DBid{$go_id};
	if ($SeenBefore{$id_gene}{$id_class} ne 'T') {
		print OUTFILE "INSERT INTO Gene_Class (idGene, idClass) VALUES ('$id_gene', '$id_class');\n";
		$SeenBefore{$id_gene}{$id_class} = 'T';
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


#	Create and run SQL to load Gene to Class links
$sql_file = './tmp_files/go_b_2.sql';
open(OUTFILE, ">$sql_file");
print OUTFILE "use $db_name;\n";
print OUTFILE "SET autocommit=0;\n";
print OUTFILE "START TRANSACTION;\n";
open (FILE, $gene2go_file);
while ($line = <FILE>) {
	chomp($line);
	my ($tax_id, $entrez, $go_id, $evid_type, $qualifier, $go_term, $pubmed_ids, $go_catagory) = split(/\t/, $line);
	$go_id =~ s/^GO:0*//;
	if (not defined $Species{$tax_id}) { next }			#	skip other species
	if ($entrez !~ /^\d+$/) { next }							#	skip non-Entrez IDs
	if (not defined $Entrez2Gene{$entrez}) {		#	skip genes with no entry in ToxGene
		log_err("ERROR ($0) - Couldn't find EntrezID '$entrez' in Entrez2Gene lookup table.");
		next;
	}
	if (not defined $NativeID_to_DBid{$go_id}) {		#	skip go terms with no entry in ToxGene
		log_err("ERROR ($0) - Couldn't find GO ID '$go_id' in NativeID_to_DBid lookup table.");
		next;
	}
	my $id_gene = $Entrez2Gene{$entrez};
	my $id_class = $NativeID_to_DBid{$go_id};
	my $id_gene_class = $GeneClass{$id_gene}{$id_class};
	my $evidence = make_sql_safe("$qualifier\|$pubmed_ids");
	$evid_type = make_sql_safe($evid_type);
	print OUTFILE "INSERT INTO Class_Evid (idGene_Class, Evid_Type, Evidence, Create_Date, Update_Date)"
						. " VALUES ('$id_gene_class', '$evid_type', '$evidence', NOW(), NOW());\n";
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
