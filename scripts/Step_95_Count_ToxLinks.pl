#!/usr/bin/perl -I..

################################################################
#
#  Author(s) - Mark M. Gosink, Ph.D.
#  Company -   DSRD, Pfizer Inc.
#
#  Creation Date - Tue May 25 08:27:21 EDT 2010
#  Modified - 
#
#  Function - Counts number of total & categorical links
#					in pre-defined tox categories
#
################################################################

use conf::ToxGene_Defaults;

use POSIX qw(log10);
use DBI;

use Getopt::Long;

$result = GetOptions ('user=s'			=> \$username,
								'pass=s'			=> \$password);

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

$r_app_loc = $SetupFiles{R_APPLICATION};

#	Toxicity Categories to count
@ToxCategories = (
	'Adipose',
	'Cardiovascular_System',
	'Dermal',
	'Endocrine_System',
	'Gastrointestinal_System',
	'Hepatobiliary_System',
	'Immune_System',
	'Musculoskeletal_System',
	'Nervous_System',
	'Ocular',
	'Pulmonary_System',
	'Renal_System',
	'Reproductive_System',
	'Carcinogenicity',
	'Inflammation',
	'Mitochondrial_toxicity'
);

#	Class categories to include in counts
@ClassCategories = (
	'GO_Function',
	'GO_Process',
	'GO_Component',
	'Pathways',
	'MESH_Publications',
	'Mouse_Phenotypes',
	'Microarray_GeneAtlas_Mouse',
	'Microarray_GeneAtlas_Human',
	'Precision_Medicine'
);

#	Xref categories to include in counts
@XrefCategories = (
	'OMIM'
);

#	load all generic gene info
my %Genes = ();
my $sql = "SELECT G.idGene, G.entrezID, G.GeneBook_ID, G.idHomolog, S.commonName"
			. " FROM Gene G, Species S"
			. " WHERE G.idSpecies IN (SELECT idSpecies FROM Species WHERE commonName = 'Human' OR commonName = 'Mouse')"
			. " AND G.idSpecies = S.idSpecies";
$statement = $db_handle->prepare($sql);
$statement->execute;
while (@row = $statement->fetchrow_array) {
	my $gene_id = $row[0];
	$Genes{$gene_id}{ENTREZ} = $row[1];
	$Genes{$gene_id}{GENEBOOK} = $row[2];
	$Genes{$gene_id}{HOMOLOG} = $row[3];
	$Genes{$gene_id}{SPECIES} = $row[4];
}
my $sql = "SELECT G.idGene, N.Name"
			. " FROM Gene G, Names N"
			. " WHERE G.idSpecies IN (SELECT idSpecies FROM Species WHERE commonName = 'Human' OR commonName = 'Mouse')"
			. " AND N.idGene = G.idGene"
			. " AND N.Name_Type = 'Symbol'";
$statement = $db_handle->prepare($sql);
$statement->execute;
while (@row = $statement->fetchrow_array) {
	my $gene_id = $row[0];
	$Genes{$gene_id}{SYMBOL} = $row[1];
}


#	create a hash of all tox IDs and their children to their tox categories (an ID may have multiple tox categories)
%ToxID_2_ToxCat = ();
foreach $tox_term (@ToxCategories) {
	my $sql = "SELECT idToxTerm FROM ToxTerm WHERE Tox_Term = '$tox_term'";
	my $statement = $db_handle->prepare($sql);
	$statement->execute;
	@row = $statement->fetchrow_array;
	my $id_tox = $row[0];
	$ToxID_2_ToxCat{$id_tox}{$tox_term} = 'T';
	find_child_tox($id_tox, $tox_term);
}

#	Map all class IDs to their tox IDs
#		note: classes can have multiple tox links
%Class_2_ToxID = ();
$sql = "SELECT Class_idClass, idToxTerm FROM ToxLink WHERE Class_idClass > 0";
$statement = $db_handle->prepare($sql);
$statement->execute;
while (@row = $statement->fetchrow_array) {
	$Class_2_ToxID{$row[0]}{$row[1]} = 'T';
}

