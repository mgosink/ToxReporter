#!/usr/bin/perl -I..

################################################################
#
#  Author(s) - Mark M. Gosink, Ph.D.
#  Company -   Pfizer Inc
#
#  Creation Date - March 16, 2009
#
#  Function - display potential toxicity information about a gene
#
################################################################

$| = 1;

use conf::ToxGene_Defaults;

use CGI qw/:standard/;

use DBI;

# vvvvvvvvvvvv Log the use of this application vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
#	Log the use of this application
eval {
	my $add = $ENV{HTTP_X_FORWARDED_FOR}?$ENV{HTTP_X_FORWARDED_FOR}:$ENV{REMOTE_ADDR};
	`/cssi/data/neusentis_data1/cgi/comptoxdev.pfizer.com/TOOLS/Log_Use $add $0`;
#	print " $add $0<BR>\n";
};
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

$gene_id = param(GENE);
$entrez = param(ENTREZ);
$html = param(HTML);
$xml = param(XML);

#	Set up mysql command and DBI mysql connection string
$dsn = "";
if ($MiscVariables{DATABASE_SOCKET} ne '') {
	$dsn = $MiscVariables{DATABASE_TYPE}
		. ':database=' . $MiscVariables{DATABASE_NAME}
		. ':mysql_socket=' . $MiscVariables{DATABASE_SOCKET};
}
else {
	$dsn = $MiscVariables{DATABASE_TYPE};
	my $host = $MiscVariables{DATABASE_HOST};
	my $port = $MiscVariables{DATABASE_PORT}
			. ':database=' . $MiscVariables{DATABASE_NAME}
			. ';host=' . $MiscVariables{DATABASE_HOST}
			. ';port=' . $MiscVariables{DATABASE_PORT};
}
$username = $MiscVariables{TOXGENE_USER};
$password = $MiscVariables{TOXGENE_PSWD};
$db_handle = DBI->connect( $dsn, $username, $password, { PrintError => 1 })
					or die "Can't connect to the database!!\n\n";

print header();

if ($html) {
	print start_html(-title=>"ToxReporter: Tox-At-A-Glance");
}
if ($xml) {
	print "<?xml version='1.0' encoding='UTF-8'?>\n";
}

#	gather general gene info
my $sql = "";
if (($entrez =~ /^\d+$/) && ($gene_id eq '')) {
	$sql = "SELECT G.idGene, G.entrezID"
			. " FROM Gene G"
			. " WHERE G.entrezID = '$entrez'";
}
elsif (($gene_id =~ /^\d+$/) && ($entrez eq '')) {
	$sql = "SELECT G.idGene, G.entrezID"
			. " FROM Gene G"
			. " WHERE G.idGene = '$gene_id'";
}
elsif ($entrez =~ /^ALL_HUMAN$/) {
	$sql = "SELECT idSpecies FROM Species WHERE ncbiTaxID = '9606'";
	$statement = $db_handle->prepare($sql);
	$statement->execute;
	@row = $statement->fetchrow_array;
	$species_id = $row[0];
	
	$sql = "SELECT G.idGene, G.entrezID"
			. " FROM Gene G"
			. " WHERE G.idSpecies = '$species_id'";
}
#print "SQL -'$sql'<BR>\n";
$statement = $db_handle->prepare($sql);
$statement->execute;
%GeneID_2_EntrezID = ();
while (@row = $statement->fetchrow_array) {
	$gene_id = $row[0];
	$entrez_id = $row[1];
	if (($gene_id =~ /^\d+$/) && ($entrez_id =~ /^\d+$/)) { $GeneID_2_EntrezID{$gene_id} = $entrez_id }
}

#	Display Tox-At-A-Glance
%GeneID_2_ToxAtAGlance = ();
if ($entrez =~ /^ALL_HUMAN$/) {
	$sql = "SELECT idGene, Annot_Text FROM Annotation WHERE Annot_Link = 'TOX_AT_GLANCE'";
}
else {
	$sql = "SELECT idGene, Annot_Text FROM Annotation WHERE idGene = '$gene_id' AND Annot_Link = 'TOX_AT_GLANCE'";
}
$statement = $db_handle->prepare($sql);
$statement->execute;
while (@row = $statement->fetchrow_array) {
	my $gene_id = $row[0];
	my $tox_percentiles = $row[1];
	$GeneID_2_ToxAtAGlance{$gene_id} = $tox_percentiles;
}
$statement->finish;
$db_handle->disconnect;

print "<TOXREPORT_MATRIX>\n";
foreach $gene_id (keys(%GeneID_2_EntrezID)) {
	my $entrez_id = $GeneID_2_EntrezID{$gene_id};
	my $tox_percentiles = $GeneID_2_ToxAtAGlance{$gene_id};
	print "  <ENTREZ ID='$entrez_id'>\n";
	my @Issues = split(/\|\|/, $tox_percentiles);
	my $base_link = $MiscLinks{TOXREPORTBASELINK2} . $entrez_id . ';TOXTERM=';
	foreach $issue (@Issues) {
		if ($xml) {
			my ($term, $score) = split(/\:/, $issue);
			my $link = $base_link . $IssueCatagories{$term};
			if (($term eq '') || ($score !~ /^[\d\.]+$/)) { next }
			print "    <SAFETY_LEX>\n",
					"      <TERM>$term</TERM>\n",
					"      <TOXREP_SCORE>$score</TOXREP_SCORE>\n",
					"      <TOXREP_LINK>$link</TOXREP_LINK>\n",
					"    </SAFETY_LEX>\n";
		}
		else { print "$issue\n" }
	}
	print "  </ENTREZ>\n";
}
print "</TOXREPORT_MATRIX>\n";
if ($html) {
	print end_html();
}



exit;
