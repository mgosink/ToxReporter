#!/usr/bin/perl -I..

################################################################
#
#  Author(s) - Mark M. Gosink, Ph.D.
#  Company -   DSRD, Pfizer Inc.
#
#  Creation Date - Mon Mar 16 11:20:50 EDT 2009
#  Modified - 
#
#  Function - Create Insert statements to load Gene table,
#					load it, and then export Entrez to idGene table
#
################################################################

use conf::ToxGene_Defaults;

use DBI;

use Getopt::Long;

$result = GetOptions ('user=s'		=> \$username,
								'pass=s'		=> \$password);
if (($username eq "") || ($password eq "")) {
	die "\nUSAGE:\n\t$0 -u(ser) username -p(ass) password\n\n";
}

$entrez2geneid = './tmp_files/Entrez_2_idGene.tmp';

$date = `date`;
chomp($date);
log_err("Running '$0' on '$date'.");

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

#	Required files
$homolog_info_file = $SetupFiles{HOMOLOGENE};

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

#	Create entries into the Homolog table for just genes in ToxGene
$sql_file = './tmp_files/homologene_1.sql';
%Seenbefore = ();
open(OUTFILE, ">$sql_file");
print OUTFILE "use $db_name;\n";
print OUTFILE "SET autocommit=0;\n";
print OUTFILE "START TRANSACTION;\n";
open (FILE, $homolog_info_file);
while ($line = <FILE>) {
	if ($line =~ /^#/) { next }	#	skip comment lines
	chomp($line);
	my ($homologene_id, $tax_id, $entrez, undef) = split(/\t/, $line);
	if ($Seenbefore{$homologene_id} eq 'T') { next }	#	skip homologs already inserted
	if (not defined $Species{$tax_id}) { next }			#	skip other species
	if ($entrez !~ /^\d+$/) { next }							#	skip non-Entrez IDs
	if (not defined $Entrez2Gene{$entrez}) { next }		#	skip homologenes with no entrez in ToxGene
	print OUTFILE "INSERT INTO Homolog (HomoloGene_ID) VALUES ('$homologene_id');\n";
	$Seenbefore{$homologene_id} = 'T';
}
print OUTFILE "COMMIT;\n";
close(OUTFILE);
close(FILE);
$date = `date`;
chomp($date);
log_err("\t... loading '$sql_file' on '$date'.");
$cmd = $mysql_cmd . ' < ' . $sql_file;
`$cmd`;

#	Load a hash of HomoloGene_ID's to ToxGene idHomolog's
%Homolo_2_id_Homol = ();
my $sql = "SELECT HomoloGene_ID, idHomolog FROM Homolog";
$statement = $db_handle->prepare($sql);
$statement->execute();
while(@row = $statement->fetchrow_array) {
	$Homolo_2_id_Homol{$row[0]} = $row[1];
}

$statement->finish;
$db_handle->disconnect;

#	Update Gene table to reflect Homolog entries
$sql_file = './tmp_files/homologene_2.sql';
open(OUTFILE, ">$sql_file");
print OUTFILE "use $db_name;\n";
print OUTFILE "SET autocommit=0;\n";
print OUTFILE "START TRANSACTION;\n";
open (FILE, $homolog_info_file);
while ($line = <FILE>) {
	if ($line =~ /^#/) { next }	#	skip comment lines
	chomp($line);
	my ($homologene_id, $tax_id, $entrez, undef) = split(/\t/, $line);
	if (not defined $Species{$tax_id}) { next }					#	skip other species
	if ($entrez !~ /^\d+$/) { next }									#	skip non-Entrez IDs
	if (not defined $Entrez2Gene{$entrez}) { next }				#	skip homologenes with no homolog in ToxGene
	if (not defined $Homolo_2_id_Homol{$homologene_id}) {		#	skip homologenes with no homolog in ToxGene
		log_err("ERROR ($0) - Couldn't find '$homologene_id' in lookup table.");
		next;
	}
	my $gene_id = $Entrez2Gene{$entrez};
	my $homo_id = $Homolo_2_id_Homol{$homologene_id};
	print OUTFILE "UPDATE Gene SET idHomolog = '$homo_id' WHERE idGene = '$gene_id';\n"
}
print OUTFILE "COMMIT;\n";
close(OUTFILE);
close(FILE);
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