#	Map all class IDs to their tox IDs
#		note: classes can have multiple tox links
%Xref_2_ToxID = ();
$sql = "SELECT Xref_idXref, idToxTerm FROM ToxLink WHERE Xref_idXref > 0";
$statement = $db_handle->prepare($sql);
$statement->execute;
while (@row = $statement->fetchrow_array) {
	$Xref_2_ToxID{$row[0]}{$row[1]} = 'T';
}

#	Map all Class IDs to their Category
#		note: IDs can have multiple links
%ClassID_2_Category = ();
%ClassName_2_ID = ();
foreach $class_id (keys %Class_2_ToxID) {
	my $sql = "SELECT CS.Class_Sys_Name, C.Class_Desc, C.Class_Name"
				. " FROM Class C, Class_System CS"
				. " WHERE C.idClass = '$class_id'"
				. " AND CS.idClass_System = C.idClass_System";
	$statement = $db_handle->prepare($sql);
	$statement->execute;
	my @row = $statement->fetchrow_array;
	$ClassName_2_ID{$row[2]}{$class_id} = 'T';
	if ($row[0] eq 'Ingenuity Pathways') { $ClassID_2_Category{$class_id} = 'Pathways' }
	elsif ($row[0] eq 'Mouse Mutant Phenotypes') { $ClassID_2_Category{$class_id} = 'Mouse_Phenotypes' }
	elsif ($row[0] eq 'MESH Trees') { $ClassID_2_Category{$class_id} = 'MESH_Publications' }
	elsif ($row[0] eq 'Microarray_GeneAtlas_Mouse') { $ClassID_2_Category{$class_id} = 'Microarray_GeneAtlas_Mouse' }
	elsif ($row[0] eq 'Microarray_GeneAtlas_Human') { $ClassID_2_Category{$class_id} = 'Microarray_GeneAtlas_Human' }
	elsif ($row[0] eq 'Genetic Association Database') { $ClassID_2_Category{$class_id} = 'Precision_Medicine' }
	elsif ($row[0] eq 'Genome-Wide Association Studies') { $ClassID_2_Category{$class_id} = 'Precision_Medicine' }
	elsif ($row[0] eq 'Gene Ontologies') {
		if ($row[1] =~ /^molecular_function/) { $ClassID_2_Category{$class_id} = 'GO_Function' }
		elsif ($row[1] =~ /^biological_process/) { $ClassID_2_Category{$class_id} = 'GO_Process' }
		elsif ($row[1] =~ /^cellular_component/) { $ClassID_2_Category{$class_id} = 'GO_Component' }
	}
}
#	load tox class categories counts
my %Gene_2_ClassName = ();
$sql = "SELECT GC.idClass, GC.idGene, C.Class_Name"
		. " FROM Gene_Class GC, Class C"
		. " WHERE C.idClass = GC.idClass";
$statement = $db_handle->prepare($sql);
$statement->execute;
while (@row = $statement->fetchrow_array) {
	my $class_id = $row[0];
	my $class_name = $row[2];
	if (not defined $Class_2_ToxID{$class_id}) { next } 	#	skip class ids which aren't Tox related
	my $gene_id = $row[1];
	$Gene_2_ClassName{$gene_id}{$class_name} = 'T';
}
foreach $gene_id (keys %Gene_2_ClassName) {
	foreach $class_name (keys %{$Gene_2_ClassName{$gene_id}}) {
		my %GeneClassToxAssoc = ();
		foreach $class_id (keys %{$ClassName_2_ID{$class_name}}) {
			my $class_category = $ClassID_2_Category{$class_id};
			foreach $tox_id (keys %{$Class_2_ToxID{$class_id}}) {
				foreach $toxterm (keys %{$ToxID_2_ToxCat{$tox_id}}) {
					if ($GeneClassToxAssoc{$gene_id}{$class_name}{$toxterm} eq 'T') { next }
					else { $GeneClassToxAssoc{$gene_id}{$class_name}{$toxterm} = 'T' }
					my $cat_weight = 1;
					if ($class_category =~ /^Microarray_/) { $cat_weight = 0.2 }
					$Genes{$gene_id}{$toxterm}{TOTALS} += $cat_weight;
				}
			}
		}
	}
}

