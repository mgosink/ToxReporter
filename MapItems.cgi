#!/usr/bin/perl -I..

################################################################
#
#  Author(s) - Mark M. Gosink, Ph.D.
#  Company     Pfizer Inc.
#
#  Creation Date - August 10, 2009
#
#  Function - display_classes
#				added index
#
################################################################

$| = 1;

use lib ("/home/gosinm/CGI/perl_lib", "/cssi/data/neusentis_data1/cgi/comptoxdev.pfizer.com/perl_lib", ".", "..");

use conf::ToxGene_Defaults;

use CGI qw/:standard/;

use DBI;

$fname = $0;
$fname =~ s/.+\/([^\/]+)$/$1/;

$query = new CGI;
$annotator = $query->cookie('TOX_MAP_ANNOTATOR');
my $comment = param(COMMENT);
$cookie = $query->cookie(-name=>"COMMENT", -value=>"$comment", -expires=>"+1M");

print header(-cookie=>$cookie);

$date = `date`;
chomp($date);

$image_path = $MiscVariables{IMAGE_PATH};
$dsrd_link = $MiscLinks{DSRD_HOME};

print start_html(-title=>"Mapped Toxicities", -style=>{'src'=>"$image_path/Style.css"},);

# vvvvvvvvvvvv Log the use of this application vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
#	Log the use of this application
eval {
	my $add = $ENV{HTTP_X_FORWARDED_FOR}?$ENV{HTTP_X_FORWARDED_FOR}:$ENV{REMOTE_ADDR};
	`/cssi/data/neusentis_data1/cgi/comptoxdev.pfizer.com/TOOLS/Log_Use $add $0`;
#	print " $add $0<BR>\n";
};
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

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

$parents = "";

$tox_sys_id = param(TOX_SYS_ID);
$tox_term = param(TOXTERM);
($tox_name, $tox_id, $native_id) = split(/\|/, $tox_term);

$tox_map_file = $tox_name . '.' . $native_id;
$tox_map_file =~ s/\//_/g;
$tox_map_file = './data/Edittable_SafeLex/' . $tox_map_file;

%Tox_2_Cat = ();
open(FILE, $tox_map_file);
while ($line = <FILE>) {
	chomp($line);
	my ($tox_id, $cat_id, $item_annotator, $item_date, $item_comment) = split(/\t/, $line);
	$Tox_2_Cat{$tox_id}{$cat_id}{KEEP_FLAG} = 'T';
	$Tox_2_Cat{$tox_id}{$cat_id}{ANNOTATOR} = $item_annotator;
	$Tox_2_Cat{$tox_id}{$cat_id}{DATE} = $item_date;
	$Tox_2_Cat{$tox_id}{$cat_id}{COMMENT} = $item_comment;
}
close(FILE);

my $class_sys_id = param(ClassID);
my $page_sys_id = param(PAGEID);
my $parent_list = param(PARENTLIST);
my @CategoryIDs = param(CATEGORY_ID);
my @SubtractCategoryIDs = param(SUBTRACT_CATEGORY_ID);
my $nativeid_list = '';
my $system_name = '';
foreach $item (@CategoryIDs) {
	my ($sys_name, $native_id) = split(/\|\|/, $item);
	if ($system_name eq '') { $system_name = $sys_name }
	$nativeid_list .= ", '$native_id'";
}
foreach $item (@SubtractCategoryIDs) {
	my ($sys_name, $native_id) = split(/\|\|/, $item);
	if ($system_name eq '') { $system_name = $sys_name }
	$nativeid_list .= ", '$native_id'";
}
$nativeid_list =~ s/^, //;
%CategoryInfo = ();

print '<DIV class="evid_view">';
print	'<table class="header">
			<tr>
				<td class="header_1">
					<a href="' . $dsrd_link .'"><img border="0" height=65px width=150px src="' . $image_path . '/DSRD.jpg" ALT="Drug Safety Research & Development"></a>
  				</td>
				<td class="header_2">
				<div class="header">
					<i><font color="blue">M</font>ap<font color="blue"> T</font>oxicities to <font color="orangered">C</font>ategories</i>
				</div>
  				</td>
			</tr>
		</table>';
print "\n";

