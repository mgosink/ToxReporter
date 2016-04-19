#!/usr/bin/perl

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

$ROWS_PER_PAGE = 1000;

$fname = $0;
$fname =~ s/.+\/([^\/]+)$/$1/;


my $max_search_returns = 500;
my $annotator = param(ANNOTATOR);
$query_set = new CGI;
$cookie = $query_set->cookie(-name=>"TOX_MAP_ANNOTATOR", -value=>"$annotator", -expires=>"+1M");

$query = new CGI;
$comment = $query->cookie('COMMENT');

print header(-cookie=>$cookie);

$image_path = $MiscVariables{IMAGE_PATH};
$dsrd_link = $MiscLinks{DSRD_HOME};

print start_html(-title=>"Map Toxicities", -style=>{'src'=>"$image_path/Style.css"},);

# vvvvvvvvvvvv Log the use of this application vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
#	Log the use of this application
eval {
	my $add = $ENV{HTTP_X_FORWARDED_FOR}?$ENV{HTTP_X_FORWARDED_FOR}:$ENV{REMOTE_ADDR};
#	`/cssi/data/neusentis_data1/cgi/comptoxdev.pfizer.com/TOOLS/Log_Use $add $0`;
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
	my ($class_system_name, $native_id) = split(/\t/, $line);
	$Tox_2_Cat{$class_system_name}{$native_id} = 'T';
}
close(FILE);


my $class_sys_id = param(ClassID);
my $page_sys_id = param(PAGEID);
print '<DIV class="evid_view">';

#	if data type to classify not selected, do it now
if ($class_sys_id eq "") {
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
		  		 <td class="menu_current">
					 <A class="menu_current" href="MapToxicities.cgi">
					 Map Tox Issues:
					 </A>
				 </td>
				</tr>
			</table></td><td valign="top">';
	print '</td></tr></table>';

	print '<DIV class="body_indent">';

	print "ANNOTATOR - '$annotator'<br>\n";

	print h2("Select the category you wish to map to '$tox_name':<br>");
	my $sql = "SELECT idClass_System, Class_Sys_Name, Class_Sys_Desc FROM Class_System ORDER BY Class_Sys_Name";
	$statement = $db_handle->prepare($sql);
	$statement->execute;
	print "<ul>\n";
	$species = "";
	while(@row = $statement->fetchrow_array) {
		$class_sys_id = $row[0];
		$class_sys_name = $row[1];
#		if ($class_sys_name =~ /pathway/i) { next }	#	Pathways are base solely on predictions
		$class_sys_desc = $row[2];
		$link = "\?ANNOTATOR=$annotator\&TOX_SYS_ID=$tox_sys_id\&TOXTERM=$tox_term\&ClassID=$class_sys_id";
		print "<li><a href='$link'>$class_sys_name</a></li>\n";
	}
	print "</ul>\n";
}

