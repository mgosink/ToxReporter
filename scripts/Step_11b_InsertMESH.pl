#!/usr/bin/perl -I..

#use warnings;
#use diagnostics;

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

$result = GetOptions ('user=s'			=> \$username,
								'pass=s'			=> \$password,
								'count:i'		=>	\$cutoff,
								'directory=s'	=>	\$parsed_mesh_dir);

#	Required files
$entrez2geneid = './tmp_files/Entrez_2_idGene.tmp';

$cutoff = int($cutoff);
if ($cutoff < 1) { $cutoff = 3 }
if (($username eq "") || ($password eq "") || ($parsed_mesh_dir eq "")) {
	die "\nUSAGE:\n\t$0 -u(ser) username -p(ass) password -c(ount) min_num_pubmed_refs(optional) -d(irectory) directory_of_mesh_parsed_medline\n\n";
}

$date = `date`;
chomp($date);
log_err("Running '$0' on '$date'.");
log_err("\tUsing '$cutoff' minimal publications.");
log_err("\tParsing files stored in '$parsed_mesh_dir/MESH'.");

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

#	build a hash mapping the MESH IDs to the database IDs
my %NativeID_to_DBid = ();
my %Name_to_DBid = ();
my $sql = "SELECT Class_Native_ID, idClass, Class_Name"
			. " FROM Class WHERE idClass_System"
			. " IN (SELECT idClass_System FROM Class_System"
			.				" WHERE Class_Sys_Name = 'MESH Trees')";
$statement = $db_handle->prepare($sql);
$statement->execute();
while(@row = $statement->fetchrow_array) {
	my $native_id = $row[0];
	my $class_id = $row[1];
	my $class_name = $row[2];
	$NativeID_to_DBid{$native_id} = $class_id;
	$Name_to_DBid{$class_name} .= "\t$class_id";
}
%ClassDecendants = ();
find_all_decendants();
$db_handle->{'mysql_use_result'}=0;
$statement->finish;

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

$db_handle->{'mysql_use_result'} = 1;
%GeneClass = ();
$sql = "SELECT idGene, idClass, idGene_Class FROM Gene_Class;";
$statement = $db_handle->prepare($sql);
$statement->execute();
while(@row = $statement->fetchrow_array) {
	$GeneClass{$row[0]}{$row[1]} = $row[2];
}
$statement->finish;

my $cmd = "ls -1 $parsed_mesh_dir\/MESH";
@Files = split(/\n/, `$cmd`);
#	Capture all the direct references for a gene to a MESH term
%ClassGeneRefs = ();
foreach $file (@Files) {
	my $mesh_term = $file;
	$mesh_term =~ s/_/ /g;
	my $class_ids = $Name_to_DBid{$mesh_term};
	$class_ids =~ s/^\t+//;
	my @ClassIDs = split(/\t+/, $class_ids);
	open (FILE, "$parsed_mesh_dir\/MESH\/$file");
	while ($line = <FILE>) {
		chomp($line);
		my @Entries = split(/\t/, $line);
		foreach $entry (@Entries) {
			my ($entrez_id, $refs) = split(/\|\|/, $entry);
			$refs =~ s/^\://;
			my @IndividRefsInfo = split(/\:/, $refs);
			foreach $refinfo (@IndividRefsInfo) {
				my ($major_minor, $pmid) = split(/\|/, $refinfo);
				foreach $class_id (@ClassIDs) {
					$ClassGeneRefs{$class_id}{$entrez_id}{$pmid} = 'T';
				}
			}
		}
	}
	close(FILE);
}
#	Capture all the indirect (child) references for a gene to a MESH term
foreach $class_id (keys(%ClassGeneRefs)) {
	foreach $desendant_id (keys (%{$ClassDecendants{$class_id}})) {
		my @DecendantsGenes = keys(%{$ClassGeneRefs{$desendant_id}});
		foreach $decend_gene (@DecendantsGenes) {
			my @DescGeneRefs = keys(%{$ClassGeneRefs{$desendant_id}{$decend_gene}});
			foreach $decend_gene_pmid (@DescGeneRefs) {
				$ClassGeneRefs{$class_id}{$decend_gene}{$decend_gene_pmid} = 'T';
			}
		}
	}
}