#	Map all Class IDs to their Category
#		note: IDs can have multiple links
%XrefID_2_Category = ();
%Xref_2_ID = ();
foreach $xref_id (keys %Xref_2_ToxID) {
	my $sql = "SELECT Xref_Source FROM Xref"
				. " WHERE idXref = '$xref_id'";
	$statement = $db_handle->prepare($sql);
	$statement->execute;
	my @row = $statement->fetchrow_array;
	$Xref_2_ID{$row[0]}{$xref_id} = 'T';
	if ($row[0] eq 'MIM') { $XrefID_2_Category{$xref_id} = 'Precision_Medicine' }
	elsif ($row[0] eq 'MIM_DOM') { $XrefID_2_Category{$xref_id} = 'Precision_Medicine' }
}
#	load tox class categories counts
my %Gene_2_Xref = ();
$sql = "SELECT idXref, idGene FROM Xref";
$statement = $db_handle->prepare($sql);
$statement->execute;
while (@row = $statement->fetchrow_array) {
	my $xref_id = $row[0];
	if (not defined $Xref_2_ToxID{$xref_id}) { next } 	#	skip class ids which aren't Tox related
	my $gene_id = $row[1];
	$Gene_2_Xref{$gene_id}{$xref_id} = 'T';
}
foreach $gene_id (keys %Gene_2_Xref) {
	foreach $xref_id (keys %{$Gene_2_Xref{$gene_id}}) {
		my %GeneXrefToxAssoc = ();
		my $xref_category = $XrefID_2_Category{$xref_id};
		foreach $tox_id (keys %{$Xref_2_ToxID{$xref_id}}) {
			foreach $toxterm (keys %{$ToxID_2_ToxCat{$tox_id}}) {
				if ($GeneXrefToxAssoc{$gene_id}{$tox_id}{$toxterm} eq 'T') { next }
				else { $GeneXrefToxAssoc{$gene_id}{$tox_id}{$toxterm} = 'T' }
#				$Genes{$gene_id}{$toxterm}{$class_category}++;
				$Genes{$gene_id}{$toxterm}{TOTALS}++;
				my $cat_weight = 1;
				if ($class_category =~ /^Precision_Medicine/) { $cat_weight = 2.0 }
				$Genes{$gene_id}{$toxterm}{TOTALS} += $cat_weight;
			}
		}
	}
}

#	report Tox
foreach $species ('Human', 'Mouse') {
	$outfile = './tmp_files/' . $species . "_Toxicity.Counts";
	open (OUTFILE, ">$outfile");
	print OUTFILE "idGene\tEntrez\tHomolog\tGenebook";
	foreach $toxterm (@ToxCategories) { print OUTFILE "\t$toxterm" }
	print OUTFILE "\n";

	foreach $gene_id (keys %Genes) {
		if ($Genes{$gene_id}{SPECIES} ne $species) { next }	#	skip genes not in current species
		my $entrez = $Genes{$gene_id}{ENTREZ};
		my $symbol = $Genes{$gene_id}{SYMBOL};
		my $homolog = $Genes{$gene_id}{HOMOLOG};
		if (($homolog eq "") || ($homolog eq "N.A.")) { $homolog = 'NA' }
		my $genebook = $Genes{$gene_id}{GENEBOOK};
		if (($genebook eq "") || ($genebook eq "N.A.")) { $genebook = 'NA' }
		print OUTFILE "$gene_id",
				"\t$entrez",
				"\t$homolog",
				"\t$genebook";
		foreach $toxterm (@ToxCategories) {
			if (defined $Genes{$gene_id}{$toxterm}{TOTALS}) { print OUTFILE "\t", $Genes{$gene_id}{$toxterm}{TOTALS}; }
			else { print OUTFILE "\tNA"; }
		}
		print OUTFILE "\n";
	}
	close(OUTFILE);
}

