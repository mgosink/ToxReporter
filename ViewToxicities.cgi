#!/usr/bin/perl -I..

################################################################
#
#  Author(s) - Mark M. Gosink, Ph.D.
#  Company     Pfizer Inc.
#
#  Creation Date - April 1, 2009
#
#  Function - display_classes
#				added index
#
################################################################

use lib ("/home/gosinm/CGI/perl_lib", "/cssi/data/neusentis_data1/cgi/comptoxdev.pfizer.com/perl_lib", ".", "..");

use CGI qw(:standard);

use conf::ToxGene_Defaults;

use DBI;

$image_path = $MiscVariables{IMAGE_PATH};
$dsrd_link = $MiscLinks{DSRD_HOME};

print header();
print start_html(-title=>"ToxReporter: Issue Selector",
						-head=>[meta({-http_equiv=>'X-UA-Compatible', -content=>'IE=edge'}),	#	because IE is bad, need to tell it to display in highest mode
									Link({-rel=>'shortcut icon',-type=>'image/x-icon',-href=>"$image_path/favicon.ico"})],
						-style=>[{'src'=>"$image_path/jquery/css/start/jquery-ui-1.10.4.custom.min.css"},
										{'src'=>"$image_path/dist/themes/default/style.min.css"},
										{'src'=>"$image_path/Style.css"}],
						-script=>[{-type=>'text/javascript', -src=>"$image_path/jquery/js/jquery-1.10.2.js"},						
										{-type=>'text/javascript', -src=>"$image_path/jquery/js/jquery-ui-1.10.4.custom.min.js"},						
										{-type=>'text/javascript', -src=>"$image_path/dist/jstree.min.js"},						
										{-type=>'text/javascript', -src=>"$image_path/load_jquery.js"},				
										{-type=>'text/javascript', -src=>"$image_path/hider.js"}]
						);

print "<div id='loading'>\n";
print "   <div id='content'></div>\n";
print "</div>\n";

print<<MENU;
<table class="header">
  <tr>
    <td class="header_1">
      <a href="$dsrd_link"><img border="0" height=74px width=170px src="$image_path/DSRD.jpg" ALT="Drug Safety Research & Development"></a>
    </td>
    <td class="header_2">
      <div class="header">
        <i><font color="blue">T</font>oxicity<font color="blue"> I</font>ssue <font color="orangered">S</font>elector</i><BR>
           $tox_system_name 
      </div>
    </td>
  </tr>
</table>

<table class="menu_table">
  <tr>
    <td class="menu_current">
      <A class="menu_current" href="ViewToxicities.cgi"><span class='help_info' tooltip-data='$ToolTips{ToxIssues_But}'>Search Tox Issues:</span></A>
    </td>
  </tr>
  <tr>
    <td class="menu">
      <A class="menu" href="ToxMatrixReport.cgi"><span  class='help_info' tooltip-data='$ToolTips{ToxMatrix_But}'>ToxMatrix Genes:</span></A>
    </td>
  </tr>
</table>
MENU



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

my $tox_sys_id = param(TOX_SYS_ID);
my $tox_sys_name = param(TOX_SYS_NAME);
my $page_sys_id = param(PAGEID);
my $parent_list = param(PARENTLIST);
if ($tox_sys_id eq "") {
	$tox_sys_id = $MiscVariables{BASE_TOX_SYS_ID};
	$parent_list = $MiscVariables{BASE_TOX_ID};
	$tox_sys_name = 'Pfizer Toxicity Lexicon';
}

$parents = $parent_list;
my $search_term = param(SEARCHTERM);
my @ItemTypes = param(ITEMS);
my $item_desc = join(" & ", @ItemTypes);

my $sql = "SELECT Tox_Sys_Name, Tox_Sys_Desc FROM Tox_System WHERE idTox_System = '$tox_sys_id'";
$statement = $db_handle->prepare($sql);
$statement->execute;
@row = $statement->fetchrow_array;
my $tox_system_name = $row[0];

print '<DIV class="body_indent">';
print start_form(-action=>"SearchTargets.cgi", -method=>'POST');

