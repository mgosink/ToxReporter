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
#					part 'a' loads the ontologies
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
$gene_ontology_file = $SetupFiles{GENEONTOL};

#	check that the ontology file looks OK and gather basic info about the file
$obo_ver = $obo_date = $obo_creator = $obo_file_list = "";
if ((not(-s $gene_ontology_file)) || (not(-T $gene_ontology_file))) {
	die "\n\tRequired Gene Ontology file not found or in wrong format at '$gene_ontology_file'!\n\n";
}
else {
	$obo_file_list = `ls -l $gene_ontology_file`;
	$obo_file_list =~ s/[\n\r\f]+//g;
	open (FILE, $gene_ontology_file);
	for ($idx = 0; $idx <10; $idx++) {
		$line = <FILE>;
		chomp($line);
		if ($line =~ /^format-version:\s*(.+)/) { $obo_ver = $1 }
		elsif ($line =~ /^date:\s*(.+)/) { $obo_date = $1 }
		elsif ($line =~ /^saved-by:\s*(.+)/) { $obo_creator = $1 }
	}
	close(FILE);
	if (($obo_ver eq "") || ($obo_date eq "") || ($obo_date eq "")) {
		die "\n\tRequired Gene Ontology file in wrong format at '$gene_ontology_file'!\n\n";
	}
}
$go_file_desc = "Gene Ontologies built using file '$obo_file_list'."
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


#	Create an entry in the Class_System table for GO
my $class_sys_name = make_sql_safe('Gene Ontologies');
my $class_sys_desc = make_sql_safe($go_file_desc);
my $sql = "INSERT INTO Class_System (Class_Sys_Name, Class_Sys_Desc) VALUES ('$class_sys_name', '$class_sys_desc')";
$statement = $db_handle->prepare($sql);
$statement->execute();
my $sql = "SELECT idClass_System FROM Class_System WHERE Class_Sys_Name = '$class_sys_name'";
$statement = $db_handle->prepare($sql);
$statement->execute();
@row = $statement->fetchrow_array;
$class_sys_id = $row[0];

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
my %PHENO = ();
open (FILE, $gene_ontology_file);
while ($line = <FILE>) {
	chomp($line);
	if ($line =~ /^\[Term\]/) {
		$current_obsolete = 'F';
		$current_id = $current_name = '';
	}
	if ($line =~ /^id:\s+(GO:\d+)/) {
		$current_obsolete = 'F';
		$current_id = $current_name = '';
		$current_id = $1;
		$current_id =~ s/^GO:0*//;
	}
	if ($line =~ /^name:\s+(.+)/) {
		$PHENO{$current_id}{NAME} = $1;
	}
	if ($line =~ /^namespace:\s+(.+)/) {
		$PHENO{$current_id}{NAMESPACE} = $1;
	}
	if ($line =~ /^def:\s+(.+)/) {
		$PHENO{$current_id}{DEF} = $1;
	}
	if ($line =~ /^is_obsolete: true/) {
		$PHENO{$current_id}{OBSOLETE} = 'T';
	}
	if ($line =~ /^alt_id:\s+(GO:\d+)/) {
		my $alt_id = $1;
		$alt_id =~ s/^GO:0*//;
#				$PHENO{$current_id}{ALTS} .= "\|$alt_id";
	}

	if ($line =~ /^is_a: (GO:\d+)/) {
		my $parent_id = $1;
		$parent_id =~ s/^GO:0*//;
		$ParentChild{$parent_id}{$current_id} = 'is_a';
		$ChildParent{$current_id}{$parent_id} = 'is_a';
	}
	if ($line =~ /^relationship: part_of (GO:\d+)/) {
		my $parent_id = $1;
		$parent_id =~ s/^GO:0*//;
		$ParentChild{$parent_id}{$current_id} = 'part_of';
		$ChildParent{$current_id}{$parent_id} = 'part_of';
	}
}
foreach $id (keys %PHENO) {	#	handle the alternative phenotype IDs
	my $alts = $PHENO{$id}{ALTS};
	$alts =~ s/^\|//;
	my @Alts = split(/\|/, $alts);
	foreach $alt_id (@Alts) {
		$PHENO{$alt_id}{NAME} = $PHENO{$id}{NAME};
		$PHENO{$alt_id}{OBSOLETE} = $PHENO{$id}{OBSOLETE};
		$PHENO{$alt_id}{DEF} = $PHENO{$id}{DEF};
		foreach $par_id (keys %{$ChildParent{$id}}) {
			$ParentChild{$par_id}{$alt_id} = $ParentChild{$par_id}{$alt_id};	
		}
	}
}

#	Create and run a SQL file for every ontology
$sql_file = './tmp_files/go_a_1.sql';
open(OUTFILE, ">$sql_file");
print OUTFILE "use $db_name;\n";
print OUTFILE "SET autocommit=0;\n";
print OUTFILE "START TRANSACTION;\n";
foreach $class_id (keys %PHENO) {
	my $name = make_sql_safe($PHENO{$class_id}{NAME});
	my $desc = $PHENO{$class_id}{NAMESPACE} . ':' . $PHENO{$class_id}{DEF};
	my $def = make_sql_safe($desc);
	my $obsolete = $PHENO{$class_id}{OBSOLETE};
	if ($obsolete eq 'T') { next }
	print OUTFILE "INSERT INTO Class (idClass_System, Class_Native_ID, Class_Name, Class_Desc) VALUES ('$class_sys_id', '$class_id', '$name', '$def');\n";
}
print OUTFILE "COMMIT;\n";
close(OUTFILE);
$date = `date`;
chomp($date);
log_err("\t... loading '$sql_file' on '$date'.");
$cmd = $mysql_cmd . ' < ' . $sql_file;
`$cmd`;

#	build a hash mapping the GO IDs to the database IDs
my %NativeID_to_DBid = ();
my %Name_to_DBid = ();
my $sql = "SELECT Class_Native_ID, idClass, Class_Name FROM Class WHERE idClass_System = '$class_sys_id'";
$statement = $db_handle->prepare($sql);
$statement->execute();
while(@row = $statement->fetchrow_array) {
	$NativeID_to_DBid{$row[0]} = $row[1];
	$Name_to_DBid{$row[3]} = $row[1];
}

$statement->finish;
$db_handle->disconnect;

#	Create and run a SQL file to load the parent / child relationships
$sql_file = './tmp_files/go_a_2.sql';
open(OUTFILE, ">$sql_file");
print OUTFILE "use $db_name;\n";
print OUTFILE "SET autocommit=0;\n";
print OUTFILE "START TRANSACTION;\n";
foreach $parent_id (keys %ParentChild) {
	foreach $child_id (keys %{$ParentChild{$parent_id}}) {
		my $db_par_id = $NativeID_to_DBid{$parent_id};
		my $db_chd_id = $NativeID_to_DBid{$child_id};
		my $relationship = $ParentChild{$parent_id}{$child_id};
		if ((defined $db_par_id) && (defined $db_chd_id)) {
			print OUTFILE $sql = "INSERT INTO Class_Parent (Parent_idClass, Child_idClass, Relationship) VALUES ('$db_par_id', '$db_chd_id', '$relationship');\n";
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
