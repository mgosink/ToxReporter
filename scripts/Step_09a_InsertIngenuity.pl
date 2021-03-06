#!/usr/bin/perl -I..

################################################################
#
#  Author(s) - Mark M. Gosink, Ph.D.
#  Company     Pfizer Inc
#
#  Creation Date - March 18, 2009
#  Modified -
#
#  Function - load Ingenuity pathways from their 'pathwaylist'
#					integration module; Part a creates a class entry
#					for Ingenuity and inserts the pathway names
#
################################################################

use conf::ToxGene_Defaults;

use DBI;

use Text::CSV;

use Getopt::Long;

$result = GetOptions ('user=s'		=> \$username,
								'pass=s'		=> \$password);
if (($username eq "") || ($password eq "")) {
	die "\nUSAGE:\n\t$0 -u(ser) username -p(ass) password\n\n";
}

#	Required Files
$ingenuity_file = '../data/IngenuityIdList.csv';

#	check that the ontology file looks OK and gather basic info about the file
$ing_ver = $ing_date = $ing_creator = $ing_file_list = "";
if ((not(-s $ingenuity_file)) || (not(-T $ingenuity_file))) {
	die "\n\tRequired Ingenuity Pathways file not found or in wrong format at '$ingenuity_file'!\n\n";
}
else {
	$ing_file_list = `ls -l $ingenuity_file`;
	$ing_file_list =~ s/[\n\r\f]+//g;
}
$ing_file_desc = "Ingenuity Pathway classes built using file '$ing_file_list'.";

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


#	Create an entry in the Class_System table for GO
my $class_sys_name = make_sql_safe('Ingenuity Pathways');
my $class_sys_desc = make_sql_safe($ing_file_desc);
my $sql = "INSERT INTO Class_System (Class_Sys_Name, Class_Sys_Desc) VALUES ('$class_sys_name', '$class_sys_desc')";
$statement = $db_handle->prepare($sql);
$statement->execute();
my $sql = "SELECT idClass_System FROM Class_System WHERE Class_Sys_Name = '$class_sys_name'";
$statement = $db_handle->prepare($sql);
$statement->execute();
@row = $statement->fetchrow_array;
$class_sys_id = $row[0];

%IngID2PathName = ();

my $csv = Text::CSV->new ( { binary => 1 } )  # should set binary attribute.
                 or die "Cannot use CSV: ".Text::CSV->error_diag ();
open($fh, "<:encoding(utf8)", $ingenuity_file);
binmode STDOUT, ":utf8";
while ($csv->getline( $fh )) {
	my @Columns = $csv->fields();
	my $id_data = $Columns[0];
	$id_data =~ s/.*(ING:[A-Za-z0-9]+).*/$1/;
	my $current_path_id = utf_to_html($id_data);
	my $current_pathname = utf_to_html($Columns[1]);
	my $current_pathtype = utf_to_html($Columns[2]);
	my $current_pathentities = utf_to_html($Columns[3]);
	my $human = utf_to_html($Columns[4]);
	my $mouse = utf_to_html($Columns[5]);
	my $rat = utf_to_html($Columns[6]);
	$IngID2PathName{$current_path_id} = $current_pathname;
}
close($fh);

#	Create and run a SQL file for every ontology
$sql_file = './tmp_files/Ingenuity_5a.sql';
open(OUTFILE, ">$sql_file");
print OUTFILE "use $db_name;\n";
print OUTFILE "SET autocommit=0;\n";
print OUTFILE "START TRANSACTION;\n";
foreach $class_id (keys %IngID2PathName) {
	my $name = make_sql_safe($IngID2PathName{$class_id});
	print OUTFILE "INSERT INTO Class (idClass_System, Class_Native_ID, Class_Name) VALUES ('$class_sys_id', '$class_id', '$name');\n";
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

sub utf_to_html {
	my $term = $_[0];
	$term =~ s/\x{03B1}/&alpha;/g;	#	alpha
	$term =~ s/\x{03B2}/&#976;/g;	#	beta
	$term =~ s/\x{0394}/&#916;/g;	#	delta, upper case
	$term =~ s/\x{03B4}/&#948;/g;	#	delta, lower case
	$term =~ s/\x{03B7}/&#951;/g;	#	eta
	$term =~ s/\x{03B9}/&#953;/g;	#	iota
	$term =~ s/\x{03B3}/&#947;/g;	#	gamma
	$term =~ s/\x{03BA}/&#954;/g;	#	kappa
	$term =~ s/\x{03BB}/&#955;/g;	#	
	$term =~ s/\x{03B5}/&#949;/g;	#	epsilon
	$term =~ s/\x{03C9}/&#969;/g;	#	omega
	$term =~ s/\x{03C3}/&#963;/g;	#	sigma
	$term =~ s/\x{03B8}/&#952;/g;	#	theta
	$term =~ s/\x{03B6}/&#950;/g;	#	zeta

	$term =~ s/\s+/ /g;					#	remove extra spaces
	$term =~ s/\x{2424}//g;			#	remove newline
	$term =~ s/\x{000A}//g;			#	remove line feed
	$term =~ s/\x{2013}/-/g;
	$term =~ s/[^[:ascii:]]+/***FOOBAR***/g;
	return $term;
}

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
