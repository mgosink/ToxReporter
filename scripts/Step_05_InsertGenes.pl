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

$result = GetOptions ('user=s'			=> \$username,
								'pass=s'			=> \$password);
if (($username eq "") || ($password eq "")) {
	die "\nUSAGE:\n\t$0 -u(ser) username -p(ass) password -d(bname) database_name\n\n";
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

#	Required files
$gene_info_file = $SetupFiles{GENEINFO};
$genebook_file  = './tmp_files/INTERNAL_GENEID_2_ENTREZ.txt';

$date = `date`;
chomp($date);
log_err("Running '$0' on '$date'.");

#	find the Taxonomy IDs currently in use in the database
my $sql = "SELECT ncbiTaxID, idSpecies FROM Species";
$statement = $db_handle->prepare($sql);
$statement->execute();
while(@row = $statement->fetchrow_array) {
	$Species{$row[0]} = $row[1];
}

#	Gather basic info about genes
%Genes = ();
$short_gene_info = './tmp_files/gene_info.tmp';
open (FILE, $gene_info_file);
open (OUTFILE, ">$short_gene_info");
while ($line = <FILE>) {
	if ($line =~ /^#/) { next }	#	skip comment lines
	chomp($line);
	my ($tax_id, $entrez, $symbol, $locustag, $synonyms, $dbxrefs, $chromosome,
		 $map_location, $description, $type_of_gene, $symbol_from_nomenclature_authority,
		 $full_name_from_nomenclature_authority, $nomenclature_status,
		 $other_designations, $modification_date) = split(/\t/, $line);
	if (not defined $Species{$tax_id}) { next }		#	skip other species
	if ($entrez !~ /^\d+$/) { next }						#	skip non-Entrez IDs
	my $current_species_id = $Species{$tax_id};
	print OUTFILE "$line\n";
	$Genes{$entrez}{SPECIES} = $current_species_id;
}
close(OUTFILE);
close(FILE);

#	associate GeneBook IDs to Entrez IDs
open (FILE, $genebook_file);
while ($line = <FILE>) {
	if ($line =~ /^#/) { next }	#	skip comment lines
	chomp($line);
	my ($gb, $entrez, undef) = split(/\t/, $line);
	if (($gb eq "") || ($gb eq "-")) { next }
	if (not defined $Genes{$entrez}) {
		next;
	}
	$Genes{$entrez}{GENEBOOK} = $gb;
}
close(FILE);

$sql_file = './tmp_files/InsertGenes.sql';
open(OUTFILE, ">$sql_file");
print OUTFILE "use $db_name;\n";
print OUTFILE "SET autocommit=0;\n";
print OUTFILE "START TRANSACTION;\n";
foreach $entrez (keys %Genes) {
	my $species_id = $Genes{$entrez}{SPECIES};
	my $gb_id = $Genes{$entrez}{GENEBOOK};
	if (($entrez != 0) && ($species_id != 0) && ($gb_id ne "")) {
		print OUTFILE "INSERT INTO Gene (entrezID, idSpecies, GeneBook_ID) VALUES ('$entrez', '$species_id', '$gb_id');\n"
	}
	elsif (($entrez != 0) && ($species_id != 0)) {
		print OUTFILE "INSERT INTO Gene (entrezID, idSpecies) VALUES ('$entrez', '$species_id');\n"
	}
	else {
		log_err("ERROR ($0) - missing data Entrez - '$entrez'\tSpecies - '$species_id'\tGeneBook - '$gb_id'");
	}
}
print OUTFILE "COMMIT;\n";
close(OUTFILE);
$date = `date`;
chomp($date);
log_err("\t... loading '$sql_file' on '$date'.");
$cmd = $mysql_cmd . ' < ' . $sql_file;
`$cmd`;

#	build a file linking database IDs to Entrez IDs
$id_hash_file = './tmp_files/Entrez_2_idGene.tmp';
open(OUTFILE, ">$id_hash_file");
my $sql = "SELECT entrezID, idGene FROM Gene";
$statement = $db_handle->prepare($sql);
$statement->execute();
while(@row = $statement->fetchrow_array) {
	print OUTFILE "$row[0]\t$row[1]\n";
}
close(OUTFILE);

$statement->finish;
$db_handle->disconnect;

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
