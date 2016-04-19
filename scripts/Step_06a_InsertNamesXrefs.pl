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

use Getopt::Long;

$result = GetOptions ('user=s'		=> \$username,
								'pass=s'		=> \$password);
if (($username eq "") || ($password eq "")) {
	die "\nUSAGE:\n\t$0 -u(ser) username -p(ass) password -i(d)\n\n";
}

#	Set up mysql command
$mysql_cmd = "";
$db_name = $MiscVariables{DATABASE_NAME};
if ($MiscVariables{DATABASE_SOCKET} ne '') {
	$mysql_cmd = 'mysql -S' . $MiscVariables{DATABASE_SOCKET} . ' -u' . $username . ' -p' . $password;
}
else {
	my $host = $MiscVariables{DATABASE_HOST};
	my $port = $MiscVariables{DATABASE_PORT}
			. ':database=' . $MiscVariables{DATABASE_NAME}
			. ';host=' . $MiscVariables{DATABASE_HOST}
			. ';port=' . $MiscVariables{DATABASE_PORT};
	$mysql_cmd = 'mysql -P' . $port . ' -h' . $host . ' -u' . $username . ' -p' . $password;
}

$entrez2geneid = './tmp_files/Entrez_2_idGene.tmp';
$date = `date`;
chomp($date);
log_err("Running '$0' on '$date'.");

#	Load database IDs
%Entrez2Gene = ();
open(FILE, $entrez2geneid);
while ($line = <FILE>) {
	if ($line =~ /^#/) { next }	#	skip comment lines
	chomp($line);
	my ($entrez, $gene) = split(/\t/, $line);
	$Entrez2Gene{$entrez} = $gene;
}
close(FILE);

%Genes = ();
$short_gene_info = './tmp_files/gene_info.tmp';

$name_sql_file = './tmp_files/InsertNames.sql';
open(NAME_OUTFILE, ">$name_sql_file");
print NAME_OUTFILE "use $db_name;\n";
print NAME_OUTFILE "SET autocommit=0;\n";
print NAME_OUTFILE "START TRANSACTION;\n";
$xref_sql_file = './tmp_files/InsertXref.sql';
open(XREF_OUTFILE, ">$xref_sql_file");
print XREF_OUTFILE "use $db_name;\n";
print XREF_OUTFILE "SET autocommit=0;\n";
print XREF_OUTFILE "START TRANSACTION;\n";
open (FILE, $short_gene_info);
while ($line = <FILE>) {
	if ($line =~ /^#/) { next }	#	skip comment lines
	chomp($line);
	my ($tax_id, $entrez, $symbol, $locustag, $synonyms, $dbxrefs, $chromosome,
		 $map_location, $description, $type_of_gene, $symbol_from_nomenclature_authority,
		 $full_name_from_nomenclature_authority, $nomenclature_status,
		 $other_designations, $modification_date) = split(/\t/, $line);
	my $id_gene = $Entrez2Gene{$entrez};
	if (($entrez !~ /^\d+$/) || ($id_gene !~ /^\d+$/)) { next }						#	skip non-Entrez IDs
	
	if (($symbol ne "") && ($symbol ne "-")) {
		$symbol = make_sql_safe($symbol);
		print NAME_OUTFILE "INSERT INTO Names (idGene, Name, Name_Type) VALUES ('$id_gene', '$symbol', 'Symbol');\n";
	}
	
	if (($synonyms ne "") && ($synonyms ne "-")) {
		my @Aliases = split(/\|/, $synonyms);
		foreach $alias (@Aliases) {
			if (($alias ne "") && ($alias ne "-")) {
				$alias = make_sql_safe($alias);
				print NAME_OUTFILE "INSERT INTO Names (idGene, Name, Name_Type) VALUES ('$id_gene', '$alias', 'Alias');\n";
			}
		}
	}

	if (($description ne "") && ($description ne "-")) {
		my $fullname = $description;
		if (($full_name_from_nomenclature_authority ne "")
			&& ($full_name_from_nomenclature_authority ne "-")) {
				$fullname = $full_name_from_nomenclature_authority;
		}
		$fullname = make_sql_safe($fullname);
		print NAME_OUTFILE "INSERT INTO Names (idGene, Name, Name_Type) VALUES ('$id_gene', '$fullname', 'Name');\n";
	}

	if (($dbxrefs ne "") && ($dbxrefs ne "-")) {
		my @Xrefs = split(/\|/, $dbxrefs);
		foreach $xref (@Xrefs) {
			if (($xref ne "") && ($xref ne "-")) {
				$xref =~ s/MGI:MGI:/MGI:/;
if ($xref !~ /^MGI:/) { next }
				my ($db, $id) = split(/:/, $xref);
				print XREF_OUTFILE "INSERT INTO Xref (idGene, Xref_Source, Xref_ID) VALUES ('$id_gene', '$db', '$id');\n";
			}
		}
	}

}
print XREF_OUTFILE "COMMIT;\n";
print NAME_OUTFILE "COMMIT;\n";
close(XREF_OUTFILE);
close(NAME_OUTFILE);
close(FILE);

$date = `date`;
chomp($date);
log_err("\t... loading '$name_sql_file' on '$date'.");
$cmd = $mysql_cmd . ' < ' . $name_sql_file;
`$cmd`;
$date = `date`;
chomp($date);
log_err("\t... loading '$xref_sql_file' on '$date'.");
$cmd = $mysql_cmd . ' < ' . $xref_sql_file;
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
