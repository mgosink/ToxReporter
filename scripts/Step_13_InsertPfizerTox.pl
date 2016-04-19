#!/usr/bin/perl -I..

################################################################
#
#  Author(s) - Mark M. Gosink, Ph.D.
#  Company     Pfizer Inc
#
#  Creation Date - April 1, 2009
#  Modified -
#
#  Function - load Pfizer Toxicity Ontology terms into ToxGene
#					part 'a' loads the ontologies
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

#	Required Files
$tox_ontology_file = $SetupFiles{PFIZER_TOX};

#	check that the ontology file looks OK and gather basic info about the file
$obo_ver = $obo_date = $obo_creator = $obo_file_list = "";
if ((not(-s $tox_ontology_file)) || (not(-T $tox_ontology_file))) {
	die "\n\tRequired Pfizer Toxicity Ontology file not found or in wrong format at '$tox_ontology_file'!\n\n";
}
else {
	$obo_file_list = `ls -l $tox_ontology_file`;
	$obo_file_list =~ s/[\n\r\f]+//g;
	open (FILE, $tox_ontology_file);
	for ($idx = 0; $idx <10; $idx++) {
		$line = <FILE>;
		chomp($line);
		if ($line =~ /^format-version:\s*(.+)/) { $obo_ver = $1 }
		elsif ($line =~ /^date:\s*(.+)/) { $obo_date = $1 }
		elsif ($line =~ /^saved-by:\s*(.+)/) { $obo_creator = $1 }
	}
	close(FILE);
	if (($obo_ver eq "") || ($obo_date eq "") || ($obo_date eq "")) {
		die "\n\tRequired Pfizer Toxicity file in wrong format at '$tox_ontology_file'!\n\n";
	}
}
$tox_file_desc = "Pfizer Toxicity built using file '$obo_file_list'."
					. " Files headings indicated that the format version was: '$obo_ver',"
					. " the datestamp was: '$obo_date',"
					. " and the creator was: '$obo_creator'.";

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


#	Create an entry in the ToxTerm_System table for GO
my $tox_sys_name = make_sql_safe('Pfizer Toxicity');
my $tox_sys_desc = make_sql_safe($tox_file_desc);
my $sql = "INSERT INTO Tox_System (Tox_Sys_Name, Tox_Sys_Desc) VALUES ('$tox_sys_name', '$tox_sys_desc')";
$statement = $db_handle->prepare($sql);
$statement->execute();
my $sql = "SELECT idTox_System FROM Tox_System WHERE Tox_Sys_Name = '$tox_sys_name'";
$statement = $db_handle->prepare($sql);
$statement->execute();
@row = $statement->fetchrow_array;
$tox_sys_id = $row[0];

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

####	parse the GO file and build a hash
my %ParentChild = ();
my %ChildParent = ();
my %OBO_TERM = ();
open (FILE, $tox_ontology_file);
while ($line = <FILE>) {
	chomp($line);
	if ($line =~ /^\[Term\]/) {
		$current_obsolete = 'F';
		$current_id = $current_name = '';
	}
	if ($line =~ /^id:\s+(PT:\d+)/) {
		$current_obsolete = 'F';
		$current_id = $current_name = '';
		$current_id = $1;
#		$current_id =~ s/^PT:0+//;
	}
	if ($line =~ /^name:\s+(.+)/) {
		$OBO_TERM{$current_id}{NAME} = $1;
	}
	if ($line =~ /^namespace:\s+(.+)/) {
		$OBO_TERM{$current_id}{NAMESPACE} = $1;
	}
	if ($line =~ /^def:\s+(.+)/) {
		$OBO_TERM{$current_id}{DEF} = $1;
	}
	if ($line =~ /^synonym:\s+\"([^\"]+)\"/) {
		$OBO_TERM{$current_id}{SYN} .= ", $1";
	}
	if ($line =~ /^is_obsolete: true/) {
		$OBO_TERM{$current_id}{OBSOLETE} = 'T';
	}
	if ($line =~ /^alt_id:\s+(PT:\d+)/) {
		my $alt_id = $1;
#		$alt_id =~ s/^PT:0+//;
#				$OBO_TERM{$current_id}{ALTS} .= "\|$alt_id";
	}

	if ($line =~ /^is_a: (PT:\d+)/) {
		my $parent_id = $1;
#		$parent_id =~ s/^PT:0+//;
		$ParentChild{$parent_id}{$current_id} = 'is_a';
		$ChildParent{$current_id}{$parent_id} = 'is_a';
	}
	if ($line =~ /^relationship: part_of (PT:\d+)/) {
		my $parent_id = $1;
#		$parent_id =~ s/^PT:0+//;
		$ParentChild{$parent_id}{$current_id} = 'part_of';
		$ChildParent{$current_id}{$parent_id} = 'part_of';
	}
}
foreach $id (keys %OBO_TERM) {	#	handle the alternative phenotype IDs
	my $alts = $OBO_TERM{$id}{ALTS};
	$alts =~ s/^\|//;
	my @Alts = split(/\|/, $alts);
	foreach $alt_id (@Alts) {
		$OBO_TERM{$alt_id}{NAME} = $OBO_TERM{$id}{NAME};
		$OBO_TERM{$alt_id}{OBSOLETE} = $OBO_TERM{$id}{OBSOLETE};
		$OBO_TERM{$alt_id}{DEF} = $OBO_TERM{$id}{DEF};
		foreach $par_id (keys %{$ChildParent{$id}}) {
			$ParentChild{$par_id}{$alt_id} = $ParentChild{$par_id}{$alt_id};	
		}
	}
}

