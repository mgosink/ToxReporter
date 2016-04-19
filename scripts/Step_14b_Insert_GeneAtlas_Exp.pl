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

%Tissue_2_idClass = ();
my $sql = "SELECT CS.Class_Sys_Name, C.Class_Name, C.idClass"
			. " FROM Class_System CS, Class C"
			. " WHERE CS.Class_Sys_Name LIKE 'Microarray_GeneAtlas_%'"
			. " AND CS.idClass_System = C.idClass_System";
$statement = $db_handle->prepare($sql);
$statement->execute();
while (@row = $statement->fetchrow_array) {
	my $class_sys_name = $row[0];
	my $tissue = $row[1];
	my $class_id = $row[2];
	$Tissue_2_idClass{$class_sys_name}{$tissue} = $class_id;
}

%Gene_2_Tissue = ();
my $files = $SetupFiles{HUM_EXP_DATA} . '||' . $SetupFiles{MOU_EXP_DATA};
@Data_Files = split(/\|\|/, $files);
foreach $filename (@Data_Files) {
	my $chip = $filename;
	$chip =~ s/\.soft//;
	$chip =~ s/^.+\/([^\/]+)$/$1/;
	open (FILE, $filename);
	my %Idx_2_Header = ();
	my %Sample_2_Tissue = ();
	my $found_data = 'F';
	my ($affy_id_col, $gene_id_col) = -1;
	my @ColumnsHeaders = ();
	while ($line = <FILE>) {
		$line =~ s/[\n\r\f]+//g;

		if ($line =~ /^\!subset_description = (.+)/) {
			$current_tissue = $1;
		}
		elsif ($line =~ /^\!dataset_platform_organism = (.+)/) {
			$current_organism = $1;
			if ($current_organism eq 'Mus musculus') { $tissue_system = 'Microarray_GeneAtlas_Mouse' }
			elsif ($current_organism eq 'Homo sapiens') { $tissue_system = 'Microarray_GeneAtlas_Human' }
		}
		elsif ($line =~ /^\!subset_sample_id =\s*(.+)/) {
			my ($s1, $s2) = split(/\s*,\s*/, $1);
			$Sample_2_Tissue{$s1} = $current_tissue;
			$Sample_2_Tissue{$s2} = $current_tissue;
		}

		if ($line =~ /^\!dataset_table_begin/) {
			$found_data = 'T';
			$line = <FILE>;
			$line =~ s/[\n\r\f]+//g;
			@ColumnsHeaders = split(/\t/, $line);
			next;
		}

		if ($found_data ne 'T') { next }
		my @Data = split(/\t/, $line);
		my $affy_id = $Data[0];
		my $id_gene = $Affy_2_Gene{$affy_id};
		if ($id_gene !~ /^\d+$/) { next }		#	skip unmapped affy IDs
		my %Data4Probe = ();
		my $line_total = 0;
		for ($idx = 2; $idx <= $#Data; $idx++) {
			my $current_tissue = $Sample_2_Tissue{$ColumnsHeaders[$idx]};
			my $data = $Data[$idx] + 0;
			$Data4Probe{$current_tissue} += $data;
			$line_total += $data;
		}
		if ($line_total <= 0) { next }	#	skip lines with no data
		my @SortedKeys = sort {$Data4Probe{$a} <=> $Data4Probe{$b}} (keys %Data4Probe);
		my $num_tissues = $#SortedKeys + 1;
		my $mid_idx = int($num_tissues / 2);
		my $median_value = $Data4Probe{$SortedKeys[$mid_idx]};
		my $expected_skew = 1 / $num_tissues;
		foreach $tissue (@SortedKeys) {
			my $id_tissue = $Tissue_2_idClass{$tissue_system}{$tissue};
			if ($id_tissue !~ /^\d+$/) { next }		#	skip entry where the tissue isn't mapped to the database
			my $data = $Data4Probe{$tissue};
			my $skew = $data / $line_total;
			my $med_fc = round(($data / $median_value), 2);
			my $skew_fc = round(($skew / $expected_skew), 2);
			$skew = round($skew, 4);
			if (($skew_fc >= 2.0) || ($med_fc >= 1.0)) {
				$Gene_2_Tissue{$id_gene}{$id_tissue} .= "Based on probeset - '$affy_id' ($chip), the gene is expressed '$med_fc' times the median across the tissues. (Skew - '$skew ($skew_fc X expected))\n";
			}
		}
	}
}

$geneatlas_sql_file = './tmp_files/Insert_GeneAtlas_gene2tis_1.sql';
open(ATLAS_OUTFILE, ">$geneatlas_sql_file");
print ATLAS_OUTFILE "use $db_name;\n";
print ATLAS_OUTFILE "SET autocommit=0;\n";
print ATLAS_OUTFILE "START TRANSACTION;\n";
foreach $id_gene (keys %Gene_2_Tissue) {
	foreach $id_tissue (keys %{$Gene_2_Tissue{$id_gene}}) {
		print ATLAS_OUTFILE "INSERT INTO Gene_Class (idGene, idClass) VALUES ('$id_gene', '$id_tissue');\n";
	}
}
print ATLAS_OUTFILE "COMMIT;\n";
close(ATLAS_OUTFILE);
$date = `date`;
chomp($date);
log_err("\t... loading '$geneatlas_sql_file' on '$date'.");
$cmd = $mysql_cmd . ' < ' . $geneatlas_sql_file;
`$cmd`;
$date = `date`;
chomp($date);
log_err("\t... finished loading '$geneatlas_sql_file' on '$date'.");

%GeneClass_2_ID = ();
my $sql = "SELECT idGene, idClass, idGene_Class FROM Gene_Class";
$statement = $db_handle->prepare($sql);
$statement->execute();
while (@row = $statement->fetchrow_array) {
	my $gene_id = $row[0];
	my $class_id = $row[1];
	$GeneClass_2_ID{$gene_id}{$class_id} = $row[2];
}

$geneatlas_sql_file = './tmp_files/Insert_GeneAtlas_gene2tis_2.sql';
open(ATLAS_OUTFILE, ">$geneatlas_sql_file");
print ATLAS_OUTFILE "use $db_name;\n";
print ATLAS_OUTFILE "SET autocommit=0;\n";
print ATLAS_OUTFILE "START TRANSACTION;\n";
foreach $id_gene (keys %Gene_2_Tissue) {
	foreach $id_tissue (keys %{$Gene_2_Tissue{$id_gene}}) {
		my $geneclass_id = $GeneClass_2_ID{$id_gene}{$id_tissue};
		my $evidence = $Gene_2_Tissue{$id_gene}{$id_tissue};
		foreach $evid_item (split(/\n/, $evidence)) {
			my $evid = make_sql_safe($evid_item);
			print ATLAS_OUTFILE "INSERT INTO Class_Evid (idGene_Class, Evid_Type, Evidence, Create_Date, Update_Date) VALUES ('$geneclass_id', 'mRNA_expression', '$evid', NOW(), NOW());\n";
		}
	}
}
print ATLAS_OUTFILE "COMMIT;\n";
close(ATLAS_OUTFILE);
$date = `date`;
chomp($date);
log_err("\t... loading '$geneatlas_sql_file' on '$date'.");
$cmd = $mysql_cmd . ' < ' . $geneatlas_sql_file;
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

sub round {
	my $value = $_[0];
	my $places = $_[1];
	return (int($value * 10**$places) / 10**$places);
}
