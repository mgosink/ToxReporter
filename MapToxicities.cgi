#!/usr/bin/perl

################################################################
#
#  Author(s) - Mark M. Gosink, Ph.D.
#  Company     Pfizer Inc.
#
#  Creation Date - April 1, 2009
#
#  Function - This app displays the Pfizer tox categories and allows entry 
#					of an annotator.
#				added index
#
################################################################

$| = 1;

use lib ("/home/gosinm/CGI/perl_lib", "/cssi/data/neusentis_data1/cgi/comptoxdev.pfizer.com/perl_lib", ".", "..");

use CGI qw(:standard);

use conf::ToxGene_Defaults;

use DBI;

$ROWS_PER_PAGE = 100;
my $max_search_returns = 50;

$fname = $0;
$fname =~ s/.+\/([^\/]+)$/$1/;


$query = new CGI;
$annotator = $query->cookie('TOX_MAP_ANNOTATOR');

print header();


$image_path = $MiscVariables{IMAGE_PATH};
$dsrd_link = $MiscLinks{DSRD_HOME};

print start_html(-title=>"Map Toxicity Issues to Gene Categories", -style=>{'src'=>"$image_path/Style.css"},);

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

my $tox_sys_id = param(TOX_SYS_ID);
my $tox_sys_name = param(TOX_SYS_NAME);
my $page_sys_id = param(PAGEID);
my $parent_list = param(PARENTLIST);
if ($tox_sys_id eq "") {
	$tox_sys_id = 1;
	$parent_list = 96;
	$tox_sys_name = 'Pfizer Toxicity Lexicon';
}
print '<DIV class="evid_view">';
#	my $parent_list = param(PARENTLIST);
$parents = $parent_list;
my $search_term = param(SEARCHTERM);
my @ItemTypes = param(ITEMS);
my $item_desc = join(" & ", @ItemTypes);

my $sql = "SELECT Tox_Sys_Name, Tox_Sys_Desc FROM Tox_System WHERE idTox_System = '$tox_sys_id'";
$statement = $db_handle->prepare($sql);
$statement->execute;
@row = $statement->fetchrow_array;
my $tox_system_name = $row[0];
print	'<table class="header">
			<tr>
				<td class="header_1">
					<a href="' . $dsrd_link .'"><img border="0" height=65px width=150px src="' . $image_path . '/DSRD.jpg" ALT="Drug Safety Research & Development"></a>
  				</td>
				<td class="header_2">
				<div class="header">
					<i><font color="blue">M</font>ap<font color="blue"> T</font>oxicities to <font color="orangered">C</font>ategories</i><BR>';
print "'$tox_system_name'";
print '					</div>
  				</td>
			</tr>
		</table>';
print "\n";

print '<table class="menu" align="left"><tr><td class="menu_col"><table class="menu_table">
			<tr>
				<tr>
		  		 <td class="menu_current">
					 <A class="menu_current" href="MapToxicities.cgi">
					 Map Tox Issues:
					 </A>
				 </td>
				</tr>
		</table></td><td valign="top">';
print '</td></tr></table>';
print '<DIV class="body_indent">';