#	once a data type is selected display the list and create links
else {
	my $parent_list = param(PARENTLIST);
	$parents = $parent_list;
	my $search_term = param(SEARCHTERM);
	my @ItemTypes = param(ITEMS);
	my $item_desc = join(" & ", @ItemTypes);
	
	my $sql = "SELECT Class_Sys_Name, Class_Sys_Desc FROM Class_System WHERE idClass_System = '$class_sys_id'";
	$statement = $db_handle->prepare($sql);
	$statement->execute;
	@row = $statement->fetchrow_array;
	$class_system_name = $row[0];
	(undef, undef, $geneset_id) = split(/:/, $row[1]);
	print	'<table class="header">
				<tr>
					<td class="header_1">
					<a href="' . $dsrd_link .'"><img border="0" height=65px width=150px src="' . $image_path . '/DSRD.jpg" ALT="Drug Safety Research & Development"></a>
  					</td>
					<td class="header_2">
					<div class="header">
						<i><font color="blue">M</font>ap<font color="blue"> T</font>oxicities to <font color="orangered">C</font>ategories</i><br>';
	print "'$class_system_name'";
	print '					</div>
  					</td>
				</tr>
			</table>';
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
	print "\n";

	print '<DIV class="body_indent">';

	print "ANNOTATOR - '$annotator'<br>\n";
	if ($search_term ne "") {
		print h2("SEARCH FOR '<FONT COLOR='blue'>$search_term</FONT>' RETURNED THE FOLLOWING RESULTS:<BR>\n");
		$search_term = '%' . make_sql_safe($search_term) . '%';
		my $sql = "SELECT idClass, Class_Name, Class_Native_ID FROM Class
						WHERE idClass_System = '$class_sys_id' AND
						(UPPER(Class_Name) like UPPER('$search_term')
						OR UPPER(Class_Native_ID) like UPPER('$search_term'))";
		$statement = $db_handle->prepare($sql);
		$statement->execute;
		my $row_count = $statement->rows;
		while (@row = $statement->fetchrow_array) {
			$class_id = $row[0];
			$ClassInfo{$class_id}{Class_Name} = $row[1];
			$ClassInfo{$class_id}{Class_Native_ID} = $row[2];
		}
		%TmpInfo = %ClassInfo;
		@ClassList = sort by_name_id(keys %TmpInfo);

		if ($row_count > $max_search_returns) {
			print h3("Your search returned hits more than the maximum number allowed ($max_search_returns)!<br> Your results will be truncated.");
		}
		
		foreach my $class_id (@ClassList) {
			print "<UL>\n";
			my $name = $ClassInfo{$class_id}{Class_Name};
			if ($ClassInfo{$class_id}{ITEM_NUM} > 0) { $name .= ' (' . $ClassInfo{$class_id}{ITEM_NUM} . " $item_desc)" }
			my $term = '<b>' . $ClassInfo{$class_id}{Class_Name} . '</b>';
			print "<LI><b>$name</b></LI>\n";
			print_path_links($class_id, $term);
			print "</UL>\n";
			$max_search_returns--;
			if ($max_search_returns <= 0) { last }
		}
	}
	else {
		print h2("Check the specific category you wish to map to '$tox_name':<br>");

		print start_form();	#	form to search for a category
		print "<table>\n";
		print "<tr><td>Search for a term:</td><td><input type='text' name='SEARCHTERM' size=40></input></td><td>\n";
		print submit('Search');
		print "</td></tr></table>\n";
		print "<input type='hidden' name='ANNOTATOR' value='$annotator'></input>\n";
		print "<input type='hidden' name='ClassID' value='$class_sys_id'></input>\n";
		print "<input type='hidden' name='TOX_SYS_ID' value='$tox_sys_id'></input>\n";
		print "<input type='hidden' name='TOXTERM' value='$tox_term'>";
		print end_form();
		print "<HR WIDTH='25%'>\n";

		print start_form(-action=>"MapItems.cgi");	#	form to modify category to tox links
		display_classes($class_sys_id, $parent_list, -1);
		print "<table>\n";
		print "<tr><td>Comment(s) <I>optional</I>:</td><td><TEXTAREA NAME='COMMENT' COLS=60 ROWS=2>$comment</TEXTAREA></td></tr>\n";
		print "</table>\n";
		print "<input type='hidden' name='ClassID' value='$class_sys_id'></input>\n";
		print "<input type='hidden' name='ANNOTATOR' value='$annotator'></input>\n";
		print "<input type='hidden' name='PARENTLIST' value='$parent_list'></input>\n";
		print "<input type='hidden' name='TOX_SYS_ID' value='$tox_sys_id'></input>\n";
		print "<input type='hidden' name='TOXTERM' value='$tox_term'></input>\n";
		print submit('Map Items'), "&nbsp;&nbsp;&nbsp;&nbsp;", reset('Reset');
		print end_form();

	}
}


print "<BR><BR><HR WIDTH=\"50%\"><BR>For questions or problem contact: <A HREF=\"mailto:$MiscVariables{ADMINISTRATOR_EMAIL}\">$MiscVariables{ADMINISTRATOR_NAME}</A>";
print "<BR><I><FONT SIZE=\"2\">Developed by Mark Gosink, Investigative Toxicology, DSRD @ Pfizer Inc.</I><BR></FONT>";
print '</DIV>';

print end_html();

exit;



