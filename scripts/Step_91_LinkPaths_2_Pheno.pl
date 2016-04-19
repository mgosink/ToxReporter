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
#
################################################################

use conf::ToxGene_Defaults;

use DBI;

use Getopt::Long;

$min_enrichment = 5;
$max_qval = 1e-5;
$min_genes = 5;

#	Required Files
$path2pheno_stats_file = "./Mouse_Ingenuity_VS_Mouse_phenotype.stats";

$result = GetOptions ('ann=s{,}'		=> \@Ann,
								'tid=s{,}'	=> \@ToxNativeIDs,
								'user=s'		=> \$username,
								'pass=s'		=> \$password);
$annotator = join(" ", @Ann);
$comment = "Pathways linked to phenotypes via gene-enrichment analysis (Min-enrich: $min_enrichment; Max-qval: $max_qval; Min-genes: $min_genes)";
$date = `date`;
chomp($date);
$comment = make_xml_safe($comment);

if ($annotator eq "") { die "\nFatal Error: You must specify an annotator's name with the --ann(-a) option.\n\n" }
elsif ($#ToxNativeIDs <= 0) {
	$cmd = 'ls -1 ../data/Edittable_SafeLex/*.PT:0*';
	@Files = split(/\n/, `$cmd`);
	foreach $filename (@Files) {
		if ($filename =~ /.+\.(PT:0\d+)/) { push (@ToxNativeIDs, $1) }
	}
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

#	first create a lookup hash of Ingenuity Pathway to idClass
%Ing_2_idClass = ();
my $sql = "SELECT idClass, Class_Native_ID, Class_Name FROM Class"
			. " WHERE idClass_System IN"
			. " (SELECT idClass_System FROM Class_System WHERE Class_Sys_Name = 'Ingenuity Pathways')";
$statement = $db_handle->prepare($sql);
$statement->execute;
while (@row = $statement->fetchrow_array) {
	$Ing_2_idClass{$row[1]}{ID} = $row[0];
	$Ing_2_idClass{$row[1]}{NAME} = $row[2];
}

#	Iterate through each of the submitted tox IDs
foreach $native_tox_id (@ToxNativeIDs) {
	my $sql = "SELECT idToxTerm FROM ToxTerm"
				. " WHERE Tox_Native_ID = '$native_tox_id'";
	$statement = $db_handle->prepare($sql);
	$statement->execute;
	@row = $statement->fetchrow_array;
	$toxterm_id = $row[0];
	if ($toxterm_id <= 0) {
		log_err("... Error!: Toxicity Native ID '$native_tox_id' is not recognized. Skipped.");
		next;
	}
	log_err("... Working on Toxicity Native ID '$native_tox_id ($toxterm_id)'.");


	#	next lookup all the mouse phenotypes which are associated with this toxicity
	my $sql = "SELECT idClass, Class_Native_ID, Class_Name FROM Class"
				. " WHERE idClass_System = (SELECT idClass_System FROM Class_System WHERE Class_Sys_Name = 'Mouse Mutant Phenotypes')"
				. " AND idClass IN (SELECT Class_idClass FROM ToxLink WHERE idToxTerm = $toxterm_id)";
	$statement = $db_handle->prepare($sql);
	$statement->execute;
	%Phenotype_Classes = ();
	while (@row = $statement->fetchrow_array) {
		$phenotype_id_class = $row[0];
		$phenotype_native_id = $row[1];
		$phenotype_name = $row[2];
		$reason = "'$phenotype_name' =&gt; $comment ($annotator on $date)";
		$Phenotype_Classes{$phenotype_native_id}{idClass} = $phenotype_id_class;
		$Phenotype_Classes{$phenotype_native_id}{Name} = $phenotype_name;
	}

	%HitPathways = ();
	open(FILE, $path2pheno_stats_file);
	while ($line = <FILE>) {
		chomp($line);
		my ($pathway, @Phenotypes) = split(/\t/, $line);
		my ($ing_id, $ing_name) = split(/\s\(/, $pathway);
		$ing_name =~ s/\)$//;
	#	skip unknown pathways, this should not hit anything
		if ($Ing_2_idClass{$ing_id}{ID} !~ /\d/) {
			log_err("Can't find the class for pathway '$ing_id' ($ing_name).");
			next;
		}

		foreach $phenotype (@Phenotypes) {
			my ($id_name, $enrich, $pval, $qval, $cnt) = split(/\|/, $phenotype);
			my $id = $id_name;
			$id =~ s/^(\S+)\s+.+/$1/;
			if ($Phenotype_Classes{$id}{Name} eq "") { next }	#	skip the phenotypes which don't have a name and hence aren't related to this toxicity

			if ($pval eq "") { next }
			elsif ($qval eq "") { next }
			elsif (($enrich >= $min_enrichment) && ($qval <= $max_qval) && ($cnt >= $min_genes)) {
				my $reason = "";
				$reason = "$cnt genes in the $ing_name pathway have the phenotype '$Phenotype_Classes{$id}{Name}'. This number of genes is a statistically significant ($qval) enrichment ($enrich). =&gt; $comment ($annotator on $date)";
				push(@{$HitPathways{$Ing_2_idClass{$ing_id}{ID}}}, $reason);
			} 
		}
	}
	close(FILE);

	$sql_file = './tmp_files/' . $0 . '_1.sql';
	open(OUTFILE, ">$sql_file");
	print OUTFILE "use $db_name;\n";
   print OUTFILE "SET autocommit=0;\n";
   print OUTFILE "START TRANSACTION;\n";
	foreach $id (keys %HitPathways) {
		print OUTFILE "INSERT INTO ToxLink (idToxTerm, Class_idClass) VALUES ('$toxterm_id', '$id');\n";
	}
   print OUTFILE "COMMIT;\n";
	close(OUTFILE);
	$cmd = $mysql_cmd . ' < ' . $sql_file;
	`$cmd`;

	%Class_2_ToxLinkId = ();
	my $sql = "SELECT idToxLink, Class_idClass FROM ToxLink WHERE idToxTerm = '$toxterm_id'";
	$statement = $db_handle->prepare($sql);
	$statement->execute;
	while (@row = $statement->fetchrow_array) {
		$Class_2_ToxLinkId{$row[1]} = $row[0];
	}

	$sql_file = './tmp_files/' . $0 . '_2.sql';
	open(OUTFILE, ">$sql_file");
	print OUTFILE "use $db_name;\n";
   print OUTFILE "SET autocommit=0;\n";
   print OUTFILE "START TRANSACTION;\n";
	foreach $id (keys %HitPathways) {
		my $toxlink_id = $Class_2_ToxLinkId{$id};
		foreach $evid (@{$HitPathways{$id}}) {
			$evid = make_sql_safe($evid);
			print OUTFILE "INSERT INTO ToxLink_Evid (idToxLink, Tox_Evidence, Create_Date, Update_Date) VALUES ('$toxlink_id', '$evid', NOW(), NOW());\n";
		}
	}
   print OUTFILE "COMMIT;\n";
	close(OUTFILE);
	$cmd = $mysql_cmd . ' < ' . $sql_file;
	`$cmd`;
}

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

sub make_xml_safe {
	my $text = $_[0];
	$text =~ s/\&/&amp;/g;
	$text =~ s/\>/&gt;/g;
	$text =~ s/\</&lt;/g;
	$text =~ s/\"/&quot;/g;
	return $text;
}

sub make_sql_safe {
	my $term = $_[0];
	$term =~ s/\\/\\\\/g;
	$term =~ s/'/\\'/g;
	$term =~ s/"/\\"/g;
	return $term;
}