if ($search_term ne "") {
	print h2("SEARCH FOR '<FONT COLOR='blue'>$search_term</FONT>' RETURNED THE FOLLOWING RESULTS:<BR>\n");
	$search_term = '%' . make_sql_safe($search_term) . '%';
	my $sql = "SELECT idToxTerm, Tox_Term, Tox_Native_ID FROM ToxTerm
					WHERE idTox_System = '$tox_sys_id' AND
					(UPPER(Tox_Term) like UPPER('$search_term')
					OR UPPER(Tox_Native_ID) like UPPER('$search_term'))";
	$statement = $db_handle->prepare($sql);
	$statement->execute;
	my $row_count = $statement->rows;
	while (@row = $statement->fetchrow_array) {
		$tox_id = $row[0];
		$ToxInfo{$tox_id}{Tox_Term} = $row[1];
		$ToxInfo{$tox_id}{Tox_Native_ID} = $row[2];
	}
	%TmpInfo = %ToxInfo;
	@ClassList = sort by_name_id(keys %TmpInfo);

	if ($row_count > $max_search_returns) {
		print h3("Your search returned hits more than the maximum number allowed ($max_search_returns)!<br> Your results will be truncated.");
	}

	foreach my $tox_id (@ClassList) {
		print "<UL>\n";
		my $name = $ToxInfo{$tox_id}{Tox_Term};
		if ($ToxInfo{$tox_id}{ITEM_NUM} > 0) { $name .= ' (' . $ToxInfo{$tox_id}{ITEM_NUM} . " $item_desc)" }
		my $term = '<b>' . $ToxInfo{$tox_id}{Tox_Term} . '</b>';
		print "<LI><b>$name</b></LI>\n";
		print_path_links($tox_id, $term);
		print "</UL>\n";
		$max_search_returns--;
		if ($max_search_returns <= 0) { last }
	}
}
else {
	print start_form();
	print "<table>\n";
	print "<tr><td>Search for term:</td><td><input type='text' name='SEARCHTERM' size=40></input></td></tr>\n";
	print "</table>\n";
	print "<input type='hidden' name='ANNOTATOR' value='$annotator'></input>\n";
	print "<input type='hidden' name='TOX_SYS_ID' value='$tox_sys_id'></input>\n";
	print "<input type='hidden' name='TOX_SYS_NAME' value='$tox_sys_name'></input>\n";
	print submit('Search'), "&nbsp;&nbsp;&nbsp;&nbsp;", reset('Reset');
	print end_form();

	print start_form(-action=>"MapTox.cgi");
	display_classes($tox_sys_id, $parent_list, -1);

	print "<table>\n";
	print "<tr><td>Enter your name:</td><td><input type='text' name='ANNOTATOR' size=40 value='$annotator'></input></td></tr>\n";
	print "</table>\n";
	print "<input type='hidden' name='TOX_SYS_ID' value='$tox_sys_id'></input>\n";
	print "<input type='hidden' name='TOX_SYS_NAME' value='$tox_sys_name'></input>\n";
	print submit('Create Mappings'), "&nbsp;&nbsp;&nbsp;&nbsp;", reset('Reset');
	print end_form();
}
	

print "<BR><BR><HR WIDTH=\"50%\"><BR>For questions or problem contact: <A HREF=\"mailto:$MiscVariables{ADMINISTRATOR_EMAIL}\">$MiscVariables{ADMINISTRATOR_NAME}</A>";
print "<BR><I><FONT SIZE=\"2\">Developed by Mark Gosink, Investigative Toxicology, DSRD @ Pfizer Inc.</I><BR></FONT>";
print '</DIV>';

print end_html();
exit;

sub by_geneset_name {
	return uc($Species_to_GeneSets{$species}{$a}) cmp uc($Species_to_GeneSets{$species}{$b})
}

