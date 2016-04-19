#!/usr/bin/perl -I..

################################################################
#
#  Author(s) - Mark M. Gosink, Ph.D.
#  Company -   DSRD, Pfizer Inc.
#
#  Creation Date - Fri May 28 14:38:26 EDT 2010
#  Modified - 
#
#  Function - 
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

#	first we need to ensure that all Affymetrix IDs used in the 
#	Gene Atlas chips have been entered into the database
@Annotation_Files = split(/\|\|/, $SetupFiles{EXP_ANN_FILES});
	#	make a hash linking Affy IDs to Entrez IDs
%Affy_2_Entrez = ();
foreach $filename (@Annotation_Files) {
	open (FILE, $filename);
	my $found_data = 'F';
	my ($affy_id_col, $entrez_id_col) = -1;
	while ($line = <FILE>) {
		if ($line =~ /^\!platform_table_begin/) {
			$found_data = 'T';
			$line = <FILE>;
			$line =~ s/[\n\r\f]+//g;
			my @ColumnsHeaders = split(/\t/, $line);
			for ($idx = 0; $idx <= $#ColumnsHeaders; $idx++) {
				$header = $ColumnsHeaders[$idx];
				if ($header eq 'ID') { $affy_id_col = $idx }
				if ($header eq 'Gene ID') { $entrez_id_col = $idx }
			}
			next;
		}
		if ($found_data ne 'T') { next }
		$line =~ s/[\n\r\f]+//g;
		my @Data = split(/\t/, $line);
		my $affy_id = $Data[$affy_id_col];
		my $entrez_id = $Data[$entrez_id_col];
		if (($affy_id eq '') || ($entrez_id !~ /^\d+$/)) { next }
		$Affy_2_Entrez{$affy_id} = $entrez_id;
	}
	close(FILE);
}
	#	build a hash of mapped entrez ids to idGene
%Entrez_2_IDGene = ();
my $sql = "SELECT entrezID, idGene FROM Gene";
$statement = $db_handle->prepare($sql);
$statement->execute();
while (@row = $statement->fetchrow_array) { $Entrez_2_IDGene{$row[0]} = $row[1] }
#	build a hash of mapped affy probes
%Affy_2_Gene = ();
my $sql = "SELECT Xref_ID, idGene FROM Xref  WHERE Xref_Source = 'AFFY_PROBESET'";
$statement = $db_handle->prepare($sql);
$statement->execute();
while (@row = $statement->fetchrow_array) {
	my $affy_id = $row[0];
	my $id_gene = $row[1];
	$Affy_2_Gene{$affy_id} = $id_gene;
}
	#	map the Affy ids which haven't already been mapped yet
$xref_sql_file = './tmp_files/Insert_GeneAtlas.xrefs.sql';
open(XREF_OUTFILE, ">$xref_sql_file");
print XREF_OUTFILE "use $db_name;\n";
print XREF_OUTFILE "SET autocommit=0;\n";
print XREF_OUTFILE "START TRANSACTION;\n";
$need_to_add_flag = 'F';
foreach $affy_id (keys %Affy_2_Entrez) {
	if (defined $Affy_2_Gene{$affy_id}) { next }
	else {
		my $idgene = $Entrez_2_IDGene{$Affy_2_Entrez{$affy_id}};
		if (($affy_id ne '') && ($idgene =~ /^\d+$/)) {
			print XREF_OUTFILE "INSERT INTO Xref (idGene, Xref_Source, Xref_ID) VALUES ('$idgene', 'AFFY_PROBESET', '$affy_id');\n";
			$need_to_add_flag = 'T';
		}
	}
}
print XREF_OUTFILE "COMMIT;\n";
close(XREF_OUTFILE);
if ($need_to_add_flag eq 'T') {
	$date = `date`;
	chomp($date);
	log_err("\t... loading '$xref_sql_file' on '$date'.");
	$cmd = $mysql_cmd . ' < ' . $xref_sql_file;
	`$cmd`;
	$date = `date`;
	chomp($date);
	log_err("\t... finished loading '$xref_sql_file' on '$date'.");
}