print '<table class="menu" align="left"><tr><td class="menu_col"><table class="menu_table">
			<tr>
				<tr>
		  		 <td class="menu">
					 <A class="menu" href="ViewToxicities.cgi">
					 Search Tox Issues:
					 </A>
				 </td>
				</tr>
				<tr>
		  		 <td class="menu">
					 <A class="menu" href="SearchTargets.cgi">
					 Search for a Gene:
					 </A>
				 </td>
				</tr>
				<tr>
		  		 <td class="menu">
					 <A class="menu" href="ToxMatrixReport.cgi">
					 ToxMatrix Genes:
					 </A>
				 </td>
				</tr>
		</table></td><td valign="top">';
print '</td></tr></table>';

print '<DIV class="body_indent">';

print "ANNOTATOR - '$annotator'<br>\n";

	my $sql = "SELECT Class_Native_ID, Class_Name FROM Class
					WHERE Class_Native_ID IN ($nativeid_list)
					AND idClass_System = (SELECT idClass_System FROM Class_System WHERE Class_Sys_Name = '$system_name')";
	$statement = $db_handle->prepare($sql);
	$statement->execute;
	my $row_count = $statement->rows;
	while (@row = $statement->fetchrow_array) {
		$native_id = $row[0];
		$CategoryInfo{$native_id} = $row[1];
	}

print h2("The following terms will be mapped to '$tox_name':<br>");
print '<UL>';
foreach $item (@CategoryIDs) {
	my ($sys_name, $native_id) = split(/\|\|/, $item);
	print "<LI>$CategoryInfo{$native_id}</LI>\n";
	$Tox_2_Cat{$sys_name}{$native_id}{KEEP_FLAG} = 'T';
	$Tox_2_Cat{$sys_name}{$native_id}{ANNOTATOR} = $annotator;
	$Tox_2_Cat{$sys_name}{$native_id}{DATE} = $date;
	$Tox_2_Cat{$sys_name}{$native_id}{COMMENT} = $comment;
}
print '</UL>';


print h2("The following terms will be removed from mapping to '$tox_name':<br>");
print '<UL>';
foreach $item (@SubtractCategoryIDs) {
	my ($sys_name, $native_id) = split(/\|\|/, $item);
	print "<LI>$CategoryInfo{$native_id}</LI>\n";
	$Tox_2_Cat{$sys_name}{$native_id}{KEEP_FLAG} = 'F';
}
print '</UL>';

open(OUTFILE, ">$tox_map_file");
foreach $sys_name (keys %Tox_2_Cat) {
	foreach $native_id (keys %{$Tox_2_Cat{$sys_name}}) {
		if ($Tox_2_Cat{$sys_name}{$native_id}{KEEP_FLAG} eq 'T') {
			my $item_annotator = $Tox_2_Cat{$sys_name}{$native_id}{ANNOTATOR};
			my $item_date = $Tox_2_Cat{$sys_name}{$native_id}{DATE};
			my $item_comment = $Tox_2_Cat{$sys_name}{$native_id}{COMMENT};
			print OUTFILE "$sys_name\t$native_id\t$item_annotator\t$item_date\t$item_comment\n";
		}
	}
}
close(OUTFILE);
chmod 0777, "$tox_map_file";

my $link = "MapTox.cgi?ANNOTATOR=$annotator\&TOX_SYS_ID=$tox_sys_id&TOXTERM=$tox_term&ClassID=$class_sys_id&PARENTLIST=$parent_list";
print "<A HREF='$link'>Continue</A>";

print "<BR><BR><HR WIDTH=\"50%\"><BR>For questions or problem contact: <A HREF=\"mailto:$MiscVariables{ADMINISTRATOR_EMAIL}\">$MiscVariables{ADMINISTRATOR_NAME}</A>";
print "<BR><I><FONT SIZE=\"2\">Developed by Mark Gosink, Investigative Toxicology, DSRD @ Pfizer Inc.</I><BR></FONT>";
print '</DIV>';

print end_html();
exit;

sub make_sql_safe {
	my $term = $_[0];
	$term =~ s/[\n\r\f\e]+/ /g;
	$term =~ s/(\\|\'|\"|\%)/\\$1/g;
	return $term;
}

