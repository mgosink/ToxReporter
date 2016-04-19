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

#	Required files
$omim_cit_file = $SetupFiles{PUBMED_CITED};

$result = GetOptions ('user=s'			=> \$username,
								'pass=s'			=> \$password,
								'directory=s'	=>	\$parsed_mesh_dir);

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

@ToxTermIds = ();
my $sql = "SELECT idToxTerm FROM ToxTerm";
$statement = $db_handle->prepare($sql);
$statement->execute;
while (@row = $statement->fetchrow_array) {
	push(@ToxTermIds, $row[0]);
}

$toxterm_id_list = join(", ", @ToxTermIds);

#	first create a lookup hash of OMIM IDs to the idXref
%OMIM_2_idXref = ();
my $sql = "SELECT idXref, Xref_ID FROM Xref"
			. " WHERE Xref_Source = 'MIM' OR Xref_Source = 'MIM_DOM'";
$statement = $db_handle->prepare($sql);
$statement->execute;
while (@row = $statement->fetchrow_array) {
	$OMIM_2_idXref{$row[1]} = $row[0];
}

#	create a hash of publications (pubmed ids) cited in OMIM to their OMIM id
%PubMed_2_OMIM = ();
open (FILE, "$omim_cit_file");
while ($line = <FILE>) {
	$line =~ s/[\n\r\f]+//g;
	my ($omim_id, undef, $pubmed_id) = split(/\t/, $line);
	if (($omim_id !~ /^\d+/) || ($pubmed_id !~ /^\d+/)) { next }		#	skip entries with no IDs
	if (not defined $OMIM_2_idXref{$omim_id}) { next }						#	skip OMIM entries with no gene links
	$PubMed_2_OMIM{$pubmed_id}{$omim_id} = 'T';
}
close(FILE);

#	next MESH terms and all children which are associated with this toxicity
my $sql = "SELECT C.idClass, C.Class_Name, TL.idToxTerm"
			. " FROM Class C, ToxLink TL"
			. " WHERE C.idClass_System = (SELECT idClass_System FROM Class_System WHERE Class_Sys_Name = 'MESH Trees')"
			. " AND C.idClass IN (SELECT Class_idClass FROM ToxLink WHERE idToxTerm in ($toxterm_id_list))"
			. " AND C.idClass = TL.Class_idClass";
#print "SQL>\n\t$sql\n\n<SQL\n\n\n";
$statement = $db_handle->prepare($sql);
$statement->execute;
%MESH_2_Class = ();
while (@row = $statement->fetchrow_array) {
	$mesh_id = $row[0];
	$mesh_name = $row[1];
	$toxterm_id = $row[2];
	my $skip = 'T';
	foreach $tt_id (@ToxTermIds) { if ($tt_id == $toxterm_id) { $skip = 'F' } }
	if ($skip eq 'T') { next } #	skip also matched toxterms
	$MESH_2_Class{$mesh_name}{$toxterm_id} = $mesh_id;
}

%Xref_2_Tox = ();
%ReportedCombination = ();
foreach $mesh_name (keys(%MESH_2_Class)) {
	my $file = $mesh_name;
	$file = $parsed_mesh_dir .'/MESH/' . $file;
	$file =~ s/\s+/_/g;
	if ((-e $file) && (-s $file)) {
		log_err("\t...parsing '$file'.");
		open(FILE, $file);
		while ($line = <FILE>) {
			chomp($line);
			my @LinkedGenes = split(/\t/, $line);
			foreach $linkedgene (@LinkedGenes) {
				my ($gene, $articles) = split(/\|\|:/, $linkedgene);
				my @Entries = split(/:/, $articles);
				foreach $entry (@Entries) {
					my ($cat_type, $pmid) = split(/\|/, $entry);
					if ($cat_type eq 'M') { $major_topic = 'Major Topic' }
					else { $major_topic = 'Minor Topic' }
					if ((defined $MESH_2_Class{$mesh_name}) && (defined $PubMed_2_OMIM{$pmid})) {
						foreach $omim_id (keys(%{$PubMed_2_OMIM{$pmid}})) {
							my $xref_id = $OMIM_2_idXref{$omim_id};
							my $evid = ", '$mesh_name' ($major_topic)";
							foreach $toxterm_id (keys %{$MESH_2_Class{$mesh_name}}) {
								if ($ReportedCombination{$xref_id}{$toxterm_id}{$pmid} ne '') { next }
								$Xref_2_Tox{$xref_id}{$toxterm_id}{$pmid} .= $evid;
								$ReportedCombination{$xref_id}{$toxterm_id}{$pmid} = $evid;
							}
						}
					}
				}
			}
		}
		close(FILE);
	}
}
log_err("\t... Finished parsing medline files.");

$sql_file = './tmp_files/Omim_mesh_1.sql';
open(OUTFILE, ">$sql_file");
print OUTFILE "use $db_name;\n";
print OUTFILE "SET autocommit=0;\n";
print OUTFILE "START TRANSACTION;\n";
foreach $xref_id (keys %Xref_2_Tox) {
	foreach $toxterm_id (keys %{$Xref_2_Tox{$xref_id}}) {
		print OUTFILE "INSERT INTO ToxLink (idToxTerm, Xref_idXref) VALUES ('$toxterm_id', '$xref_id');\n";
	}
}
print OUTFILE "COMMIT;\n";
close(OUTFILE);
$date = `date`;
chomp($date);
log_err("\t... loading '$sql_file' on '$date'.");
$cmd = $mysql_cmd . ' < ' . $sql_file;
`$cmd`;

%Xref_2_ToxLinkId = ();
my $sql = "SELECT idToxLink, Xref_idXref, idToxTerm FROM ToxLink WHERE idToxTerm in ($toxterm_id_list)";
$statement = $db_handle->prepare($sql);
$statement->execute;
while (@row = $statement->fetchrow_array) {
	$Xref_2_ToxLinkId{$row[1]}{$row[2]} = $row[0];
}

$sql_file = './tmp_files/Omim_mesh_2.sql';
open(OUTFILE, ">$sql_file");
print OUTFILE "use $db_name;\n";
print OUTFILE "SET autocommit=0;\n";
print OUTFILE "START TRANSACTION;\n";
foreach $xref_id (keys %Xref_2_Tox) {
	foreach $toxterm_id (keys %{$Xref_2_Tox{$xref_id}}) {
		my $toxlink_id = $Xref_2_ToxLinkId{$xref_id}{$toxterm_id};
		my @Publications = keys %{$Xref_2_Tox{$xref_id}{$toxterm_id}};
		foreach $pubmed_id (@Publications) {
		my $matched_terms = $Xref_2_Tox{$xref_id}{$toxterm_id}{$pubmed_id};
		$matched_terms =~ s/^, //;
		my $evid = "OMIM cites the PubMed article:$pubmed_id which matches the MESH term(s) $matched_terms";
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