print "<FONT SIZE=-1>Terms which are 'grayed out' do not have specific annotations. Use the parent term.</FONT>\n";
print "<div id='jstree_demo_div'>\n";
print "<ul>\n";
display_toxicity_tree($tox_sys_id, $parent, 0);
print "</ul>\n";
print "</div>\n";

print "<span  class='help_info' tooltip-data='Use the Search box to find specific terms. Tree will expand to display available matches.'>";
print '<input type="text" value="" style="box-shadow:inset 0 0 4px #eee; width:100px; margin:0; padding:6px 12px; border-radius:4px; border:1px solid silver; font-size:1.1em;" id="demo_q" placeholder="Search" />';
print "</span><br>\n";

print "<input type='hidden' name='TOXTERM'></input>\n";
print "<input type='hidden' name='TOX_SYS_ID' value='$tox_sys_id'></input>\n";
print "<input type='hidden' name='TOX_SYS_NAME' value='$tox_sys_name'></input>\n";
print "<span  class='help_info' tooltip-data='$ToolTips{SearchGene_But}'><input type='submit' value='Search for a Gene'></span>\n";

print end_form();

print "<BR><BR><HR WIDTH=\"50%\"><BR>For questions or problem contact: <A HREF=\"mailto:$MiscVariables{ADMINISTRATOR_EMAIL}\">$MiscVariables{ADMINISTRATOR_NAME}</A>";
print "<BR><I><FONT SIZE=\"2\">Developed by Mark Gosink, Investigative Toxicology, DSRD @ Pfizer Inc.</I><BR></FONT>";
print '</DIV>';

print end_html();

exit;

sub display_toxicity_tree {
	my $tox_system = $_[0];
	my $parent_id = $_[1];
	my $list_depth = $_[2];
	$list_depth++;
	my $sql = "";
	if ($list_depth == 1) {
		$sql = "SELECT idToxTerm, Tox_Term, Tox_Native_ID, Tox_Desc FROM ToxTerm"
				. " WHERE idTox_System = '$tox_sys_id'"
				. " AND idToxTerm NOT IN (SELECT Child_idToxTerm FROM ToxParent)";
	}
	else {
		$sql = "SELECT idToxTerm, Tox_Term, Tox_Native_ID, Tox_Desc FROM ToxTerm WHERE idToxTerm = '$parent_id'";
	}
	my $statement = $db_handle->prepare($sql);
	$statement->execute;
	my @row = $statement->fetchrow_array;
	my $tox_id = $row[0];
	my $term = $row[1];
	my $native_tox_id = $row[2];
	my $tox_desc = $row[3];
	print "  " x $list_depth;
 
 	my $data_warning = "data-jstree='{\"disabled\":true}'";
	if (($IssueCatagories{$term} ne '')
			|| ($term eq 'Toxicity_Mechanism')) { $data_warning = '' }
	elsif (($term eq 'Pfizer_Toxicities')
			|| ($term eq 'Organ_System')) { $data_warning = "data-jstree='{\"opened\":true}'" }

	print "<li $data_warning><a href='#'>$term</a>\n";

	$sql = "SELECT COUNT(Child_idToxTerm) FROM ToxParent WHERE Parent_idToxTerm = '$tox_id'";
	$statement = $db_handle->prepare($sql);
	$statement->execute;
	@row = $statement->fetchrow_array;
	my $child_count = $row[0];
	if ($child_count >= 1) {
		$sql = "SELECT TP.Child_idToxTerm, TT.Tox_Term FROM ToxParent TP, ToxTerm TT"
				. " WHERE TP.Parent_idToxTerm = '$tox_id'"
				. " AND TT.idToxTerm = TP.Child_idToxTerm ORDER BY TT.Tox_Term ASC";
		$statement = $db_handle->prepare($sql);
		$statement->execute;
		print "  " x $list_depth, "<ul>\n";
		while(my @row = $statement->fetchrow_array) {
			my $new_id = $row[0];
			display_toxicity_tree($tox_system, $new_id, $list_depth);
		}
		print "  " x $list_depth, "</ul>\n";
	}
	print "  " x $list_depth;
	print "</li>\n";
}
