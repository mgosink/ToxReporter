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

use lib ("/home/gosinm/CGI/perl_lib", "/cssi/data/neusentis_data1/cgi/comptoxdev.pfizer.com/perl_lib", ".", "..");

use conf::ToxGene_Defaults;

use DBI;

use Getopt::Long;

$result = GetOptions ('user=s'			=> \$username,
								'pass=s'			=> \$password,
								'directory=s'	=>	\$large_temp_dir);

if (($username eq "") || ($password eq "") || ($large_temp_dir eq "")) {
	die "\nUSAGE:\n\t$0 -u(ser) username -p(ass) password -f(ile) filename -d(irectory) directory_of_mesh_parsed_medline\n\n";
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
$refseq_2_entrez_file = $SetupFiles{GENE2REF};

$date = `date`;
chomp($date);
log_err("Running '$0' on '$date'.");

$threshold = 5.0;
log_err("\tUsing a frequency threshold of '$threshold'%.");

%Entrez_2_idGene = ();
my $sql = "SELECT entrezID, idGene FROM Gene";
$statement = $db_handle->prepare($sql);
$statement->execute();
while (@row = $statement->fetchrow_array) {
	$Entrez_2_idGene{$row[0]} = $row[1];
}
log_err("\t...finished loading hash 'Entrez_2_idGene'.");
%MRNA_2_Entrez = ();
open (FILE, $refseq_2_entrez_file);
while ($line = <FILE>) {
	$line =~ s/[\n\r\f]+//;
	my @Vals = split(/\t/, $line);
	if ($Vals[0] != 9606) { next }		#	skip non-human

	my $entrez_id = $Vals[1];
	if ($entrez_id !~ /^\d+$/) { next }	#	skip non-integer entrez IDs
	if (not(defined($Entrez_2_idGene{$entrez_id}))) { next }	#	skip entrez IDs not mapping to database entry

	my $mrna = $Vals[3];
	if (($mrna eq '-') || ($mrna eq '')) { next }	#	skip bad mRNA IDs
	$mrna =~ s/(.+)\.\d+$/$1/;		#	remove accession version
	$MRNA_2_Entrez{$mrna} = $entrez_id;
}
close(FILE);
log_err("\t...finished loading hash 'MRNA_2_Entrez'.");

$cmd = 'ls -1 ' . $large_temp_dir . '/ESP6500SI-V2-SSA137.*.chr*.snps_indels.txt';
@Files = split(/\n/, `$cmd`);

#	Load the Genetic Association Database IDs
$sql_file = './tmp_files/HighFreqMisSNPs.sql';
open(OUTFILE, ">$sql_file");
print OUTFILE "use $db_name;\n";
print OUTFILE "SET autocommit=0;\n";
print OUTFILE "START TRANSACTION;\n";
%MissenseSNPs = ();
%SNPGeneSeen = ();
foreach $file (@Files) {
	my $chromo = '';
	if ($file =~ /\.chr([\dXYxy]+)\./) {
		$chromo = $1;
		log_err("\t...working on Chromosome '$chromo' with file '$file'.");
	}
	open(FILE, $file);
	while ($line = <FILE>) {
		$line =~ s/[\n\r\f]//;
		$comment = "";
		if ($line =~ /^#/) { next }		#	skip comment lines
		my @Vals = split(/\s+/, $line);
		my $snp_id = $Vals[1];
		my $maf = $Vals[7];
		my ($euro_maf, $afamer_maf, $global_maf) = split(/\//, $maf);
		my $gene = $Vals[12];
		my $accession = $Vals[13];
		$accession =~ s/(.+)\.\d+$/$1/;		#	remove accession version
		if (not(defined($MRNA_2_Entrez{$accession}))) { next }	#	skip accessions not mapping to database entrez entry
		my $mut_type = $Vals[14];
		my $damaging = $Vals[21];
		if ($mut_type !~ /missense|stop-gained|frameshift/) { next }
		if ($global_maf >= $threshold) { $comment .= " Global MAF is $global_maf for $mut_type SNP\." }
		if ($euro_maf >= $threshold) { $comment .= " European ancestry MAF is $euro_maf for $mut_type SNP\." }
		if ($afamer_maf >= $threshold) { $comment .= " African American MAF is $afamer_maf for $mut_type SNP\." }

		if ($comment ne '') {
			my $id_gene = $Entrez_2_idGene{$MRNA_2_Entrez{$accession}};
			if ($id_gene !~ /^\d+$/) {
				log_err("Can't find an idGene for ACC:$accession // mRNA:$MRNA_2_Entrez{$accession} for SNP:$snp_id");
				next;
			}
			$comment = make_sql_safe("$snp_id - $comment");
			if ($SNPGeneSeen{$id_gene}{$snp_id} eq 'T') { next }
			print OUTFILE "INSERT INTO Annotation(idGene, Annot_Text, Annot_Link, Create_Time) VALUES ('$id_gene', '$comment', 'HIGH_FREQ_MIS_SNP', NOW());\n";
			$SNPGeneSeen{$id_gene}{$snp_id} = 'T';
		}
	}
	close(FILE);
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
