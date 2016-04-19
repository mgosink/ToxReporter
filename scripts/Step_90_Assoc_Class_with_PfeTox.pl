#!/usr/bin/perl -I..

################################################################
#
#  Author(s) - Mark M. Gosink, Ph.D.
#  Company -   DSRD, Pfizer Inc.
#
#  Creation Date - Wed Mar 18 14:27:50 EDT 2009
#  Modified - 
#
#  Function - Create a file of suspected toxicity classes
#					v2 is a modification to load associations create
#					from web interface; cascading is assumed to be true
#
################################################################

use conf::ToxGene_Defaults;

use DBI;

use Getopt::Long;

@Files = ();

$result = GetOptions ('user=s'		=> \$username,
								'pass=s'		=> \$password,
								'file:s'		=> \$file,
								'all'			=> \$all_files
								);
if (($username eq "") || ($password eq "")) {
	die "\nUSAGE:\n\t$0 -u(ser) username -p(ass) password -f(ile) filename -a(ll)\n\n";
}
if ($file ne "") {
	if ((not(-T $file)) || (-z $file)) {
		die "\nFatal Error: The file '$file' does not apear to be in the appropriate format.\n\n"
	}
	push (@Files, $file);
}
elsif ($all_files) {
	$cmd = 'ls -1 ../data/Edittable_SafeLex/*.PT:0*';
	@Files = split(/\n/, `$cmd`);
}
else {
	die "\nUSAGE:\n\t$0 -u(ser) username -p(ass) password  -f(ile) filename -a(ll)\n\n";
}

$date = `date`;
chomp($date);
log_err("Running '$0' on '$date'.");

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

