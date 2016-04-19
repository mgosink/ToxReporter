#!/usr/bin/perl -I..

################################################################
#
#  Author(s) - Mark M. Gosink, Ph.D.
#  Company     Pfizer Inc
#
#  Creation Date - April 30, 2009
#  Modified -
#
#  Function - load MESH Tree classes into ToxGene
#					part 'a' loads the trees
#
################################################################

use conf::ToxGene_Defaults;

use DBI;

use Getopt::Long;

$mesh_tree_file = $SetupFiles{MESH_TREE};

$result = GetOptions ('user=s'		=> \$username,
								'pass=s'		=> \$password);
if (($username eq "") || ($password eq "") || ($mesh_tree_file eq "")) {
	die "\nUSAGE:\n\t$0 -u(ser) username -p(ass) password -f(ile) MESHtree_file\n\n";
}

#	check that the mesh file looks OK and gather basic info about the file
if ((not(-s $mesh_tree_file)) || (not(-T $mesh_tree_file))) {
	die "\n\tRequired MESH trees file not found or in wrong format at '$mesh_tree_file'!\n\n";
}
else {
	$meshtrees_file_list = `ls -l $mesh_tree_file`;
	$meshtrees_file_list =~ s/[\n\r\f]+//g;
}
$mesh_file_desc = "MESH Trees built using file '$meshtrees_file_list'.";

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


#	Create an entry in the Class_System table for MESH
my $class_sys_name = make_sql_safe('MESH Trees');
my $class_sys_desc = make_sql_safe($mesh_file_desc);
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

####	parse the MESH file and build a hash
my %ParentChild = ();
my %ChildParent = ();
my %PHENO = ();
open (FILE, $mesh_tree_file);
while ($line = <FILE>) {
	$line =~ s/[\n\r\f]+//g;
	if ($line =~ /^([A-Z]\d\d(\.\d{3})*)\.+(.+)/) {
#	if ($line =~ /^([^;]+);(.+)/) {
		my $current_id = $1;
		my $name = $3;
#print "N-'$name'\tID-'$current_id'\n";
		$PHENO{$current_id}{NAME} = $name;
		if ($current_id =~ /(.+)\.\d+$/) {
			my $parent_id = $1;
			$ParentChild{$parent_id}{$current_id} = 'is_a';
			$ChildParent{$current_id}{$parent_id} = 'is_a';
		}
	}
}

#	Create and run a SQL file for every ontology
$sql_file = './tmp_files/MESH_a_1.sql';
open(OUTFILE, ">$sql_file");
print OUTFILE "use $db_name;\n";
print OUTFILE "SET autocommit=0;\n";
print OUTFILE "START TRANSACTION;\n";
foreach $class_id (keys %PHENO) {
	my $name = make_sql_safe($PHENO{$class_id}{NAME});
	print OUTFILE "INSERT INTO Class (idClass_System, Class_Native_ID, Class_Name) VALUES ('$class_sys_id', '$class_id', '$name');\n";
}
print OUTFILE "COMMIT;\n";
close(OUTFILE);
$date = `date`;
chomp($date);
log_err("\t... loading '$sql_file' on '$date'.");
$cmd = $mysql_cmd . ' < ' . $sql_file;
`$cmd`;

#	build a hash mapping the MESH IDs to the database IDs
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
$sql_file = './tmp_files/MESH_a_2.sql';
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
