#!/usr/bin/perl -I..

################################################################
#
#  Author(s) - Mark M. Gosink, Ph.D.
#  Company -   DSRD, Pfizer Inc.
#
#  Creation Date - Wed Oct 28 11:47:48 EDT 2009
#  Modified - 
#
#  Function - Update the MIM entries using the mim2gene file
#
################################################################

use conf::ToxGene_Defaults;

use Getopt::Long;

use DBI;

$result = GetOptions ('user=s'		=> \$username,
								'pass=s'		=> \$password);
if (($username eq "") || ($password eq "")) {
	die "\nUSAGE:\n\t$0 -u(ser) username -p(ass) password -i(d)\n\n";
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

#Required files
$mim2gene_file = $SetupFiles{MIM2GENE};
my @FileInfo = split(/\s+/, `ls -l $mim2gene_file`);
$mim2gene_file_date = $FileInfo[5] . ' ' . $FileInfo[6] . ' ' . $FileInfo[7];
$dominant_omim_file = '../data/omim_result.txt';
my @FileInfo = split(/\s+/, `ls -l $mim2gene_file`);
$mim2gene_file_date = $FileInfo[5] . ' ' . $FileInfo[6] . ' ' . $FileInfo[7];
if ((not(-s $mim2gene_file)) || (not(-T $mim2gene_file))) {
	die "\n\tRequired OMIM to Gene file not found or in wrong format at '$mim2gene_file'!\n\n";
}
elsif ((not(-s $dominant_omim_file)) || (not(-T $dominant_omim_file))) {
	die "\n\tRequired OMIM dominants file not found or in wrong format at '$dominant_omim_file'!\n\n";
}


#	first find out the current MIM GENE pairs
%Entrez_2_idGene = ();
my $sql = "SELECT idGene, entrezID FROM Gene";
$statement = $db_handle->prepare($sql);
$statement->execute;
while (@Row = $statement->fetchrow_array) {
	my $idgene = $Row[0];
	my $entrezid = $Row[1];
	$Entrez_2_idGene{$entrezid} = $idgene;
}
%OMIM_2_idXref = ();
%OMIM_Type = ();
%OMIM_Entrez = ();
my $sql = "SELECT X.idXref, X.Xref_ID, X.Xref_Source, G.idGene, G.entrezID"
			. " FROM Xref X, Gene G"
			. " WHERE X.idGene = G.idGene"
			. " AND (X.Xref_Source = 'MIM' OR X.Xref_Source = 'MIM_DOM')";
$statement = $db_handle->prepare($sql);
$statement->execute;
while (@Row = $statement->fetchrow_array) {
	my $idxref = $Row[0];
	my $xref_id = $Row[1];
	my $xref_source = $Row[2];
	my $idgene = $Row[3];
	my $entrezid = $Row[4];
	$OMIM_2_idXref{$xref_id} = $idxref;
	$OMIM_Type{$xref_id} = $xref_source;
	$OMIM_Entrez{$xref_id}{$entrezid}++;
}

#	generate an updated list of pairs
%Updated_OMIM_Entrez = ();
%Updated_OMIM_Type = ();
open (FILE, $mim2gene_file);
while ($line = <FILE>) {
	chomp($line);
	if ($line =~ /^#/) { next }		#	skip comment lines
	my ($omim_id, $entrez_id, undef) = split(/\t/, $line);
	$Updated_OMIM_Entrez{$omim_id}{$entrez_id}++;
	$Updated_OMIM_Type{$omim_id} = 'MIM';
}
close(FILE);
open (FILE, $dominant_omim_file);
while ($line = <FILE>) {
	chomp($line);
	if ($line =~ /^OMIM:\s+(\d+)/) {
		my $dom_omim_id = $1;
		my @Genes = keys(%{$Updated_OMIM_Entrez{$dom_omim_id}});
		foreach $gene_id (@Genes) {
			$Updated_OMIM_Entrez{$dom_omim_id}{$gene_id}++;
			$Updated_OMIM_Type{$dom_omim_id} = 'MIM_DOM';
		}
	}
}
close(FILE);

#	next, compare the database to existing pairs
$sql_file = './tmp_files/Update_MIMXrefs.sql';
open(OUTFILE, ">$sql_file");
print OUTFILE "use $db_name;\n";
print OUTFILE "SET autocommit=0;\n";
print OUTFILE "START TRANSACTION;\n";
foreach $omim_id (keys %Updated_OMIM_Type) {
	my $type = $Updated_OMIM_Type{$omim_id};
	if (not defined $OMIM_Type{$omim_id}) {
		#	need to add new omim xref entry and its gene links
		@Genes = keys(%{$Updated_OMIM_Entrez{$omim_id}});
		foreach $entrez_id (@Genes) {
			my $idgene = $Entrez_2_idGene{$entrez_id};
			if ($idgene eq "") {
				print "Warning A! Could not find an idGene entry for Entrez ID '$entrez_id', therefore couldn't add '$omim_id'\n";
			}
			else {
				print OUTFILE "INSERT INTO Xref (idGene, Xref_Source, Xref_ID) VALUES ($idgene, '$type', '$omim_id');\n";
			}
		}
		
	}
	else {
		if ($OMIM_Type{$omim_id} ne $Updated_OMIM_Type{$omim_id}) {
			#	need to update the OMIM type
			my $idxref = $OMIM_2_idXref{$omim_id};
			if ($idxref eq "") {
				print "Warning B! Could not find an idXref entry for OMIM ID '$omim_id' '$type'\n";
			}
			else {
				print OUTFILE "UPDATE Xref SET Xref_Source = '$type' WHERE idXref = '$idxref';\n";
			}
		}

		my @Genes = keys(%{$Updated_OMIM_Entrez{$omim_id}});
		foreach $gene_id (@Genes) {
			if (not defined $OMIM_Entrez{$omim_id}{$gene_id}) {
				my $idgene = $Entrez_2_idGene{$gene_id};
				if ($idgene eq "") {
					print "Warning C! Could not find an idGene entry for Entrez ID '$gene_id', therefore couldn't add '$omim_id'\n";
				}
				else {
					print OUTFILE "INSERT INTO Xref (idGene, Xref_Source, Xref_ID) VALUES ($idgene, '$type', '$omim_id');\n";
				}
			}
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