foreach $file (@Files) {
	$date = `date`;
	chomp($date);
	log_err("\t...starting on file '$file' on '$date'.");

	$native_tox_id = '';
	if ($file =~ /\.(PT:\d+)$/) { $native_tox_id = $1 }
	else { die "\nFatal Error: The file '$file' does not apear to be in the appropriate format.\n\n" }


	my $sql = "SELECT idToxTerm FROM ToxTerm"
				. " WHERE Tox_Native_ID = '$native_tox_id'";
	$statement = $db_handle->prepare($sql);
	$statement->execute;
	@row = $statement->fetchrow_array;
	$id_toxterm = $row[0];

	open (FILE, $file);
	while ($line = <FILE>) {
		if ($line =~ /^[#\s]/) { next }
		chomp($line);
		my ($class_sys_name, $class_native_id, $annotator, $date, $comment, $cascade) = split(/\t/, $line);
		if (($class_sys_name eq "") || ($class_native_id eq "") || ($annotator eq "") || ($comment eq "")) {
			log_err("A class system name , native class id, annotator, or comment was left blank '$id_toxterm', '$id_class', '$annotator', '$comment'");
			next;
		}
		if ($cascade eq "") { $cascade = 'Y' }

		my $sql = "SELECT C.idClass, C.Class_Name FROM Class C, Class_System CS"
					. " WHERE C.Class_Native_ID = '$class_native_id'"
					. " AND CS.Class_Sys_Name = '$class_sys_name'"
					. " AND CS.idClass_System = C.idClass_System";
		$statement = $db_handle->prepare($sql);
		$statement->execute;
		@row = $statement->fetchrow_array;
		$id_class = $row[0];
		$class_name = $row[1];
		if ($id_class <= 0) {
			log_err("Couldn't find an class name for the native class ID '$class_native_id' in '$class_sys_name'");
			next;
		}

		$Association{$id_class}{$id_toxterm}{CLASSNAME} = $class_name;
		$Association{$id_class}{$id_toxterm}{COMM} = $comment;
		$Association{$id_class}{$id_toxterm}{ANNOTATOR} = $annotator;
		$Association{$id_class}{$id_toxterm}{DATE} = $date;
		$Association{$id_class}{$id_toxterm}{CASCADE} = $cascade;
	}
	close(FILE);

	#	Build a hash of existing links between a phenotype and toxicity to the idToxLink so we don't duplicate it
	%ToxClassHash = ();
	my $sql = "SELECT idToxLink, idToxTerm, Class_idClass from ToxLink";
	$statement = $db_handle->prepare($sql);
	$statement->execute;
	while(@row = $statement->fetchrow_array) {
		my $id_toxlink = $row[0];
		my $id_toxterm = $row[1];
		my $id_class = $row[2];
		if ($id_class > 0) {
			$ToxClassHash{$id_class}{$id_toxterm} = $id_toxlink;
		}
	}

	%All_Classes = ();
	foreach $id_class (keys(%Association)) {
		foreach $id_toxterm (keys(%{$Association{$id_class}})) {
			$annotator = $Association{$id_class}{$id_toxterm}{ANNOTATOR};
			$date = $Association{$id_class}{$id_toxterm}{DATE};
			$class_name = $Association{$id_class}{$id_toxterm}{CLASSNAME};
			$reason = "'$class_name' =&gt; " . $Association{$id_class}{$id_toxterm}{COMM} . " ($annotator on $date)";

			$All_Classes{$id_class}{$id_toxterm}{Name} = $class_name;
			$All_Classes{$id_class}{$id_toxterm}{Reason} = $reason;

			my $cascade = $Association{$id_class}{$id_toxterm}{CASCADE};
			if ($cascade =~ /^[yYtT]$/) { find_class_children($id_class, $id_toxterm, $reason) }
		}
	}

	$sql_file = './tmp_files/' . $0 . '_ToxClass_a.sql';
	open(OUTFILE, ">$sql_file");
	print OUTFILE "use $db_name;\n";
   print OUTFILE "SET autocommit=0;\n";
   print OUTFILE "START TRANSACTION;\n";
	foreach $id_class (keys %All_Classes) {
		foreach $id_toxterm (keys %{$All_Classes{$id_class}}) {
			if (defined $ToxClassHash{$id_class}{$id_toxterm}) { next }
			else {
				print OUTFILE "INSERT INTO ToxLink (idToxTerm, Class_idClass) VALUES ('$id_toxterm', '$id_class');\n";
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

	%ClassTox_2_ToxLinkId = ();
	my $sql = "SELECT idToxLink, Class_idClass, idToxTerm FROM ToxLink";
	$statement = $db_handle->prepare($sql);
	$statement->execute;
	while (@row = $statement->fetchrow_array) {
		$ClassTox_2_ToxLinkId{$row[1]}{$row[2]} = $row[0];
	}

	$sql_file = './tmp_files/' . $0 . '_ToxClass_b.sql';
	open(OUTFILE, ">$sql_file");
	print OUTFILE "use $db_name;\n";
   print OUTFILE "SET autocommit=0;\n";
   print OUTFILE "START TRANSACTION;\n";
	foreach $id_class (keys %All_Classes) {
		foreach $id_toxterm (keys %{$All_Classes{$id_class}}) {
			my $toxlink_id = $ClassTox_2_ToxLinkId{$id_class}{$id_toxterm};
			my $evid = make_sql_safe($All_Classes{$id_class}{$id_toxterm}{Reason});
			print OUTFILE "INSERT INTO ToxLink_Evid (idToxLink, Tox_Evidence, Create_Date, Update_Date) VALUES ('$toxlink_id', '$evid', NOW(), NOW());\n";
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
	log_err("\t... finished loading '$sql_file' on '$date'.");

}

$statement->finish;
$db_handle->disconnect;

$date = `date`;
chomp($date);
log_err("Finished '$0' on '$date'.");

exit;

sub log_err {
	my $msg = $_[0];
	my $log_file = $0 . '.log';
	open (LOG, ">>$log_file");
	print LOG "$msg\n";
	close(LOG);
}

sub find_class_children {
	my $parent = $_[0];
	my $id_toxterm = $_[1];
	my $reason = $_[2];
	my $sql = "SELECT CP.Child_idClass, C.Class_Name"
				. " FROM Class_Parent CP, Class C"
				. " WHERE CP.Child_idClass = C.idClass"
				. " AND CP.Parent_idClass = '$parent'";
	my $statement = $db_handle->prepare($sql);
	$statement->execute;
	while (@row = $statement->fetchrow_array) {
		$child_id = $row[0];
		$child_name = $row[1];
		$All_Classes{$child_id}{$id_toxterm}{Name} = $child_name;
		my $child_reason = "'$child_name' is a sub-catagory of a flagged catagory [" . $reason . "]";
		$All_Classes{$child_id}{$id_toxterm}{Reason} = $child_reason;
		find_class_children($child_id, $id_toxterm, $reason);
	}
}

sub make_sql_safe {
	my $term = $_[0];
	$term =~ s/\\/\\\\/g;
	$term =~ s/'/\\'/g;
	$term =~ s/"/\\"/g;
	return $term;
}

