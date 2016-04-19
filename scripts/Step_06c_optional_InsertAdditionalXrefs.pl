#!/usr/bin/perl -I..

################################################################
#
#  Author(s) - Mark M. Gosink, Ph.D.
#  Company -   DSRD, Pfizer Inc.
#
#  Creation Date - Tue May 19 13:45:29 EDT 2009
#  Modified - 
#
#  Function - Script to associate various x-references with toxicities
#
################################################################

use conf::ToxGene_Defaults;

use DBI;

use Getopt::Long;

$result = GetOptions ('user=s'		=> \$username,
								'pass=s'		=> \$password,
								'id_type=s'		=> \$id_type,
								'xref_type=s'		=> \$xref_type,
								'file=s'		=> \$filename);
$id_type = uc($id_type);
if (($username eq "") || ($password eq "") || ($xref_type eq "") || ($filename eq "")) {
	die "\nUSAGE:\n\t$0 -u(ser) username -p(ass) password -i gene_id_type(default:database_id) -x xref_type -f filename_of_xrefs\n\n";
}
elsif ($id_type !~ /GENEBOOK|ENTREZ/) {
	warn "\nGene ID type not declared. All gene identifers assumed to be database IDs.\n\n";
	$id_type = 'DATABASE';
}

$xref_type = make_sql_safe($xref_type);

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
log_err("Running '$0' on '$date' using file '$filename'.\n\tLoading Xrefs of type '$xref_type' with gene IDs of type '$id_type'");

#	Load Entrez & GenBook to database IDs mappings
%EntrezGB_2_Gene = ();
my $sql = "SELECT EntrezID, GeneBook_ID, idGene FROM Gene";
$statement = $db_handle->prepare($sql);
$statement->execute();
while (@row = $statement->fetchrow_array) {
	my $entrez = $row[0];
	my $gb = $row[1];
	my $id = $row[2];
	if ($id !~ /^\d+$/) {
		log_err("Found a bad database ID: '$id'");
		next;
	}
	else {
		$EntrezGB_2_Gene{DATABASE}{$gb} = $id;
		if ($gb ne '') {
			$EntrezGB_2_Gene{GENEBOOK}{$entrez} = $id;
		}
		if ($entrez ne '') {
			$EntrezGB_2_Gene{ENTREZ}{$entrez} = $id;
		}
	}
}


#	Load current Xref IDs of current type
%Xref_2_ID = ();
my $sql = "SELECT Xref_ID, Xref_Source, idXref FROM Xref";
$statement = $db_handle->prepare($sql);
$statement->execute();
while (@row = $statement->fetchrow_array) {
	$Xref_2_ID{$row[0]}{$row[1]} = $row[2];
}

#	Load the file of ID mapping you wish to load
$xref_sql_file = './tmp_files/' . $0 . '.sql';
open(XREF_OUTFILE, ">$xref_sql_file");
print XREF_OUTFILE "use $db_name;\n";
open (FILE, $filename);
while ($line = <FILE>) {
	if ($line =~ /^#/) { next }		#	lines started with '#' are presumed to be comment lines
	$line =~ s/[\r\f\n]+//g;

	my ($xref, $gene_id, $replace_type, undef) = split(/\t/, $line);
	$xref = make_sql_safe($xref);
	$replace_type = make_sql_safe($replace_type);
	
	#	for each line find the database id corresponding to the gene id
	if ($id_type eq 'ENTREZ') { $id_gene = $EntrezGB_2_Gene{ENTREZ}{$gene_id} }
	elsif ($id_type eq 'GENEBOOK') { $id_gene = $EntrezGB_2_Gene{GENEBOOK}{$gene_id} }
	else { $id_gene = $EntrezGB_2_Gene{GENEBOOK}{$gene_id} }
	if ($id_gene !~ /^\d+$/) {
		log_err("Couldn't find a database ID for '$gene_id'");
		next;
	}

	#	
	if ($Xref_2_ID{$xref}{$xref_type} ne '') {
			log_err("A database entry for '$xref' of type '$xref_type' linked to '$gene_id/$id_gene' exists as ID: '$Xref_2_ID{$xref}{$xref_type}'. Skipped.");
			next;
	}
	elsif (($replace_type ne '') && ($Xref_2_ID{$xref}{$replace_type} eq '')) {
			log_err("A database entry for '$xref' of type '$replace_type' linked to '$gene_id/$id_gene' was not found. Skipped.");
			next;
	}
	elsif (($replace_type ne '') && ($Xref_2_ID{$xref}{$replace_type} ne '')) {
			print XREF_OUTFILE "UPDATE Xref SET Xref_Source = '$xref_type' WHERE Xref_Source = '$replace_type' AND idXref = '$xref';\n";
	}
	elsif ($replace_type eq '') {
			print XREF_OUTFILE "INSERT INTO Xref (idGene, Xref_ID, Xref_Source) VALUES ('$id_gene', '$xref', '$xref_type');\n";
	}
}
close(FILE);
close(XREF_OUTFILE);

$statement->finish;
$db_handle->disconnect;

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