$batch_file = './tmp_files/Human_R.cmds';
open(RFILE, ">$batch_file");
print RFILE "mydata<-read.table(file='./tmp_files/Human_Toxicity.Counts', header=T, na.string='NA', sep = \"\\t\")\n";
print RFILE "options(width=255)\nattach(mydata)\n";
foreach $toxterm (@ToxCategories) {
	print RFILE "#ToxTerm - $toxterm\nquantile($toxterm, seq(0,1,0.05), na.rm=T)\nsummary(log10($toxterm))\n";
}
my $r_cmd = "$r_app_loc CMD BATCH --vanilla $batch_file $batch_file.Rout";
`$r_cmd`;
%ToxPercentiles = ();
%ToxMinMax = ();
open (FILE, "$batch_file.Rout");
while ($line = <FILE>) {
	chomp($line);
	if ($line =~ /^> #ToxTerm - (.+)/) {
		$current_toxterm = $1;
		$line = <FILE>;
		$line = <FILE>;
		$line = <FILE>;
		chomp($line);
		$line =~ s/^\s*//;
		@{$ToxPercentiles{$current_toxterm}} = split(/\s+/, $line);
		$line = <FILE>;
		$line = <FILE>;
		$line = <FILE>;
		chomp($line);
		my @Vals = split(/\s+/, $line);
		$ToxMinMax{$current_toxterm}{MIN} = $Vals[1];
		$ToxMinMax{$current_toxterm}{MAX} = $Vals[6];
	}
}
close(FILE);
open (FILE, "./tmp_files/Human_Toxicity.Counts");
open (OUTFILE, ">./tmp_files/Human_Toxicity.Percentiles");
open (OUTFILEB, ">./tmp_files/Human_Toxicity.PercentLogMax");
$line = <FILE>;
print OUTFILE $line;
print OUTFILEB $line;
chomp($line);
@Headers = split(/\t/, $line);
while ($line = <FILE>) {
	chomp($line);
	my @Vals = split(/\t/, $line);
	print OUTFILE "$Vals[0]\t$Vals[1]\t$Vals[2]\t$Vals[3]\t";
	print OUTFILEB "$Vals[0]\t$Vals[1]\t$Vals[2]\t$Vals[3]\t";
	for ($idx = 4; $idx <= $#Vals; $idx++) {
		my $toxterm = $Headers[$idx];
		if ($Vals[$idx] eq 'NA') {
			print OUTFILE "\|\|$toxterm\:0.0";
			print OUTFILEB "\|\|$toxterm\:0.0";
		}
		else {
			my @Percentiles = @{$ToxPercentiles{$toxterm}};
			my $percentile = 0.00;
			my $higest_percentile =  $percentile;
			foreach $percentile_val (@Percentiles) {
				if ($Vals[$idx] >= $percentile_val) {
					$higest_percentile = $percentile;
					$percentile += 0.05;
				}
				else { last }
			}
			print OUTFILE "\|\|$toxterm\:$higest_percentile";
			if (($ToxMinMax{$toxterm}{MAX}-$ToxMinMax{$toxterm}{MIN}) > 0 ) {
				$percent_log_max = round((log10($Vals[$idx])-$ToxMinMax{$toxterm}{MIN})/($ToxMinMax{$toxterm}{MAX}-$ToxMinMax{$toxterm}{MIN}), 4);
			}
			else { $percent_log_max = 0 }
			print OUTFILEB "\|\|$toxterm\:$percent_log_max";
		}
	}
	print OUTFILE "\n";
	print OUTFILEB "\n";
}
close(OUTFILEB);
close(OUTFILE);
close(FILE);