$sql_file_1 = $parsed_mesh_dir . '/MESH_c_1.sql';
open(OUTFILE, ">$sql_file_1");
print OUTFILE "use $db_name;\n";
print OUTFILE "SET autocommit=0;\n";
print OUTFILE "START TRANSACTION;\n";
foreach $class_id (keys %ClassGeneRefs) {
	if ($class_id !~ /^\d+$/) { next }	#	skip class IDs that don't contain a number
	foreach $entrez_id (keys(%{$ClassGeneRefs{$class_id}})) {
		my $gene_id = $Entrez2Gene{$entrez_id};
		if ($gene_id !~ /^\d+$/) { next }	#	skip genes IDs that don't contain a number
		my @PMIDs = keys(%{$ClassGeneRefs{$class_id}{$entrez_id}});
		my $pub_cnt = $#PMIDs + 1;
		if ($pub_cnt < $cutoff) { next }
		print OUTFILE "# Entrez:$entrez_id\tGI:$gene_id\tIDClass:$class_id\tnumPMIDs:$pub_cnt\n";
		if (defined $GeneClass{$gene_id}{$class_id}) { next }
		else {
			print OUTFILE "INSERT INTO Gene_Class (idGene, idClass) VALUES ('$gene_id', '$class_id');\n";
		}
	}
}
print OUTFILE "COMMIT;\n";
close(OUTFILE);

$date = `date`;
chomp($date);
$cmd = $mysql_cmd . ' < ' . $sql_file_1;
log_err("\t... loading '$sql_file_1' on '$date' with CMD - '$cmd'.");
`$cmd`;

$date = `date`;
chomp($date);
log_err("\t...completed loading '$sql_file_1' on '$date'.");


#	Build a 2D hash to lookup idGene_Class
$db_handle->{'mysql_use_result'} = 1;
%GeneClass = ();
$sql = "SELECT idGene, idClass, idGene_Class FROM Gene_Class;";
$statement = $db_handle->prepare($sql);
$statement->execute();
while(@row = $statement->fetchrow_array) {
	$GeneClass{$row[0]}{$row[1]} = $row[2];
}
$db_handle->{'mysql_use_result'}=0;
$statement->finish;
$db_handle->disconnect;

#	Create and run SQL to load Gene to Class links
$sql_file_2 = $parsed_mesh_dir . '/MESH_c_2.sql';
open(OUTFILE, ">$sql_file_2");
print OUTFILE "use $db_name;\n";
print OUTFILE "SET autocommit=0;\n";
print OUTFILE "START TRANSACTION;\n";
open(FILE, "$sql_file_1");
while ($line = <FILE>) {
	chomp($line);
	if ($line =~ /^#\s+Entrez:(\d+)\s+GI:(\d+)\s+IDClass:(\d+)\s+numPMIDs:(\d+)/) {
		my $id_gene = $2;
		my $id_class = $3;
		my $pub_cnt = $4;
		my $evid_score = $pub_cnt;
		my $evid_text = make_sql_safe("Found '$pub_cnt' publications after scanning Medline on '$date'.");
		my $id_gene_class = $GeneClass{$id_gene}{$id_class};
		if (defined $id_gene_class) {
			print OUTFILE "INSERT INTO Class_Evid (idGene_Class, Evid_Type, Evidence, Evid_score, Create_Date, Update_Date)"
								. " VALUES ('$id_gene_class', 'PUBMED_MESH', '$evid_text', '$evid_score', NOW(), NOW());\n";
		}
		else {
			log_err("ERROR: Couldn't insert class_evid couldn't find 1 or the other of IDgene:'$id_gene',IDclass:'$id_class','$evid_text'");
		}
	}
}
close(FILE);
print OUTFILE "COMMIT;\n";
close(OUTFILE);
$date = `date`;
chomp($date);
log_err("\t... loading '$sql_file_2' on '$date'.");
$cmd = $mysql_cmd . ' < ' . $sql_file_2;
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

sub find_all_decendants {
	my @ClassIDs = ();
	foreach $native_id (keys %NativeID_to_DBid) { push(@ClassIDs, $NativeID_to_DBid{$native_id}) }
	my $sql = 'SELECT Parent_idClass, Child_idClass FROM Class_Parent WHERE Parent_idClass IN (' . join(", ", @ClassIDs) . ');';
	$statement = $db_handle->prepare($sql);
	$statement->execute();
	%ParentChild = ();
	while(@row = $statement->fetchrow_array) {
		$ParentChild{$row[0]}{$row[1]} = 'T';
	}
	foreach $parent_id (keys %ParentChild) {
		find_children($parent_id, $parent_id);
	}
}

sub find_children {
	my $patriarch = $_[0];
	my $starting_parent = $_[1];
	foreach $child_id (keys %{$ParentChild{$starting_parent}}) {
		$ClassDecendants{$patriarch}{$child_id} = 'T';
		if (defined $ParentChild{$child_id}) { find_children($patriarch, $child_id) }
	}
}