sub display_classes {
	print "<UL>\n";
	my $class_system = $_[0];
	my $par_list = $_[1];
	@ExpandList = split(/\|/, $par_list);
	my $list_depth = $_[2];
	my $sql = "";
	my @ClassIDs = ();
	my @ClassList = ();
	my @TmpList = ();
	my @ClassListIndex = ();
	my %ClassInfo = ();
	my $NUM_ROWS = $ROWS_PER_PAGE;
	my $bold_flag = 'F';
	
	if ($list_depth == $#ExpandList) { $bold_flag = 'T' }

	if ($list_depth == -1) {	#	this is to display the base class(es)
		$sql = "SELECT idClass FROM Class"
				. " WHERE idClass_System = '$class_sys_id'"
				. " AND idClass NOT IN (SELECT Child_idClass FROM Class_Parent)";
	}
	else {
		$parent_id = $ExpandList[$list_depth];
		$sql = "SELECT Child_idClass FROM Class_Parent WHERE Parent_idClass = '$parent_id'";
	}
	$statement = $db_handle->prepare($sql);
	$statement->execute;
	while(my @row = $statement->fetchrow_array) {
		push(@ClassIDs, $row[0]);
	}

	my $num_children = $#ClassIDs;
	
	foreach my $class_id (@ClassIDs) {
		$sql = "SELECT Class_Name, Class_Native_ID FROM Class WHERE idClass = '$class_id'";
		$statement = $db_handle->prepare($sql);
		$statement->execute;
		my @row = $statement->fetchrow_array;

		$ClassInfo{$class_id}{Class_Name} = "\u$row[0]";
		$ClassInfo{$class_id}{Class_Native_ID} = $row[1];
		$ClassInfo{$class_id}{ITEM_NUM} = $#{$ItemClass{$class_id}} + 1;
		
		$sql = "SELECT COUNT(Child_idClass) FROM Class_Parent WHERE Parent_idClass = '$class_id'";
		$statement = $db_handle->prepare($sql);
		$statement->execute;
		@row = $statement->fetchrow_array;
		$ClassInfo{$class_id}{CHILD_COUNT} = $row[0];
	}
	%TmpInfo = %ClassInfo;
	@TmpList = @ClassList = sort by_name_id(keys %TmpInfo);

	my $page = 0;
	my $row_cnt;
	foreach my $data_row (@TmpList) {
		my $name = $ClassInfo{$data_row}{Class_Name};
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
			print "<td><a href='$fname?ANNOTATOR=$annotator\&TOX_SYS_ID=$tox_sys_id\&TOXTERM=$tox_term\&ClassID=$class_sys_id\&PAGEID=$page_num'>$class_index</a></td>";
			$page_num++;
		}
		print "</tr></table></p><br>\n";
	}
	
	my $display_row = 0;
	my $START_INDEX = $DISPLAY_NUM*($page_sys_id)+1;
	foreach my $class_id (@ClassList) {
		$display_row++;
		my $native_id = $ClassInfo{$class_id}{Class_Native_ID};
		my $classsys_nativeid = $class_system_name . '||' . $native_id;
		if ($display_row == ($START_INDEX + $DISPLAY_NUM)) { last; }
		if ($display_row < $START_INDEX) { next }
		
		my $name = $ClassInfo{$class_id}{Class_Name};
			
		my $ch = substr($name, 0 , 1);
		my $lastch = $ch;
		
		if ($ClassInfo{$class_id}{CHILD_COUNT} > 0) {
			$image = "+ ";
			if ($class_id =~ /$parents/) { $image = "- " }
		}
		else { $image = "" }
		
		$list = "";
		for ($cnt = 0; $cnt <= $list_depth; $cnt++) {
			$list .= $ExpandList[$cnt] . '|';
		}
		$list .= $class_id;
		
		if (($class_id == $ExpandList[$#ExpandList]) && ($image eq "")) {
			print "<LI><STRONG>";
			if ($Tox_2_Cat{$class_system_name}{$native_id} eq 'T') {
				print "<SPAN class='toxlinked'>$name</SPAN></STRONG><INPUT TYPE='checkbox' NAME='SUBTRACT_CATEGORY_ID' VALUE='$classsys_nativeid'>Sub</INPUT></LI>\n";
			}
			else {
				print "$name</STRONG><INPUT TYPE='checkbox' NAME='CATEGORY_ID' VALUE='$classsys_nativeid'>Add</INPUT></LI>\n";
			}
		}
		elsif ($class_id == $ExpandList[$#ExpandList]) {
			my $link = "$fname?ANNOTATOR=$annotator\&TOX_SYS_ID=$tox_sys_id\&TOXTERM=$tox_term\&ClassID=$class_sys_id\&PAGEID=$page_sys_id\&PARENTLIST=$list#$list_depth$display_row";
			print "<LI>-<A NAME='$list_depth$display_row' HREF='$link'><STRONG>";
			if ($Tox_2_Cat{$class_system_name}{$native_id} eq 'T') {
				print "<SPAN class='toxlinked'>$name</SPAN></STRONG></A><INPUT TYPE='checkbox' NAME='SUBTRACT_CATEGORY_ID' VALUE='$classsys_nativeid'>Sub</INPUT></LI>\n";
			}
			else {
				print "$name</STRONG></A><INPUT TYPE='checkbox' NAME='CATEGORY_ID' VALUE='$classsys_nativeid'>Add</INPUT></LI>\n";
			}
		}
		elsif ($image eq "") {
			print "<LI>";
			if ($Tox_2_Cat{$class_system_name}{$native_id} eq 'T') {
				print "<SPAN class='toxlinked'>$name</SPAN></A><INPUT TYPE='checkbox' NAME='SUBTRACT_CATEGORY_ID' VALUE='$classsys_nativeid'>Sub</INPUT></LI>\n";
			}
			else { print "$name</A><INPUT TYPE='checkbox' NAME='CATEGORY_ID' VALUE='$classsys_nativeid'>Add</INPUT></LI>\n" }
		}
		else {
			my $link = "$fname?ANNOTATOR=$annotator\&TOX_SYS_ID=$tox_sys_id\&TOXTERM=$tox_term\&ClassID=$class_sys_id\&PAGEID=$page_sys_id\&PARENTLIST=$list#$list_depth$display_row";
			print "<LI>$image<A NAME='$list_depth$display_row' HREF='$link'>";
			if ($Tox_2_Cat{$class_system_name}{$native_id} eq 'T') {
				print "<SPAN class='toxlinked'>$name</SPAN></A><INPUT TYPE='checkbox' NAME='SUBTRACT_CATEGORY_ID' VALUE='$classsys_nativeid'>Sub</INPUT></LI>\n";
			}
			else { print "$name</A><INPUT TYPE='checkbox' NAME='CATEGORY_ID' VALUE='$classsys_nativeid'>Add</INPUT></LI>\n" }
		}

		my $expand_flag = 'F';
		foreach $id (@ExpandList) {
			if ($class_id eq $id) {
				$expand_flag = 'T'; last;
			}
		}

		if (($ClassInfo{$class_id}{CHILD_COUNT} > 0) && ($expand_flag eq 'T')) {
			$new_list = join('|', @ExpandList);
			$new_depth = $list_depth + 1;
			display_classes($class_system, $new_list, $new_depth);
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
	$a_nm = uc($TmpInfo{$a}{Class_Name});
	$b_nm = uc($TmpInfo{$b}{Class_Name});
	if ($a_nm gt $b_nm) { return 1 }
	elsif ($a_nm lt $b_nm) { return -1 }
}

sub print_path_links {
	my $child_classes = $_[0];
	my $previous_term = $_[1];
	my @Classes = split(/\|/, $child_classes);
	my @ParentClasses = ();
	my $child_class_id = shift(@Classes);
	my $sql = "SELECT Parent_idClass, Relationship, Class_Name"
				. " FROM Class_Parent, Class"
				. " WHERE Class_Parent.Child_idClass = '$child_class_id'"
				. " AND Class.idClass = Class_Parent.Parent_idClass";
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
		print "<UL><LI><a href='$fname?ANNOTATOR=$annotator\&TOX_SYS_ID=$tox_sys_id\&TOXTERM=$tox_term\&ClassID=$class_sys_id\&PAGEID=$page_sys_id\&PARENTLIST=$child_classes'>$previous_term</a></LI></UL>\n";
	}
}