sub display_classes {
	print "<UL>\n";
	my $tox_system = $_[0];
	my $par_list = $_[1];
	@ExpandList = split(/\|/, $par_list);
	my $list_depth = $_[2];
	my $sql = "";
	my @ClassIDs = ();
	my @ClassList = ();
	my @TmpList = ();
	my @ClassListIndex = ();
	my %ToxInfo = ();
	my $NUM_ROWS = $ROWS_PER_PAGE;
	my $bold_flag = 'F';
	
	if ($list_depth == $#ExpandList) { $bold_flag = 'T' }
	if ($list_depth == -1) {
		$sql = "SELECT idToxTerm FROM ToxTerm"
				. " WHERE idTox_System = '$tox_sys_id'"
				. " AND idToxTerm NOT IN (SELECT Child_idToxTerm FROM ToxParent)";
	}
	else {
		$parent_id = $ExpandList[$list_depth];
		$sql = "SELECT Child_idToxTerm FROM ToxParent WHERE Parent_idToxTerm = '$parent_id'";
	}
	$statement = $db_handle->prepare($sql);
	$statement->execute;
	while(my @row = $statement->fetchrow_array) {
		push(@ClassIDs, $row[0]);
	}

	my $num_children = $#ClassIDs;
	
	foreach my $tox_id (@ClassIDs) {
		$sql = "SELECT Tox_Term, Tox_Native_ID FROM ToxTerm WHERE idToxTerm = '$tox_id'";
		$statement = $db_handle->prepare($sql);
		$statement->execute;
		my @row = $statement->fetchrow_array;

		$ToxInfo{$tox_id}{Tox_Term} = "\u$row[0]";
		$ToxInfo{$tox_id}{Tox_Native_ID} = $row[1];
		$ToxInfo{$tox_id}{ITEM_NUM} = $#{$ItemClass{$tox_id}} + 1;
		
		$sql = "SELECT COUNT(Child_idToxTerm) FROM ToxParent WHERE Parent_idToxTerm = '$tox_id'";
		$statement = $db_handle->prepare($sql);
		$statement->execute;
		@row = $statement->fetchrow_array;
		$ToxInfo{$tox_id}{CHILD_COUNT} = $row[0];
	}
	%TmpInfo = %ToxInfo;
	@TmpList = @ClassList = sort by_name_id(keys %TmpInfo);

	my $page = 0;
	my $row_cnt;
	foreach my $data_row (@TmpList) {
		my $name = $ToxInfo{$data_row}{Tox_Term};
		$name =~ s/^[\|\s]+//;
		if ($TmpList{$data_row}{ITEM_NUM} > 0) { $name .= ' (' . $TmpList{$data_row}{ITEM_NUM} . " $item_desc)" }
		$ClassListCnt[$page][$row_cnt++] = $name;
		$end = substr($name, 0, 6);
	
		if ($row_cnt == 1) { $beg = substr($name, 0, 6) }
		elsif ($row_cnt == $NUM_ROWS) {
			push(@ClassListIndex, "$beg - $end");
			$beg = $end = "";
		}

		if (($NUM_ROWS) && ($row_cnt >= $NUM_ROWS)) { $row_cnt = 0; $page++; }
	}
	
	if ($row_cnt < $NUM_ROWS) { push(@ClassListIndex, "$beg - $end") }

	if ($NUM_ROWS) { $DISPLAY_NUM = $NUM_ROWS }
	else { $DISPLAY_NUM = $row_cnt }

	if (($#ClassListIndex > 0) && ($NUM_ROWS) && ($list_depth < 0)) {
		print "<p align=\"center\"><table border=\"1\" cellpadding=\"5\"><tr>";
		my $page_num = 0;
		foreach my $class_index (@ClassListIndex) {
			print "<td><a href='$fname?TOX_SYS_ID=$tox_sys_id\&PAGEID=$page_num'>$class_index</a></td>";
			$page_num++;
		}
		print "</tr></table></p><br>\n";
	}
	
	my $display_row = 0;
	my $START_INDEX = $DISPLAY_NUM*($page_sys_id)+1;
	foreach my $tox_id (@ClassList) {
		$display_row++;
		if ($display_row == ($START_INDEX + $DISPLAY_NUM)) { last; }
		if ($display_row < $START_INDEX) { next }
		
		my $name = $ToxInfo{$tox_id}{Tox_Term};
			
		my $ch = substr($name, 0 , 1);
		my $lastch = $ch;
		
		if ($ToxInfo{$tox_id}{CHILD_COUNT} > 0) {
			$image = "+ ";
			if ($tox_id =~ /$parents/) { $image = "- " }
		}
		else { $image = "" }
		
		$list = "";
		for ($cnt = 0; $cnt <= $list_depth; $cnt++) {
			$list .= $ExpandList[$cnt] . '|';
		}
		$list .= $tox_id;
		
		my $native_id = $ToxInfo{$tox_id}{Tox_Native_ID};
		if (($tox_id == $ExpandList[$#ExpandList]) && ($image eq "")) {
			print "<LI><strong>$name</strong><input type='radio' name='TOXTERM' value='$name\|$tox_id\|$native_id'></input></LI>\n";
		}
		elsif ($tox_id == $ExpandList[$#ExpandList]) {
			print "<LI>-<a name='$list_depth$display_row' href='$fname?TOX_SYS_ID=$tox_sys_id\&TOX_SYS_NAME=$tox_sys_name\&PAGEID=$page_sys_id\&PARENTLIST=$list#$list_depth$display_row'><strong>$name</strong></a><input type='radio' name='TOXTERM' value='$name\|$tox_id\|$native_id'></input></LI>\n";
		}
		elsif ($image eq "") {
			print "<LI>$name<input type='radio' name='TOXTERM' value='$name\|$tox_id\|$native_id'></input></LI>\n";
		}
		else {
			print "<LI>$image<a name='$list_depth$display_row' href='$fname?TOX_SYS_ID=$tox_sys_id\&TOX_SYS_NAME=$tox_sys_name\&PAGEID=$page_sys_id\&PARENTLIST=$list#$list_depth$display_row'>$name</a><input type='radio' name='TOXTERM' value='$name\|$tox_id\|$native_id'></input></LI>\n";
		}

		my $expand_flag = 'F';
		foreach $id (@ExpandList) {
			if ($tox_id eq $id) {
				$expand_flag = 'T'; last;
			}
		}

		if (($ToxInfo{$tox_id}{CHILD_COUNT} > 0) && ($expand_flag eq 'T')) {
			$new_list = join('|', @ExpandList);
			$new_depth = $list_depth + 1;
			display_classes($tox_system, $new_list, $new_depth);
		}
	}
	print "</UL>\n";
}

sub make_sql_safe {
	my $term = $_[0];
	$term =~ s/[\n\r\f\e]+/ /g;
	$term =~ s/(\\|\'|\"|\%)/\\$1/g;
	return $term;
}

sub by_name_id {
	$a_nm = uc($TmpInfo{$a}{Tox_Term});
	$b_nm = uc($TmpInfo{$b}{Tox_Term});
	if ($a_nm gt $b_nm) { return 1 }
	elsif ($a_nm lt $b_nm) { return -1 }
}

sub print_path_links {
	my $child_classes = $_[0];
	my $previous_term = $_[1];
	my @Classes = split(/\|/, $child_classes);
	my @ParentClasses = ();
	my $child_class_id = shift(@Classes);
	my $sql = "SELECT Parent_idToxTerm, Relationship, Tox_Term"
				. " FROM ToxParent, ToxTerm"
				. " WHERE ToxParent.Child_idToxTerm = '$child_class_id'"
				. " AND ToxTerm.idToxTerm = ToxParent.Parent_idToxTerm";
	$statement = $db_handle->prepare($sql);
	$statement->execute;
	my $found_parents = 'F';
	while (@row = $statement->fetchrow_array) {
		push(@ParentClasses, $row[0]);
		$found_parents = 'T';
		$PathTerms{$row[0]} = $previous_term . " <FONT COLOR='black'><i>$row[1]</i></FONT>  <b>$row[2]</b>";
	}
	if ($found_parents eq 'T') {
		foreach $id (@ParentClasses) {
			$new_child_classes = $id . '|' . $child_classes;
			$new_term = $PathTerms{$id};
			print_path_links($new_child_classes, $new_term);
		}
	}
	else {
		print "<UL><LI><a href='$fname?TOX_SYS_ID=$tox_sys_id\&TOX_SYS_NAME=$tox_sys_name\&PAGEID=$page_sys_id\&PARENTLIST=$child_classes'>$previous_term</a></LI></UL>\n";
	}
}