$batch_file = './tmp_files/Mouse_R.cmds';
open(RFILE, ">$batch_file");
print RFILE "mydata<-read.table(file='./tmp_files/Mouse_Toxicity.Counts', header=T, na.string='NA', sep = \"\\t\")\n";
print RFILE "options(width=255)\nattach(mydata)\n";
foreach $toxterm (@ToxCategories) {
	print RFILE "#ToxTerm - $toxterm\nquantile($toxterm, seq(0,1,0.05), na.rm=T)\nsummary(log10($toxterm))\n";
}
my $r_cmd = "$r_app_loc CMD BATCH --vanilla $batch_file $batch_file.Rout";
`$r_cmd`;
%ToxPercentiles = ();
%ToxMinMax = ();
open (FILE, "$batch_file.Rout");
while ($line = <FILE>) {
	chomp($line);
	if ($line =~ /^> #ToxTerm - (.+)/) {
		$current_toxterm = $1;
		$line = <FILE>;
		$line = <FILE>;
		$line = <FILE>;
		chomp($line);
		$line =~ s/^\s*//;
		@{$ToxPercentiles{$current_toxterm}} = split(/\s+/, $line);
		$line = <FILE>;
		$line = <FILE>;
		$line = <FILE>;
		my @Vals = split(/\s+/, $line);
		$ToxMinMax{$current_toxterm}{MIN} = $Vals[1];
		$ToxMinMax{$current_toxterm}{MAX} = $Vals[6];
	}
}
close(FILE);
open (FILE, "./tmp_files/Mouse_Toxicity.Counts");
open (OUTFILE, ">./tmp_files/Mouse_Toxicity.Percentiles");
open (OUTFILEB, ">./tmp_files/Mouse_Toxicity.PercentLogMax");
$line = <FILE>;
print OUTFILE $line;
print OUTFILEB $line;
chomp($line);
@Headers = split(/\t/, $line);
while ($line = <FILE>) {
	chomp($line);
	my @Vals = split(/\t/, $line);
	print OUTFILE "$Vals[0]\t$Vals[1]\t$Vals[2]\t$Vals[3]\t";
	print OUTFILEB "$Vals[0]\t$Vals[1]\t$Vals[2]\t$Vals[3]\t";
	for ($idx = 4; $idx <= $#Vals; $idx++) {
		my $toxterm = $Headers[$idx];
		if ($Vals[$idx] eq 'NA') {
			print OUTFILE "\|\|$toxterm\:0.0";
			print OUTFILEB "\|\|$toxterm\:0.0";
		}
		else {
			my $toxterm = $Headers[$idx];
			my @Percentiles = @{$ToxPercentiles{$toxterm}};
			my $percentile = 0.00;
			my $higest_percentile =  $percentile;
			foreach $percentile_val (@Percentiles) {
				if ($Vals[$idx] >= $percentile_val) {
					$higest_percentile = $percentile;
					$percentile += 0.05;
				}
				else { last }
			}
			print OUTFILE "\|\|$toxterm\:$higest_percentile";
			$percent_log_max = round((log10($Vals[$idx])-$ToxMinMax{$toxterm}{MIN})/($ToxMinMax{$toxterm}{MAX}-$ToxMinMax{$toxterm}{MIN}), 4);
			print OUTFILEB "\|\|$toxterm\:$percent_log_max";
		}
	}
	print OUTFILE "\n";
	print OUTFILEB "\n";
}
close(OUTFILEB);
close(OUTFILE);
close(FILE);


exit;

sub make_sql_safe {
	my $term = $_[0];
	$term =~ s/\\/\\\\/g;
	$term =~ s/'/\\'/g;
	$term =~ s/"/\\"/g;
	return $term;
}

sub find_child_tox {
	my $parent_id = $_[0];
	my $toxterm = $_[1];
	my $sql = "SELECT Child_idToxTerm FROM ToxParent WHERE Parent_idToxTerm = '$parent_id'";
	my $statement = $db_handle->prepare($sql);
	$statement->execute;
	while (@row = $statement->fetchrow_array) {
		my $child_id = $row[0];
		$ToxID_2_ToxCat{$child_id}{$toxterm} = 'T';
		find_child_tox($child_id, $toxterm);
	}
	return;
}

sub round {
	my $value = $_[0];
	my $places = $_[1];
	return (int($value * 10**$places) / 10**$places);
}