#	Create and run a SQL file for every ontology
$sql_file = './tmp_files/tox_a_1.sql';
open(OUTFILE, ">$sql_file");
print OUTFILE "use $db_name;\n";
foreach $tox_id (keys %OBO_TERM) {
	my $name = make_sql_safe($OBO_TERM{$tox_id}{NAME});
	my $desc = '';
	my $synonyms = $OBO_TERM{$tox_id}{SYN};
	$synonyms =~ s/^, //;
	if ($synonyms ne '') { $desc = 'Synonyms: ' . $OBO_TERM{$tox_id}{SYN} }
	if ($OBO_TERM{$tox_id}{DEF} ne '') { $desc .= ' ' . $OBO_TERM{$tox_id}{DEF} }
	my $def = make_sql_safe($desc);
	my $obsolete = $OBO_TERM{$tox_id}{OBSOLETE};
	if ($obsolete eq 'T') { next }
	print OUTFILE "INSERT INTO ToxTerm (idTox_System, Tox_Native_ID, Tox_Term, Tox_Desc) VALUES ('$tox_sys_id', '$tox_id', '$name', '$def');\n";
}
close(OUTFILE);

$date = `date`;
chomp($date);
log_err("\t... loading '$sql_file' on '$date'.");
$cmd = $mysql_cmd . ' < ' . $sql_file;
`$cmd`;

#	build a hash mapping the GO IDs to the database IDs
my %NativeID_to_DBid = ();
my %Name_to_DBid = ();
my $sql = "SELECT Tox_Native_ID, idToxTerm, Tox_Term FROM ToxTerm WHERE idTox_System = '$tox_sys_id'";
$statement = $db_handle->prepare($sql);
$statement->execute();
while(@row = $statement->fetchrow_array) {
	$NativeID_to_DBid{$row[0]} = $row[1];
	$Name_to_DBid{$row[3]} = $row[1];
}
$statement->finish;
$db_handle->disconnect;

#	Create and run a SQL file to load the parent / child relationships
$sql_file = './tmp_files/tox_a_2.sql';
open(OUTFILE, ">$sql_file");
print OUTFILE "use $db_name;\n";
foreach $parent_id (keys %ParentChild) {
	foreach $child_id (keys %{$ParentChild{$parent_id}}) {
		my $db_par_id = $NativeID_to_DBid{$parent_id};
		my $db_chd_id = $NativeID_to_DBid{$child_id};
		my $relationship = $ParentChild{$parent_id}{$child_id};
		if ((defined $db_par_id) && (defined $db_chd_id)) {
			print OUTFILE $sql = "INSERT INTO ToxParent (Parent_idToxTerm, Child_idToxTerm, Relationship) VALUES ('$db_par_id', '$db_chd_id', '$relationship');\n";
		}
	}
}
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