#	add a system_class entry for the mouse array if not already done
my $sql = "SELECT idClass_System FROM Class_System WHERE Class_Sys_Name = 'Microarray_GeneAtlas_Mouse'";
$statement = $db_handle->prepare($sql);
$statement->execute();
@row = $statement->fetchrow_array;
$mouse_array_sysclass_id = $row[0];
if ($mouse_array_sysclass_id <= 0) {
	my $sql = "INSERT INTO Class_System (Class_Sys_Name, Class_Sys_Desc) VALUES('Microarray_GeneAtlas_Mouse', 'Tissues extracted from Mouse Gene Atlas microarray GDS592')";
	$statement = $db_handle->prepare($sql);
	$statement->execute();
	$sql = "SELECT idClass_System FROM Class_System WHERE Class_Sys_Name = 'Microarray_GeneAtlas_Mouse'";
	$statement = $db_handle->prepare($sql);
	$statement->execute();
	@row = $statement->fetchrow_array;
	$mouse_array_sysclass_id = $row[0];
	@Data_Files = split(/\|\|/, $SetupFiles{MOU_EXP_DATA});
	%AllTissues = ();
	foreach $filename (@Data_Files) {
		open (FILE, $filename);
		my $found_data = 'F';
		my ($affy_id_col, $gene_id_col) = -1;
		my @ColumnsHeaders = ();
		while ($line = <FILE>) {
			$line =~ s/[\n\r\f]+//g;

			if ($line =~ /^\!subset_description = (.+)/) {
				$current_tissue = $1;
				$line = <FILE>;
				$line =~ s/[\n\r\f]+//g;
				if ($line =~ /^\!subset_sample_id = (.+)/) {
					$AllTissues{$current_tissue} .= ",$1";
				}
			}
			if ($line =~ /^\!dataset_table_begin/) { last}
		}
	}
	$tissue_sql_file = './tmp_files/Insert_GeneAtlas.m_tissue.sql';
	open(TISS_OUTFILE, ">$tissue_sql_file");
	print TISS_OUTFILE "use $db_name;\n";
   print TISS_OUTFILE "SET autocommit=0;\n";
   print TISS_OUTFILE "START TRANSACTION;\n";
	foreach $tissue (keys %AllTissues) {
		my $safe_tissue = make_sql_safe($tissue);
		my $native_id = make_sql_safe($AllTissues{$tissue});
		$native_id =~ s/^,//;
		print TISS_OUTFILE "INSERT INTO Class (idClass_System, Class_Name, Class_Native_ID) VALUES ('$mouse_array_sysclass_id', '$safe_tissue', '$native_id');\n";
	}
   print TISS_OUTFILE "COMMIT;\n";
	close(TISS_OUTFILE);
	$cmd = $mysql_cmd . ' < ' . $tissue_sql_file;
	`$cmd`;
}

#	add a system_class entry for the human arrays if not already done
my $sql = "SELECT idClass_System FROM Class_System WHERE Class_Sys_Name = 'Microarray_GeneAtlas_Human'";
$statement = $db_handle->prepare($sql);
$statement->execute();
@row = $statement->fetchrow_array;
$human_array_sysclass_id = $row[0];
if ($human_array_sysclass_id <= 0) {
	my $sql = "INSERT INTO Class_System (Class_Sys_Name, Class_Sys_Desc) VALUES('Microarray_GeneAtlas_Human', 'Tissues extracted from Human Gene Atlas microarray GDS596')";
	$statement = $db_handle->prepare($sql);
	$statement->execute();
	$sql = "SELECT idClass_System FROM Class_System WHERE Class_Sys_Name = 'Microarray_GeneAtlas_Human'";
	$statement = $db_handle->prepare($sql);
	$statement->execute();
	@row = $statement->fetchrow_array;
	$human_array_sysclass_id = $row[0];
	@Data_Files = split(/\|\|/, $SetupFiles{HUM_EXP_DATA});
	%AllTissues = ();
	foreach $filename (@Data_Files) {
		open (FILE, $filename);
		my $found_data = 'F';
		my ($affy_id_col, $gene_id_col) = -1;
		my @ColumnsHeaders = ();
		while ($line = <FILE>) {
			$line =~ s/[\n\r\f]+//g;

			if ($line =~ /^\!subset_description = (.+)/) {
				$current_tissue = $1;
				$line = <FILE>;
				$line =~ s/[\n\r\f]+//g;
				if ($line =~ /^\!subset_sample_id = (.+)/) {
					$AllTissues{$current_tissue} .= ",$1";
				}
			}
			if ($line =~ /^\!dataset_table_begin/) { last}
		}
	}
	$tissue_sql_file = './tmp_files/Insert_GeneAtlas.h_tissue.sql';
	open(TISS_OUTFILE, ">$tissue_sql_file");
	print TISS_OUTFILE "use $db_name;\n";
   print TISS_OUTFILE "SET autocommit=0;\n";
   print TISS_OUTFILE "START TRANSACTION;\n";
	foreach $tissue (keys %AllTissues) {
		my $safe_tissue = make_sql_safe($tissue);
		my $native_id = make_sql_safe($AllTissues{$tissue});
		$native_id =~ s/^,//;
		print TISS_OUTFILE "INSERT INTO Class (idClass_System, Class_Name, Class_Native_ID) VALUES ('$human_array_sysclass_id', '$safe_tissue', '$native_id');\n";
	}
   print TISS_OUTFILE "COMMIT;\n";
	close(TISS_OUTFILE);
	$cmd = $mysql_cmd . ' < ' . $tissue_sql_file;
	`$cmd`;
}


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
