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

use lib ("/home/gosinm/CGI/perl_lib", "/cssi/data/neusentis_data1/cgi/comptoxdev.pfizer.com/perl_lib", ".", "..");

use conf::ToxGene_Defaults;

use CGI qw/:standard/;

my $tr_cookie = cookie('ToxReporter_User');

use GD;
use DBI;

print header(-cookie=>$tr_cookie);

$image_path = $MiscVariables{IMAGE_PATH};
$dsrd_link = $MiscLinks{DSRD_HOME};

print start_html(-title=>"ToxReporter: Gene View",
						-head=>[meta({-http_equiv=>'X-UA-Compatible', -content=>'IE=edge'}),	#	because IE is bad, need to tell it to display in highest mode
									Link({-rel=>'shortcut icon',-type=>'image/x-icon',-href=>"$image_path/favicon.ico"})],
						-style=>[{'src'=>"$image_path/jquery/css/start/jquery-ui-1.10.4.custom.min.css"},
										{'src'=>"$image_path/dist/themes/default/style.min.css"},
										{'src'=>"$image_path/Style.css"}],
						-script=>[{-type=>'text/javascript', -src=>"$image_path/jquery/js/jquery-1.10.2.js"},						
										{-type=>'text/javascript', -src=>"$image_path/jquery/js/jquery-ui-1.10.4.custom.min.js"},						
										{-type=>'text/javascript', -src=>"$image_path/dist/jstree.min.js"},						
										{-type=>'text/javascript', -src=>"$image_path/load_jquery.js"},				
										{-type=>'text/javascript', -src=>"$image_path/hider.js"},
										{-type=>'text/javascript', -src=>"https://www.google.com/jsapi"}]
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
        <i><font color="blue">T</font>ox<font color="blue">G</font>ene <font color="orangered">R</font>eport</i>
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
      <A class="menu" href="ToxMatrixReport.cgi"><span class='help_info' tooltip-data='$ToolTips{ToxMatrix_But}'>ToxMatrix Genes:</span></A>
    </td>
  </tr>
</table>
MENU

print '<DIV class="body_indent">';

# vvvvvvvvvvvv Log the use of this application vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
#	Log the use of this application
eval {
	my $cookie_data = cookie(-name=>'ToxReporter_User');
	if ($cookie_data eq '') {
print<<EOB
EOB
	}
	my $add = $ENV{HTTP_X_FORWARDED_FOR}?$ENV{HTTP_X_FORWARDED_FOR}:$ENV{REMOTE_ADDR};
	`/cssi/data/neusentis_data1/cgi/comptoxdev.pfizer.com/TOOLS/Log_Use $add $0`;
#	print " $add $0<BR>\n";
};
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

$gene_id = param(GENE);
$entrez = param(ENTREZ);
if (($gene_id =~ /\d+/) && ($entrez eq "")) {
	open(FILE, "ToxGene_B_IDs.txt");
	while ($line = <FILE>) {
		chomp($line);
		my ($old_id, $new_entrez) = split(/\t/, $line);
		if ($old_id == $gene_id) {
			$entrez = $new_entrez;
			$gene_id = '';
			last;
		}
	}
	close(FILE);
}
$show_all = param(SHOWALL);	#	debugging parameter to alllow all links to be shown

$tox_sys_id = $MiscVariables{BASE_TOX_SYS_ID};
$tox_sys_name = param(TOX_SYS_NAME);
$tox_info = param(TOXTERM);
$tox_native = param(TOXNATIVE);
$sdg_tox = param(SDGTOX);
my ($tox_term, $tox_term_id, $tox_native_id) = split(/\|/, $tox_info);

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

if (($tox_term_id eq '') || ($tox_native_id eq '')) {
	my $sql = "SELECT idToxTerm, Tox_Native_ID from ToxTerm"
				. " WHERE Tox_Term = '$tox_term' AND idTox_System = '$tox_sys_id';";
	$statement = $db_handle->prepare($sql);
	$statement->execute;
	@row = $statement->fetchrow_array;
	$tox_term_id = $row[0];
	$tox_native_id = $row[1];
}

#	gather information about the selected tox term and its child tox terms
my $sql = "";
if ($tox_info ne '') {
	$sql = "SELECT TT.idToxTerm, TS.Tox_Sys_Name, TT.Tox_Term, TT.Tox_Desc, TT.Tox_Native_ID FROM"
				. " Tox_System TS, ToxTerm TT"
				. " WHERE TT.Tox_Native_ID = '$tox_native_id'"
				. " AND TT.idTox_System = TS.idTox_System";
}
else {
	$tox_term_id = $MiscVariables{BASE_TOX_ID};
	$sql = "SELECT TT.idToxTerm, TS.Tox_Sys_Name, TT.Tox_Term, TT.Tox_Desc, TT.Tox_Native_ID FROM"
				. " Tox_System TS, ToxTerm TT"
				. " WHERE TT.idToxTerm = '$tox_term_id'"
				. " AND TT.idTox_System = TS.idTox_System";
}
$statement = $db_handle->prepare($sql);
$statement->execute;
@row = $statement->fetchrow_array;
$tox_term_id = $row[0];
$tox_sys_name = $row[1];
$tox_term = $row[2];
$tox_desc = $row[3];
$tox_native_id = $row[4];

%AllTermIDs = ();
$AllTermIDs{$tox_term_id}{TERM} = $tox_term;
$AllTermIDs{$tox_term_id}{TERMDESC} = $tox_desc;
find_child_tox_terms($tox_term_id);

#	gather general gene info
my $sql = "";
if (($entrez =~ /^\d+$/) && ($gene_id eq '')) {
	$sql = "SELECT G.idGene, G.entrezID, S.idSpecies, S.commonName,  S.sciName, G.GeneBook_ID, G.idHomolog"
			. " FROM Gene G, Species S, Homolog H"
			. " WHERE G.entrezID = '$entrez'"
			. " AND S.idSpecies = G.idSpecies";
}
else {
	$sql = "SELECT G.idGene, G.entrezID, S.idSpecies, S.commonName,  S.sciName, G.GeneBook_ID, G.idHomolog"
			. " FROM Gene G, Species S, Homolog H"
			. " WHERE G.idGene = '$gene_id'"
			. " AND S.idSpecies = G.idSpecies";
}
#print "SQL -'$sql'<BR>\n";
$statement = $db_handle->prepare($sql);
$statement->execute;
@row = $statement->fetchrow_array;
$gene_id = $row[0];
$entrez = $row[1];
$species_id = $row[2];
$species_common = $row[3];
$species_sci = $row[4];
$genebook = $row[5];
$homologene_id = $row[6];
$homolo_id = '';

if ($homologene_id =~ /^\d+$/) {
	$sql = "SELECT HomoloGene_ID FROM Homolog WHERE idHomolog = '$homologene_id'";
	$statement = $db_handle->prepare($sql);
	$statement->execute;
	@row = $statement->fetchrow_array;
	$homolo_id = $row[0];
}

my $sql = "SELECT idNames, Name, Name_Type"
			. " FROM Names"
			. " WHERE idGene = '$gene_id'";
$statement = $db_handle->prepare($sql);
$statement->execute;
%Names = ();
$aliases = "";
while(@row = $statement->fetchrow_array) {
	$Names{$row[0]}{NAME} = $row[1];
	$Names{$row[0]}{TYPE} = $row[2];
	if ($row[2] eq "Name") {
		$fullname = $row[1];
	}
	elsif ($row[2] eq "Symbol") {
		$symbol = $row[1];
	}
	else {
		$aliases .= "$row[1]; ";
	}
}
$aliases =~ s/; $//;

my $showall_link = "ToxReport.cgi?TOX_SYS_ID=$tox_sys_id\&TOXTERM=$tox_term\&ENTREZ=$entrez";
my $icon = 'ui-icon-circle-minus';
my $expand_info = 'Hide unflagged gene information.';
if ($show_all ne 'T') {
	$showall_link .= '&SHOWALL=T';
	$icon = 'ui-icon-circle-plus';
	$expand_info = 'Show all gene information including unflagged.';
}
print "<TABLE BORDER=1 WIDTH='100%' BGCOLOR='blue'>\n",
		"<TR><TD><FONT COLOR='white'><H1>$symbol - $fullname</H1>\n",
		"Other names: $aliases<BR>\n",
		"$species_common (<I>$species_sci</I>)</FONT>",
		"<a href='$showall_link'><span class='ui-icon $icon help_info' style='float: right; margin-right: .3em;' tooltip-data='$expand_info'></span></a>",
		"</TD></TR>\n",
		"</TABLE>\n";

#	Display Tox-At-A-Glance
my $sdgamma_link = "ToxReport.cgi?TOX_SYS_ID=$tox_sys_id\&TOXTERM=$tox_term\&ENTREZ=$entrez";
$icon = 'ui-icon-refresh';
$expand_info = 'Switch back to standard scoring.';
if ($sdg_tox ne 'T') {
	$sdgamma_link .= '&SDGTOX=T';
	$expand_info = 'Experimental: Show scores based on SDgamma disproportionality scoring.';
}
print "<TABLE><TR COLSPAN=2><TH><span class='help_info' tooltip-data='$ToolTips{ToxAtGlance}'><FONT SIZE=+2>Tox-At-A-Glance",
#      "<a href='$sdgamma_link'><span class='ui-icon $icon help_info' style='float: right; margin-right: .3em;' tooltip-data='$expand_info'></span></a>",
		"</FONT></span></TH></TR><TR>\n";
if ($sdg_tox eq 'T') { $tag_type = 'SDGTOX_AT_GLANCE' }
else { $tag_type = 'TOX_AT_GLANCE' }
my $sql = "SELECT Annot_Text FROM Annotation WHERE idGene = '$gene_id' AND Annot_Link = '$tag_type'";
$statement = $db_handle->prepare($sql);
$statement->execute;
@row = $statement->fetchrow_array;
my $tox_percentiles = $row[0];
@Issues = split(/\|\|/, $tox_percentiles);
$height = (($#Issues+7) * 9) + 15 . 'pt';
#$alt = 'You must have Adobe SVG Viewer installed to see the bar graphs. To install, click on the \"Start\" button on you desktop and then on \"Control Panel\".'
#		. ' Next, double-click on \"Run Advertised Programs\". Select the \"Adobe SVG Viewer\" from the list of programs, click on \"Run\" and follow the instructions.';
if ($species_common eq 'Human') {

	my $toxdata = $tox_percentiles;
	$toxdata =~ s/^\|+//;
	$toxdata =~ s/\|+$//;
	my @DataPairs = split(/\|\|/, $toxdata);
	print '<script type="text/javascript">
      	google.load("visualization", "1", {packages:["corechart"]});
      	google.setOnLoadCallback(drawChart);
			function drawChart() {
				var options = {
					title: "Human",
					hAxis: {title: "Scores", maxValue: 1.0, titleTextStyle: {color: "black"}},
					vAxis: {title: "', $y_label, '", titleTextStyle: {color: "black"}, series: {color: "red"}},
					colors: ["yellow", "orange", "red"],
					legend: "none",
					isStacked: true
				};
				var websites = new Array();
				',"\n";
	$base_link = $MiscLinks{TOXREPORTBASELINK} . $entrez . ';TOXTERM=';
	foreach $issuecat (keys(%IssueCatagories)) {
		print "websites[\'$issuecat\'] = \'$base_link$IssueCatagories{$issuecat}\';\n";
	}
	print '
				var data = new google.visualization.DataTable();
				data.addColumn("string", "Term");
				data.addColumn("number", "Score");
				data.addRows([
			 ';
	for ($idx = 0; $idx <= $#DataPairs; $idx++) {
		my $pair = $DataPairs[$idx];
		my ($tox, $score) = split(/:/, $pair);
		print "['$tox', $score]";
		if ($idx == $#DataPairs) { print "\n" }
		else { print ",\n" }
	}
	print "]);\n";
	print '
				var view = new google.visualization.DataView(data);
				view.setColumns([0, {
					type: "number",
					label: "Score",
					calc: function (dt, row) {
						return (dt.getValue(row, 1) < 0.5) ? dt.getValue(row, 1) : null;
					}
				}, {
					type: "number",
					label: "Score",
					calc: function (dt, row) {
						return (dt.getValue(row, 1) >= 0.5 && dt.getValue(row, 1) < 0.9) ? dt.getValue(row, 1) : null;
					}
				}, {
					type: "number",
					label: "Score",
					calc: function (dt, row) {
						return (dt.getValue(row, 1) >= 0.9) ? dt.getValue(row, 1.0) : null;
					}
				}]);
	 ',"\n";
	print '
				var chart = new google.visualization.BarChart(document.getElementById("chart_div"));
				chart.draw(view, options);
				google.visualization.events.addListener(chart, "select", function() {
					val = chart.getSelection();
					site = websites[data.getValue(val[0].row, 0)];
			  		window.location.href = site;
				} );
			}
			';
	print "</script>\n";	


	my $sql = "SELECT idGene, entrezID FROM Gene"
				. " WHERE idSpecies = (SELECT idSpecies FROM Species WHERE commonName = 'Mouse')"
				. " AND idHomolog = '$homologene_id'";
	$statement = $db_handle->prepare($sql);
	$statement->execute;
	@row = $statement->fetchrow_array;
	$homologous_gene_id = $row[0];
	$homologous_entrez = $row[1];
	
	if ($homologous_gene_id > 0) {
		my $sql = "SELECT Annot_Text FROM Annotation WHERE idGene = '$homologous_gene_id' AND Annot_Link = '$tag_type'";
		$statement = $db_handle->prepare($sql);
		$statement->execute;
		@row = $statement->fetchrow_array;
		my $tox_percentiles = $row[0];
		@Issues = split(/\|\|/, $tox_percentiles);
		$height = (($#Issues+7) * 9) + 15 . 'pt';
		
		my $toxdata = $tox_percentiles;
		$toxdata =~ s/^\|+//;
		$toxdata =~ s/\|+$//;
		my @DataPairs = split(/\|\|/, $toxdata);
		print '<script type="text/javascript">
			google.load("visualization", "1", {packages:["corechart"]});
			google.setOnLoadCallback(drawChart);
			function drawChart() {
				var options = {
					title: "Mouse",
					hAxis: {title: "Scores", maxValue: 1.0, titleTextStyle: {color: "black"}},
					vAxis: {title: "', $y_label, '", titleTextStyle: {color: "black"}, series: {color: "red"}},
					colors: ["yellow", "orange", "red"],
					legend: "none",
					isStacked: true
				};
				var websites_2 = new Array();
				';
		$base_link = $MiscLinks{TOXREPORTBASELINK} . $homologous_entrez . ';TOXTERM=';
		foreach $issuecat (keys(%IssueCatagories)) {
			print "websites_2[\"$issuecat\"] = \"$base_link$IssueCatagories{$issuecat}\";\n";
		}
		print '
      	  var data_2 = google.visualization.arrayToDataTable([
			  ["Term", "Score", { role: "style" }],',"\n";
		for ($idx = 0; $idx <= $#DataPairs; $idx++) {
			my $pair = $DataPairs[$idx];
			my ($tox, $score) = split(/:/, $pair);
			print "['$tox', $score, 'color: gray']";
			if ($idx == $#DataPairs) { print "\n" }
			else { print ",\n" }
		}
		print "]);\n";
	
		print '
				var view_2 = new google.visualization.DataView(data_2);
				view_2.setColumns([0, {
					type: "number",
					label: "Score",
					calc: function (dt, row) {
						return (dt.getValue(row, 1) < 0.5) ? dt.getValue(row, 1) : null;
					}
				}, {
					type: "number",
					label: "Score",
					calc: function (dt, row) {
						return (dt.getValue(row, 1) >= 0.5 && dt.getValue(row, 1) < 0.9) ? dt.getValue(row, 1) : null;
					}
				}, {
					type: "number",
					label: "Score",
					calc: function (dt, row) {
						return (dt.getValue(row, 1) >= 0.9) ? dt.getValue(row, 1.0) : null;
					}
				}]);
		',"\n";;
	
		print '
				var chart_2 = new google.visualization.BarChart(document.getElementById("chart_div_2"));
				chart_2.draw(view_2, options);
				google.visualization.events.addListener(chart_2, "select", function() {
					val_2 = chart_2.getSelection();
					site_2 = websites_2[data_2.getValue(val_2[0].row, 0)];
					window.location.href = site_2;
				} );
      	}
   	 </script>';
		print "\n";	
		print '<TABLE><TR><TD><div id="chart_div" style="width: 500px; height: 300px;"></div></TD><TD><div id="chart_div_2" style="width: 500px; height: 300px;"></div></TD></TR></TABLE>';
	}
}
elsif ($species_common eq 'Mouse') {
	my $toxdata = $tox_percentiles;
	$toxdata =~ s/^\|+//;
	$toxdata =~ s/\|+$//;
	my @DataPairs = split(/\|\|/, $toxdata);
	print '<script type="text/javascript">
      	google.load("visualization", "1", {packages:["corechart"]});
      	google.setOnLoadCallback(drawChart);
			function drawChart() {
				var options = {
					title: "Mouse",
					hAxis: {title: "Scores", maxValue: 1.0, titleTextStyle: {color: "black"}},
					vAxis: {title: "', $y_label, '", titleTextStyle: {color: "black"}, series: {color: "red"}},
					colors: ["yellow", "orange", "red"],
					legend: "none",
					isStacked: true
				};
				var websites = new Array();
				',"\n";
	$base_link = $MiscLinks{TOXREPORTBASELINK} . $entrez . ';TOXTERM=';
	foreach $issuecat (keys(%IssueCatagories)) {
		print "websites[\'$issuecat\'] = \'$base_link$IssueCatagories{$issuecat}\';\n";
	}
	print '
				var data = new google.visualization.DataTable();
				data.addColumn("string", "Term");
				data.addColumn("number", "Score");
				data.addRows([
			 ';
	for ($idx = 0; $idx <= $#DataPairs; $idx++) {
		my $pair = $DataPairs[$idx];
		my ($tox, $score) = split(/:/, $pair);
		print "['$tox', $score]";
		if ($idx == $#DataPairs) { print "\n" }
		else { print ",\n" }
	}
	print "]);\n";
	print '
				var view = new google.visualization.DataView(data);
				view.setColumns([0, {
					type: "number",
					label: "Score",
					calc: function (dt, row) {
						return (dt.getValue(row, 1) < 0.5) ? dt.getValue(row, 1) : null;
					}
				}, {
					type: "number",
					label: "Score",
					calc: function (dt, row) {
						return (dt.getValue(row, 1) >= 0.5 && dt.getValue(row, 1) < 0.9) ? dt.getValue(row, 1) : null;
					}
				}, {
					type: "number",
					label: "Score",
					calc: function (dt, row) {
						return (dt.getValue(row, 1) >= 0.9) ? dt.getValue(row, 1.0) : null;
					}
				}]);
	 ',"\n";
	print '
				var chart = new google.visualization.BarChart(document.getElementById("chart_div"));
				chart.draw(view, options);
				google.visualization.events.addListener(chart, "select", function() {
					val = chart.getSelection();
					site = websites[data.getValue(val[0].row, 0)];
			  		window.location.href = site;
				} );
			}
			';
	print "</script>\n";	

	my $sql = "SELECT idGene, entrezID FROM Gene"
				. " WHERE idSpecies = (SELECT idSpecies FROM Species WHERE commonName = 'Human')"
				. " AND idHomolog = '$homologene_id'";
	$statement = $db_handle->prepare($sql);
	$statement->execute;
	@row = $statement->fetchrow_array;
	$homologous_gene_id = $row[0];
	$homologous_entrez = $row[1];

	if ($homologous_gene_id > 0) {
		my $sql = "SELECT Annot_Text FROM Annotation WHERE idGene = '$homologous_gene_id' AND Annot_Link = '$tag_type'";
		$statement = $db_handle->prepare($sql);
		$statement->execute;
		@row = $statement->fetchrow_array;
		my $tox_percentiles = $row[0];
		@Issues = split(/\|\|/, $tox_percentiles);
		$height = (($#Issues+7) * 9) + 15 . 'pt';
		
		my $toxdata = $tox_percentiles;
		$toxdata =~ s/^\|+//;
		$toxdata =~ s/\|+$//;
		my @DataPairs = split(/\|\|/, $toxdata);
		print '<script type="text/javascript">
			google.load("visualization", "1", {packages:["corechart"]});
			google.setOnLoadCallback(drawChart);
			function drawChart() {
				var options = {
					title: "Human",
					hAxis: {title: "Scores", maxValue: 1.0, titleTextStyle: {color: "black"}},
					vAxis: {title: "', $y_label, '", titleTextStyle: {color: "black"}, series: {color: "red"}},
					colors: ["yellow", "orange", "red"],
					legend: "none",
					isStacked: true
				};
				var websites_2 = new Array();
				';
		$base_link = $MiscLinks{TOXREPORTBASELINK} . $homologous_entrez . ';TOXTERM=';
		foreach $issuecat (keys(%IssueCatagories)) {
			print "websites_2[\"$issuecat\"] = \"$base_link$IssueCatagories{$issuecat}\";\n";
		}
		print '
      	  var data_2 = new google.visualization.DataTable();
			  data_2.addColumn("string", "Term");
			  data_2.addColumn("number", "Score");
			  data_2.addRows([';
		for ($idx = 0; $idx <= $#DataPairs; $idx++) {
			my $pair = $DataPairs[$idx];
			my ($tox, $score) = split(/:/, $pair);
			print "['$tox', $score]";
			if ($idx == $#DataPairs) { print "\n" }
			else { print ",\n" }
		}
		print "]);\n";
	
		print '
				var view_2 = new google.visualization.DataView(data_2);
				view_2.setColumns([0, {
					type: "number",
					label: "Score",
					calc: function (dt, row) {
						return (dt.getValue(row, 1) < 0.5) ? dt.getValue(row, 1) : null;
					}
				}, {
					type: "number",
					label: "Score",
					calc: function (dt, row) {
						return (dt.getValue(row, 1) >= 0.5 && dt.getValue(row, 1) < 0.9) ? dt.getValue(row, 1) : null;
					}
				}, {
					type: "number",
					label: "Score",
					calc: function (dt, row) {
						return (dt.getValue(row, 1) >= 0.9) ? dt.getValue(row, 1.0) : null;
					}
				}]);
		',"\n";;
	
		print '
				var chart_2 = new google.visualization.BarChart(document.getElementById("chart_div_2"));
				chart_2.draw(view_2, options);
				google.visualization.events.addListener(chart_2, "select", function() {
					val_2 = chart_2.getSelection();
					site_2 = websites_2[data_2.getValue(val_2[0].row, 0)];
					window.location.href = site_2;
				} );
      	}
   	 </script>';
		print "\n";	
		print '<TABLE><TR><TD><div id="chart_div" style="width: 500px; height: 300px;"></div></TD><TD><div id="chart_div_2" style="width: 500px; height: 300px;"></div></TD></TR></TABLE>';
	}
}
print "</TR></TABLE>\n";

my $data_warning = ' (Warning! Data for this toxicity has not been loaded!)';
if (($IssueCatagories{$tox_term} ne '')
		|| ($tox_term eq 'Pfizer_Toxicities')
		|| ($tox_term eq 'Organ_System')
		|| ($tox_term eq 'Toxicity_Mechanism')) { $data_warning = '' }
if (($tox_term ne "") && ($tox_sys_name ne "")) {
	print h2("<I>$tox_term$data_warning</I> <FONT SIZE='-1'>(from '$tox_sys_name')</FONT> issues will be flagged.<br>\n");
	my $toolbox_link = $MiscLinks{TOOLBOX};
	foreach $toolbox_id (keys %ToolBox_2_ToxGene) {
		if ($ToolBox_2_ToxGene{$toolbox_id} =~ /$tox_native_id/i) {
			print h3("<span class='help_info' tooltip-data='$ToolTips{DeriskLink}'><span class='ui-icon ui-icon-info' style='float: left; margin-right: .3em;'></span><a href='$toolbox_link$toolbox_id'>Potential de-risking assays</a></span>");
			print "<BR>";
		}
	}
}
else {
	print h2("<I>Warning!</I> No toxicity issues have be flagged.<br>\n");
}
%Issues = ();


#####################################################################################
#	display gene database cross references
#####################################################################################
$tb_link = $MiscLinks{TARGETPEDIA};
if (($genebook ne "") && ($genebook ne "N.A.")) {
# The following line can be uncommented and modified to search internal gene identifiers
#	print "TargetPedia: <A HREF='$tb_link$genebook'>$genebook</A><BR>\n";
}
else {
# The following line can be uncommented and modified to search internal gene identifiers
#	print "GeneBook: Not available.<BR>\n";
}
$entrez_link = $MiscLinks{GENEID_URL};
print "Entrez: <A HREF='$entrez_link$entrez'>$entrez</A><BR>\n";
if ($symbol ne '') {
	if ($species_common eq 'Mouse') {
		my $d_brain_link = $MiscLinks{ALLEN_DEV_MOUSE} . $symbol;
		my $a_brain_link = $MiscLinks{ALLEN_ADULT_MOUSE} . $symbol;
		print "Gene Symbol: (<A HREF='$a_brain_link'>Adult Mouse Brain</A>)(<A HREF='$d_brain_link'>Developing Mouse Brain</A>)<BR>\n";
	}
	elsif ($species_common eq 'Human') {
		my $targetpedia_link = $MiscLinks{TARGETPEDIA} . $symbol;
		my $a_brain_link = $MiscLinks{ALLEN_ADULT_HUMAN} . $symbol;
		print "Gene Symbol: $symbol (<A HREF='$targetpedia_link'>Pfizer TargetPedia</A>)(<A HREF='$a_brain_link'>Adult Brain</A>)<BR>\n";
	}
}

%Xrefs = ();
my $sql = "SELECT idXref, Xref_Source, Xref_ID"
			. " FROM Xref"
			. " WHERE idGene = '$gene_id'";
$statement = $db_handle->prepare($sql);
$statement->execute;
while(@row = $statement->fetchrow_array) {
	my $id_xref = $row[0];
	my $source = $row[1];
	my $id = $row[2];
	$Xrefs{$id_xref}{SOURCE} = $source;
	$Xrefs{$id_xref}{XREF_ID} = $id;
}
my @Sorted_XrefIDS = sort by_xref_source (keys %Xrefs);
find_tox_term_issues_by_type('XREF', join(', ', @Sorted_XrefIDS));
$ensembl_id = '';
foreach $id_xref (@Sorted_XrefIDS) {
	my $id = $Xrefs{$id_xref}{XREF_ID};
	my $source = $Xrefs{$id_xref}{SOURCE};

	my $tox_issue_flag = 'F';
	my $reason = "<UL>";
	if (defined $Issues{XREF}{$id_xref}) {
		if (($source eq 'MIM') || ($source eq 'MIM_DOM')) { next }
		$tox_issue_flag = 'T';
		my $tti = $Issues{XREF}{$id_xref}{TOX_TERM_ID};
		foreach $evid_id (keys %{$Issues{XREF}{$id_xref}{EVID}}) {
			$reason .= "<LI>" . $Issues{XREF}{$id_xref}{EVID}{$evid_id} . "</LI>";
		}
	}
	$reason .= "</UL>";
	if ($tox_issue_flag eq 'T') {
		$reason =~ s/'/\\&quot;/g;
		$reason =~ s/"/\\&quot;/g;
		$reason =~ s/[\n\r\f]+//g;
		print "<span class='evid_info' tooltip-data='$reason'><img src='$image_path/RedFlag_25.png'height='26' width='20' /></span>\n";
	}

	if ($source eq 'Ensembl') {
		my $link = $MiscLinks{ENSEMBLGENE_URL} . $id;
		print "Ensembl Gene: <A HREF='$link'>$id</A><BR>\n";
		$ensembl_id = $id;
	}
	elsif ($source eq 'HGNC') {
		my $link = $MiscLinks{HUGO_GENE_URL} . $id;
		print "HUGO Gene: <A HREF='$link'>$id</A><BR>\n";
	}
	elsif ($source eq 'MIM') {
		my $link = $MiscLinks{MIM_GENE_URL} . $id;
		print "OMIM Entry: <A HREF='$link'>$id</A><BR>\n";
	}
	elsif ($source eq 'MIM_DOM') {
		my $link = $MiscLinks{MIM_GENE_URL} . $id;
		print "OMIM Entry: <A HREF='$link'>$id</A> <FONT COLOR='RED'>Potential Autosomal Dominant</FONT><BR>\n";
	}
	elsif ($source eq 'AFFY_PROBESET') { next }
	elsif ($source eq 'HPRD') {
		my $link = $MiscLinks{HUM_PROT_REF_DB} . $id;
		print "Human Protein Reference Database: <A HREF='$link'>$id</A><BR>\n";
	}
	elsif ($source eq 'MGI') {
		my $link = $MiscLinks{MGI_GENE_URL} . $id;
		print "MGI Gene: <A HREF='$link'>$id</A><BR>\n";
	}
	elsif ($source eq 'RGD') {
		my $link = $MiscLinks{RGD_GENE_URL} . $id;
		print "RGD Gene: <A HREF='$link'>$id</A><BR>\n";
	}
	elsif ($source eq 'RATMAP') {
		my $link = $MiscLinks{RATMAP_GENE_URL} . $id;
		print "RATMAP Entry: <A HREF='$link'>$id</A><BR>\n";
	}
	elsif ($source eq 'Vega') {
		my $link = $MiscLinks{VEGA_GENOME} . $id;
		print "Vega Genome Database: <A HREF='$link'>$id</A><BR>\n";
	}
	elsif ($source eq 'ZFIN') {
		my $link = $MiscLinks{ZFIN_GENE_URL} . $id;
		print "ZFIN Gene: <A HREF='$link'>$id</A><BR>\n";
	}
	else {
		print "$source: $id<BR>\n";
	}
}

#####################################################################################
#	display Precision Medicine
#####################################################################################
print "<H2>Precision Medicine</H2>";
	my $link_1 = $MiscLinks{EXAC_BROWSER} . $ensembl_id;
	my $link_2 = $MiscLinks{DB_SNP} . $entrez;
	my $link_3 = $MiscLinks{NCBI_HAPMAP} . $symbol;
	my $link_4 = $MiscLinks{HUGE_NAVIGATOR} . $symbol;
	print "(<A HREF='$link_1'>ExAC Browser</A>)&nbsp;&nbsp;&nbsp;(<A HREF='$link_2'>dbSNP Database</A>)&nbsp;&nbsp;&nbsp;(<A HREF='$link_3'>HapMap Database</A>)&nbsp;&nbsp;&nbsp;(<A HREF='$link_4'>HuGENavigator</A>)<BR>\n";
$shown_title = 'F';
foreach $id_xref (@Sorted_XrefIDS) {
	my $id = $Xrefs{$id_xref}{XREF_ID};
	my $source = $Xrefs{$id_xref}{SOURCE};

	my $tox_issue_flag = 'F';
	my $reason = "<UL>";
	if (defined $Issues{XREF}{$id_xref}) {
		$tox_issue_flag = 'T';
		my $tti = $Issues{XREF}{$id_xref}{TOX_TERM_ID};
		foreach $evid_id (keys %{$Issues{XREF}{$id_xref}{EVID}}) {
			$reason .= "<LI>" . $Issues{XREF}{$id_xref}{EVID}{$evid_id} . "</LI>";
		}
	}
	$reason .= "</UL>";
	if ($tox_issue_flag ne 'T') { next }
	else {
		if ($shown_title eq 'F') {
			print "<B>OMIM Links</B><BR>";
			$shown_title = 'T';
		}
		$reason =~ s/'/\\&quot;/g;
		$reason =~ s/"/\\&quot;/g;
		$reason =~ s/[\n\r\f]+//g;
		print "<span class='evid_info' tooltip-data='$reason'><img src='$image_path/RedFlag_25.png'height='26' width='20' /></span>\n";
	}

	if ($source eq 'MIM') {
		my $link = $MiscLinks{MIM_GENE_URL} . $id;
		print "OMIM Entry: <A HREF='$link'>$id</A><BR>\n";
	}
	elsif ($source eq 'MIM_DOM') {
		my $link = $MiscLinks{MIM_GENE_URL} . $id;
		print "OMIM Entry: <A HREF='$link'>$id</A> <FONT COLOR='RED'>Potential Autosomal Dominant</FONT><BR>\n";
	}
}

###################################################################
#	Load the Class information (i.e. pathways, GO catagories, etc.)
#   and the evidence linking a gene to the classes
###################################################################
%ClassHash = ();
@ClassList = ();
@ClassIDList = ();
my $sql = "SELECT GC.idGene_Class, C.Class_Native_ID, C.Class_Name, C.Class_Desc, CS.Class_Sys_Name, C.idClass"
			. " FROM Gene_Class GC, Class C, Class_System CS"
			. " WHERE C.idClass = GC.idClass"
			. " AND CS.idClass_System = C.idClass_System"
			. " AND GC.idGene = '$gene_id'";
$statement = $db_handle->prepare($sql);
$statement->execute;
while(@row = $statement->fetchrow_array) {
	my $id_gene_class = $row[0];
	my $class_native_id = $row[1];
	my $class_name = $row[2];
	my $class_desc = $row[3];
	my $class_sys_name = $row[4];
	my $id_class = $row[5];
	push(@ClassList, $id_gene_class);
	push(@ClassIDList, $id_class);
	$ClassHash{$id_gene_class}{SYSTEM} = $class_sys_name;
	$ClassHash{$id_gene_class}{NATIVE} = $class_native_id;
	$ClassHash{$id_gene_class}{NAME} = $class_name;
	$ClassHash{$id_gene_class}{DESC} = $class_desc;
	$ClassHash{$id_gene_class}{CLASS} = $id_class;
}
my @SortClassList = sort {uc($ClassHash{$a}{NAME}) cmp uc($ClassHash{$b}{NAME})} (keys %ClassHash);
my $num_classes = $#ClassList;

$sql = "";
for ($idx = 0; $idx <= $num_classes; $idx += 900) {
	my $start_idx = $idx;
	my $end_idx = $idx + 899;
	if ($end_idx > $num_classes) { $end_idx = $num_classes }
#print "START -$start_idx\tEND - $end_idx\n\n";
	if ($start_idx == 0) {
	$sql = "SELECT idGene_Class, idClass_Evid, Evid_Type, Evidence, Evid_Score, Update_Date"
			. " FROM Class_Evid"
			. " WHERE idGene_Class in ("
			. join(", ", @ClassList[$start_idx..$end_idx]) . ")";
	}
	else {
	$sql .= " UNION SELECT idGene_Class, idClass_Evid, Evid_Type, Evidence, Evid_Score, Update_Date"
			. " FROM Class_Evid"
			. " WHERE idGene_Class in ("
			. join(", ", @ClassList[$start_idx..$end_idx]) . ")";
	}
}

$statement = $db_handle->prepare($sql);
$statement->execute;
while(@row = $statement->fetchrow_array) {
	my $id_gene_class = $row[0];
	my $idclass_evid = $row[1];
	my $evid_type = $row[2];
	my $evidence = $row[3];
	my $evid_score = $row[4];
	my $update_date = $row[5];
	$ClassHash{$id_gene_class}{EVID}{$idclass_evid}{TYPE} = $evid_type;
	$ClassHash{$id_gene_class}{EVID}{$idclass_evid}{EVIDENCE} = $evidence;
	$ClassHash{$id_gene_class}{EVID}{$idclass_evid}{SCORE} = $evid_score;
	$ClassHash{$id_gene_class}{EVID}{$idclass_evid}{DATE} = $update_date;
}

find_tox_term_issues_by_type('CLASS', join(', ', @ClassIDList));

$class_sys = 'Genetic Association Database';
$not_flagged = 0;
$number_flagged = 0;
print "<B>Genetic Association Links</B><BR><TABLE BORDER=0><TR VALIGN='top'>";
$cell_count = 1;
foreach $id_gene_class (@SortClassList) {
	my $tox_issue_flag = 'F';
	if ($ClassHash{$id_gene_class}{SYSTEM} ne $class_sys) { next }
	my $native = $ClassHash{$id_gene_class}{NATIVE};
	my $name = $ClassHash{$id_gene_class}{NAME};
	my $id_class = $ClassHash{$id_gene_class}{CLASS};
	my $link = $MiscLinks{GENETIC_ASSOC_RPT} . $native;
	my $reason = "<UL>";
	my $class_id = $ClassHash{$id_gene_class}{CLASS};
	if (defined $Issues{CLASS}{$class_id}) {
		$tox_issue_flag = 'T';
		$number_flagged++;
		my $tti = $Issues{CLASS}{$class_id}{TOX_TERM_ID};
		foreach $evid_id (keys %{$Issues{CLASS}{$class_id}{EVID}}) {
			$reason .= "<LI>" . $Issues{CLASS}{$class_id}{EVID}{$evid_id} . "</LI>";
		}
	}
	$reason .= "</UL>";
	if ($tox_issue_flag eq 'T') {
		$reason =~ s/'/\\\"/g;
		print "<TD><span class='evid_info' tooltip-data='$reason'><img src='$image_path/RedFlag_25.png'height='26' width='20' /></span></TD>\n";
		print "<TD><A HREF='$link' TITLE='Open Genetic Association Database record.'>$name</A></TD><TD>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</TD>";
		$cell_count++;
	}
	elsif ($show_all eq 'T') {
		print "<TD>-</TD>\n";	
		print "<TD><A HREF='$link' title = '$desc'>$name</A></TD>";
		$cell_count++;
	}
	else {
		$not_flagged++;	
	}
	if ($cell_count > 5) {
		print "</TR>\n<TR VALIGN='top'>";
		$cell_count = 1;
	}
}
if ($show_all ne 'T') {
	print "<TR><TD COLSPAN='3'><I>$not_flagged unflagged terms.</I></TD></TR>\n";
}
print '</TABLE>';

$class_sys = 'Genome-Wide Association Studies';
$not_flagged = 0;
$number_flagged = 0;
#print '<TABLE><TR><TH COLSPAN=2>Genetic Association Links</TH></TR>';
print "<B>Genome-Wide Association Study Links</B><BR><TABLE BORDER=0><TR VALIGN='top'>";
$cell_count = 1;
foreach $id_gene_class (@SortClassList) {
	my $tox_issue_flag = 'F';
	if ($ClassHash{$id_gene_class}{SYSTEM} ne $class_sys) { next }
	my $native = $ClassHash{$id_gene_class}{NATIVE};
	$native =~ s/^(\d+)\:\d+$/$1/;
	my $name = $ClassHash{$id_gene_class}{NAME};
	$name =~ s/^(\d+)\:\d+$/$1/;
	my $id_class = $ClassHash{$id_gene_class}{CLASS};
	my $link = $MiscLinks{PUBMED_URL} . $native;
	my $reason = "<UL>";
	my $class_id = $ClassHash{$id_gene_class}{CLASS};
	if (defined $Issues{CLASS}{$class_id}) {
		$tox_issue_flag = 'T';
		$number_flagged++;
		my $tti = $Issues{CLASS}{$class_id}{TOX_TERM_ID};
		foreach $evid_id (keys %{$Issues{CLASS}{$class_id}{EVID}}) {
			$reason .= "<LI>" . $Issues{CLASS}{$class_id}{EVID}{$evid_id} . "</LI>";
		}
	}
	$reason .= "</UL>";
	if ($tox_issue_flag eq 'T') {
		$reason =~ s/'/\\\"/g;
		print "<TD><span class='evid_info' tooltip-data='$reason'><img src='$image_path/RedFlag_25.png'height='26' width='20' /></span></TD>\n";
		print "<TD><A HREF='$link' TITLE='Open Genetic Association Database record.'>$name</A></TD><TD>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</TD>";
		$cell_count++;
	}
	elsif ($show_all eq 'T') {
		print "<TD>-</TD>\n";	
		print "<TD><A HREF='$link' title = '$desc'>$name</A></TD>";
		$cell_count++;
	}
	else {
		$not_flagged++;	
	}
	if ($cell_count > 5) {
		print "</TR>\n<TR VALIGN='top'>";
		$cell_count = 1;
	}
}
if ($show_all ne 'T') {
	print "<TR><TD COLSPAN='3'><I>$not_flagged unflagged terms.</I></TD></TR>\n";
}
print '</TABLE>';


my $sql = "SELECT Annot_Text FROM Annotation WHERE idGene = '$gene_id' AND Annot_Link = 'HIGH_FREQ_MIS_SNP'";
$statement = $db_handle->prepare($sql);
$statement->execute;
my $num_high_freq_snps = 0;
%SNP_Info = ();
while (@row = $statement->fetchrow_array) {
	$num_high_freq_snps++;
	my $info = $row[0];
	my ($snp_id, $freq_info) = split(/\s+\-\s+/, $info);
	$SNP_Info{$snp_id} = $freq_info;
}
if ($num_high_freq_snps > 0) {
	print h3("<span class='help_info' tooltip-data='$ToolTips{HighFreqSNP}'><span class='ui-icon ui-icon-info' style='float: left; margin-right: .3em;'></span>Alert: High Frequency Missense SNP(s)!</span>");
	print "<ul>\n";
	foreach $snp_id (keys(%SNP_Info)) {
		my $snp_info = $SNP_Info{$snp_id};
		my $link = $MiscLinks{DB_SNP2} . $snp_id . '#Diversity';
		print "<li><span class='help_info' tooltip-data='$snp_info'><A HREF='$link'>$snp_id</a></span></li>\n";
	}
	print "</ul>\n";
}

#####################################################################################
#	display GO gene ontologies
#####################################################################################
print "<H2>Gene Ontologies</H2>";
$class_sys = 'Gene Ontologies';
print '<TABLE border="0">';
print '<TR><TH COLSPAN="3">Function</TH></TR>';
print '<TR><TH>Flags</TH><TH>GO Term</TH><TH>Support linking gene to ontology</TH></TR>';
$not_flagged = 0;
$number_flagged = 0;
foreach $id_gene_class (@SortClassList) {
	my $tox_issue_flag = 'F';
	if (($ClassHash{$id_gene_class}{SYSTEM} ne $class_sys) || ($ClassHash{$id_gene_class}{DESC} !~ /^molecular_function/)) { next }
	my $native = $ClassHash{$id_gene_class}{NATIVE};
	my $name = $ClassHash{$id_gene_class}{NAME};
	my $desc = $ClassHash{$id_gene_class}{DESC};
	my $id_class = $ClassHash{$id_gene_class}{CLASS};
	$_ = $native;
	$cnt = tr/0-9//;
	my $id = 'GO:' . '0'x(7-$cnt) . $native;
	my $link = $MiscLinks{GO_URL} . $id;
	my $reason = "<UL>";
	my $class_id = $ClassHash{$id_gene_class}{CLASS};
	if (defined $Issues{CLASS}{$class_id}) {
		$tox_issue_flag = 'T';
		$number_flagged++;
		my $tti = $Issues{CLASS}{$class_id}{TOX_TERM_ID};
		foreach $evid_id (keys %{$Issues{CLASS}{$class_id}{EVID}}) {
			$reason .= "<LI>" . $Issues{CLASS}{$class_id}{EVID}{$evid_id} . "</LI>";
		}
	}
	$reason .= "</UL>";
	if ($tox_issue_flag eq 'T') {
		$reason =~ s/'/\\\"/g;
		print "<TD><span class='evid_info' tooltip-data='$reason'><img src='$image_path/RedFlag_25.png'height='26' width='20' /></span></TD>\n";
		print "<TD><A HREF='$link' title = '$desc'>$name</A></TD><TD>";
	}
	elsif ($show_all eq 'T') {
		print "<TR VALIGN='top'><TD>-</TD>\n";	
		print "<TD><A HREF='$link' title = '$desc'>$name</A></TD><TD>";
	}
	else {
		$not_flagged++;	
	}
	%Evidence = %{$ClassHash{$id_gene_class}{EVID}};
	if (($show_all eq 'T') || ($tox_issue_flag eq 'T')) {
		foreach $idclass_evid (keys %Evidence) {
			my $type = $Evidence{$idclass_evid}{TYPE};
			my $title = $GO_Sup_Def{$type};
			my $evidence = $Evidence{$idclass_evid}{EVIDENCE};
			$evidence =~ s/-$//;
			my ($qualifier, @PubmedIDs) = split(/\|/, $evidence);
			$qualifier =~ s/\-+//g;
			$qualifier =~ s/NOT/<B>NOT<\/B> /g;
			if ($#PubmedIDs >= 0) {
				my $link = $MiscLinks{PUBMED_URL} . join(",", @PubmedIDs);
				print "&nbsp;&nbsp;$qualifier <A HREF='$link' title='$title'>$type</A><BR>";
			}
			else {
				print "&nbsp;&nbsp;$qualifier <I title='$title'>$type</I><BR>";
			}
		}
	print "</TD></TR>\n";
	}
}
if ($show_all ne 'T') {
	print "<TR><TD COLSPAN='3'><I>$not_flagged unflagged terms.</I></TD></TR>\n";
}

print '<TR><TH COLSPAN="3">Process</TH></TR>';
print '<TR><TH>Flags</TH><TH>GO Term</TH><TH>Support linking gene to ontology</TH></TR>';
$not_flagged = 0;
$number_flagged = 0;
foreach $id_gene_class (@SortClassList) {
	my $tox_issue_flag = 'F';
	if (($ClassHash{$id_gene_class}{SYSTEM} ne $class_sys) || ($ClassHash{$id_gene_class}{DESC} !~ /^biological_process/)) { next }
	my $native = $ClassHash{$id_gene_class}{NATIVE};
	my $name = $ClassHash{$id_gene_class}{NAME};
	my $desc = $ClassHash{$id_gene_class}{DESC};
	my $id_class = $ClassHash{$id_gene_class}{CLASS};
	$_ = $native;
	$cnt = tr/0-9//;
	my $id = 'GO:' . '0'x(7-$cnt) . $native;
	my $link = $MiscLinks{GO_URL} . $id;
	my $reason = "<UL>";
	my $class_id = $ClassHash{$id_gene_class}{CLASS};
	if (defined $Issues{CLASS}{$class_id}) {
		$tox_issue_flag = 'T';
		$number_flagged++;
		my $tti = $Issues{CLASS}{$class_id}{TOX_TERM_ID};
		foreach $evid_id (keys %{$Issues{CLASS}{$class_id}{EVID}}) {
			$reason .= "<LI>" . $Issues{CLASS}{$class_id}{EVID}{$evid_id} . "</LI>";
		}
	}
	$reason .= "</UL>";
	if ($tox_issue_flag eq 'T') {
		$reason =~ s/'/\\\"/g;
		print "<TR VALIGN='top'>";
		print "<TD><span class='evid_info' tooltip-data='$reason'><img src='$image_path/RedFlag_25.png'height='26' width='20' /></span></TD>\n";
		print "<TD><A HREF='$link' title = '$desc'>$name</A></TD><TD>";
	}
	elsif ($show_all eq 'T') {
		print "<TR VALIGN='top'><TD>-</TD>\n";	
		print "<TD><A HREF='$link' title = '$desc'>$name</A></TD><TD>";
	}
	else {
		$not_flagged++;	
	}
	%Evidence = %{$ClassHash{$id_gene_class}{EVID}};
	if (($show_all eq 'T') || ($tox_issue_flag eq 'T')) {
		foreach $idclass_evid (keys %Evidence) {
			my $type = $Evidence{$idclass_evid}{TYPE};
			my $title = $GO_Sup_Def{$type};
			my $evidence = $Evidence{$idclass_evid}{EVIDENCE};
			$evidence =~ s/-$//;
			my ($qualifier, @PubmedIDs) = split(/\|/, $evidence);
			$qualifier =~ s/\-+//g;
			$qualifier =~ s/NOT/<B>NOT<\/B> /g;
			if ($#PubmedIDs >= 0) {
				my $link = $MiscLinks{PUBMED_URL} . join(",", @PubmedIDs);
				print "&nbsp;&nbsp;$qualifier <A HREF='$link' title='$title'>$type</A><BR>";
			}
			else {
				print "&nbsp;&nbsp;$qualifier <I title='$title'>$type</I><BR>";
			}
		}
	print "</TD></TR>\n";
	}
}

if ($show_all ne 'T') {
	print "<TR><TD COLSPAN='3'><I>$not_flagged unflagged terms.</I></TD></TR>\n";
}
print '<TR><TH COLSPAN="3">Component</TH></TR>';
print '<TR><TH>Flags</TH><TH>GO Term</TH><TH>Support linking gene to ontology</TH></TR>';
$not_flagged = 0;
$number_flagged = 0;
foreach $id_gene_class (@SortClassList) {
	my $tox_issue_flag = 'F';
	if (($ClassHash{$id_gene_class}{SYSTEM} ne $class_sys) || ($ClassHash{$id_gene_class}{DESC} !~ /^cellular_component/)) { next }
	my $native = $ClassHash{$id_gene_class}{NATIVE};
	my $name = $ClassHash{$id_gene_class}{NAME};
	my $desc = $ClassHash{$id_gene_class}{DESC};
	my $id_class = $ClassHash{$id_gene_class}{CLASS};
	$_ = $native;
	$cnt = tr/0-9//;
	my $id = 'GO:' . '0'x(7-$cnt) . $native;
	my $link = $MiscLinks{GO_URL} . $id;
	my $reason = "<UL>";
	my $class_id = $ClassHash{$id_gene_class}{CLASS};
	if (defined $Issues{CLASS}{$class_id}) {
		$tox_issue_flag = 'T';
		$number_flagged++;
		my $tti = $Issues{CLASS}{$class_id}{TOX_TERM_ID};
		foreach $evid_id (keys %{$Issues{CLASS}{$class_id}{EVID}}) {
			$reason .= "<LI>" . $Issues{CLASS}{$class_id}{EVID}{$evid_id} . "</LI>";
		}
	}
	$reason .= "</UL>";
	if ($tox_issue_flag eq 'T') {
		$reason =~ s/'/\\\"/g;
		print "<TR VALIGN='top'>";
		print "<TD><span class='evid_info' tooltip-data='$reason'><img src='$image_path/RedFlag_25.png'height='26' width='20' /></span></TD>\n";
		print "<TD><A HREF='$link' title = '$desc'>$name</A></TD><TD>";
	}
	elsif ($show_all eq 'T') {
		print "<TR VALIGN='top'><TD>-</TD>\n";	
		print "<TD><A HREF='$link' title = '$desc'>$name</A></TD><TD>";
	}
	else {
		$not_flagged++;	
	}
	%Evidence = %{$ClassHash{$id_gene_class}{EVID}};
	if (($show_all eq 'T') || ($tox_issue_flag eq 'T')) {
		foreach $idclass_evid (keys %Evidence) {
			my $type = $Evidence{$idclass_evid}{TYPE};
			my $title = $GO_Sup_Def{$type};
			my $evidence = $Evidence{$idclass_evid}{EVIDENCE};
			$evidence =~ s/-$//;
			my ($qualifier, @PubmedIDs) = split(/\|/, $evidence);
			$qualifier =~ s/\-+//g;
			$qualifier =~ s/NOT/<B>NOT<\/B> /g;
			if ($#PubmedIDs >= 0) {
				my $link = $MiscLinks{PUBMED_URL} . join(",", @PubmedIDs);
				print "&nbsp;&nbsp;$qualifier <A HREF='$link' title='$title'>$type</A><BR>";
			}
			else {
				print "&nbsp;&nbsp;$qualifier <I title='$title'>$type</I><BR>";
			}
		}
	print "</TD></TR>\n";
	}
}

if ($show_all ne 'T') {
	print "<TR><TD COLSPAN='3'><I>$not_flagged unflagged terms.</I></TD></TR>\n";
}
print '</TABLE>';

#####################################################################################
#	display Ingenuity Pathways
#####################################################################################
print "<H2>Ingenuity Pathways</H2>\n";
$class_sys = 'Ingenuity Pathways';
$not_flagged = 0;
$number_flagged = 0;
print '<TABLE><TR><TH>Flags</TH><TH>Pathway</TH></TR>';
foreach $id_gene_class (@SortClassList) {
	my $tox_issue_flag = 'F';
	if ($ClassHash{$id_gene_class}{SYSTEM} ne $class_sys) { next }
	print "<TR VALIGN='top'>\n";
	my $native = $ClassHash{$id_gene_class}{NATIVE};
	my $name = $ClassHash{$id_gene_class}{NAME};
	my $id_class = $ClassHash{$id_gene_class}{CLASS};
	my $link = $MiscLinks{INGENUITY_URL} . $native . '&geneid=' . $entrez;
	my $reason = "<UL>";
	my $class_id = $ClassHash{$id_gene_class}{CLASS};
	if (defined $Issues{CLASS}{$class_id}) {
		$tox_issue_flag = 'T';
		$number_flagged++;
		my $tti = $Issues{CLASS}{$class_id}{TOX_TERM_ID};
		foreach $evid_id (keys %{$Issues{CLASS}{$class_id}{EVID}}) {
			$reason .= "<LI>" . $Issues{CLASS}{$class_id}{EVID}{$evid_id} . "</LI>";
		}
	}
	$reason .= "</UL>";
	if ($tox_issue_flag eq 'T') {
		$reason =~ s/'/\\\"/g;
		print "<TR VALIGN='top'>";
		print "<TD><span class='evid_info' tooltip-data='$reason'><img src='$image_path/RedFlag_25.png'height='26' width='20' /></span></TD>\n";
		print "<TD><A HREF='$link' title = 'Open Ingenuity display of gene in pathway.'>$name</A></TD><TD>";
	}
	elsif ($show_all eq 'T') {
		print "<TR VALIGN='top'><TD>-</TD>\n";	
		print "<TD><A HREF='$link' title = '$desc'>$name</A></TD><TD>";
	}
	else {
		$not_flagged++;	
	}
	print "</TD></TR>\n";
}
if ($show_all ne 'T') {
	print "<TR><TD COLSPAN='3'><I>$not_flagged unflagged terms.</I></TD></TR>\n";
}
print '</TABLE>';

#####################################################################################
#	display Mouse Mutant Phenotypes
#####################################################################################
print "<H2>Mouse Mutant Phenotypes</H2>";
if ($species_common eq 'Mouse') {
	$not_flagged = 0;
	$number_flagged = 0;
	$class_sys = 'Mouse Mutant Phenotypes';
	print '<TABLE border="1"><TR><TH>Flags</TH><TH>Phenotype</TH><TH>Support linking gene to Phenotype</TH></TR>';
	foreach $id_gene_class (@SortClassList) {
		my $tox_issue_flag = 'F';
		if ($ClassHash{$id_gene_class}{SYSTEM} ne $class_sys) { next }
		my $native = $ClassHash{$id_gene_class}{NATIVE};
		my $name = $ClassHash{$id_gene_class}{NAME};
		my $id_class = $ClassHash{$id_gene_class}{CLASS};
		my $link = $MiscLinks{MGI_PHENO_URL} . $native;
		my $reason = "<UL>";
		my $class_id = $ClassHash{$id_gene_class}{CLASS};
		if (defined $Issues{CLASS}{$class_id}) {
			$tox_issue_flag = 'T';
			$number_flagged++;
			my $tti = $Issues{CLASS}{$class_id}{TOX_TERM_ID};
			foreach $evid_id (keys %{$Issues{CLASS}{$class_id}{EVID}}) {
				$reason .= "<LI>" . $Issues{CLASS}{$class_id}{EVID}{$evid_id} . "</LI>";
			}
		}
		$reason .= "</UL>";
		if ($tox_issue_flag eq 'T') {
			$reason =~ s/'/\\\"/g;
			print "<TR VALIGN='top'>";
			print "<TD><span class='evid_info' tooltip-data='$reason'><img src='$image_path/RedFlag_25.png'height='26' width='20' /></span></TD>\n";
		}
		elsif ($show_all eq 'T') {
			print "<TD>-</TD>\n";	
		}
		else {
			$not_flagged++;	
		}
		if (($tox_issue_flag eq 'T') || ($show_all eq 'T')) {
			print "<TD><A HREF='$link' title = '$desc'>$name</A></TD><TD>";
			%Evidence = %{$ClassHash{$id_gene_class}{EVID}};
			foreach $idclass_evid (keys %Evidence) {
				my $type = $Evidence{$idclass_evid}{TYPE};
				my $evidence = $Evidence{$idclass_evid}{EVIDENCE};
				#	DART asked that heterozygote be flagged because these may be more informative
				if ($type eq 'Mouse_Mutant') {
					my ($pubmed, $allele, $strain) = split(/\|\|/, $evidence);
					$pubmed =~ s/PubMed\|//;
					$allele =~ s/Allele\|//;
					$all = "";
					my @Alleles = split(/,/, $allele);
					foreach $genotype (@Alleles) {
						($geno_1, $geno_2) = split(/\//, $genotype);
						if ($geno_1 ne $geno_2) {
							$all .= "|highlight'orange'|$genotype|/highlight|, ";
						}
					}
					$all =~ s/, $//;
					if ($all ne "") { $allele = $all }
					$strain =~ s/Strain\|//;
					my $link = $MiscLinks{PUBMED_URL} . $pubmed;
					$evidence = "$allele &nbsp;&nbsp;&nbsp;&nbsp;&nbsp; $strain";
					$evidence =~ s/\<([^\>]+)\>/<SUP>&lt;$1&gt;<\/SUP>/g;
					$evidence =~ s/\|highlight(\'[^\']+\')\|/<FONT COLOR=$1>/g;
					$evidence =~ s/\|\/highlight\|/<\/FONT>/g;
					$evidence = "$evidence (<A HREF='$link'>$pubmed</A>)";
				}
				else {
					$evidence = make_xml_safe($Evidence{$idclass_evid}{EVIDENCE});
				}
				print "$evidence<BR>";
			}
			print "</TD></TR>\n";
		}
	}
	if ($show_all ne 'T') {
		print "<TR><TD COLSPAN='3'><I>$not_flagged unflagged terms.</I></TD></TR>\n";
	}
	print '</TABLE>';
}
else {
	print "<H3>&nbsp;&nbsp;&nbsp;Please check the ToxReport entry for the Mouse homolog of this gene for potential mutation phenotypes.</H3>\n";
}


#####################################################################################
#	display MESH Medline gene links
#####################################################################################
print "<H2>MESH / Medline Gene Links</H2>\n";
if ($species_common eq 'Human') {
	%SeenBefore = ();
	$class_sys = 'MESH Trees';
	print '<TABLE border="1">';
	print '<TR><TH>Flags</TH><TH>MESH Term</TH><TH>Support linking gene to MESH term</TH></TR>';
	$not_flagged = 0;
	$number_flagged = 0;
	foreach $id_gene_class (@SortClassList) {
		my $tox_issue_flag = 'F';
		if (($ClassHash{$id_gene_class}{SYSTEM} ne $class_sys)) { next }
		my $native = $ClassHash{$id_gene_class}{NATIVE};
		my $name = $ClassHash{$id_gene_class}{NAME};
		if ($SeenBefore{$name} eq 'T') { next }
		my $desc = $ClassHash{$id_gene_class}{DESC};
		my $id_class = $ClassHash{$id_gene_class}{CLASS};
		my $id = $native;
		my $term = $name;
		$term =~ s/\s+/\+/g;
		my $link = $MiscLinks{MESH_SEARCH} . $term;
		my $reason = "<UL>";
		my $class_id = $ClassHash{$id_gene_class}{CLASS};
		if (defined $Issues{CLASS}{$class_id}) {
			$tox_issue_flag = 'T';
			$number_flagged++;
			my $tti = $Issues{CLASS}{$class_id}{TOX_TERM_ID};
			foreach $evid_id (keys %{$Issues{CLASS}{$class_id}{EVID}}) {
				$reason .= "<LI>" . $Issues{CLASS}{$class_id}{EVID}{$evid_id} . "</LI>";
			}
		}
		$reason .= "</UL>";
		if ($tox_issue_flag eq 'T') {
			$reason =~ s/'/\\&quot;/g;
			$reason =~ s/"/\\&quot;/g;
			$reason =~ s/[\n\r\f]+//g;
			print "<TR VALIGN='top'>";
			print "<TD><span class='evid_info' tooltip-data='$reason'><img src='$image_path/RedFlag_25.png'height='26' width='20' /></span></TD>\n";
			print "<TD><A HREF='$link' title = '$desc'>$name</A></TD><TD>";
			$SeenBefore{$name} = 'T';

		}
		elsif ($show_all eq 'T') {
			print "<TR VALIGN='top'><TD>-</TD>\n";	
			print "<TD><A HREF='$link' title = '$desc'>$name</A></TD><TD>";
			$SeenBefore{$name} = 'T';
		}
		else {
			$not_flagged++;	
		}
		%Evidence = %{$ClassHash{$id_gene_class}{EVID}};

		if (($show_all eq 'T') || ($tox_issue_flag eq 'T')) {
			foreach $idclass_evid (keys %Evidence) {
				my $type = $Evidence{$idclass_evid}{TYPE};
				my $title = $GO_Sup_Def{$type};
				my $evidence = $Evidence{$idclass_evid}{EVIDENCE};
				my $link = $MiscLinks{PUBMED_URL} . join(",", @PubmedIDs);
				my $term = $name;
				$term =~ s/\s+/\+/g;
				if ($type =~ /PUBMED_MESH/) {
					$link = $MiscLinks{HOMO_PUBMED_REDIR} . $homolo_id . "&TERM=" . $term;
					$type =~ s/PUBMED_MESH/Check PubMed for latest papers\./;
				}
				elsif ($type =~ /PUBMED_MAJOR_MESH/) {
					$link = $MiscLinks{HOMO_PUBMAJOR_REDIR} . $homolo_id . "&TERM=" . $term;
					$type =~ s/PUBMED_MAJOR_MESH/Check PubMed for latest major MESH papers\./;
				}
				$evidence =~ s/'/"/g;
				print "&nbsp;&nbsp;<A HREF='$link' title='$evidence'>$type</A><BR>";
			}
		print "</TD></TR>\n";
		}
	}
	if ($show_all ne 'T') {
		print "<TR><TD COLSPAN='3'><I>$not_flagged unflagged terms.</I></TD></TR>\n";
	}
	print '</TABLE>';
}
else {
	print "<H3>&nbsp;&nbsp;&nbsp;Please check the ToxReport entry for the Human homolog of this gene for potential literature links.</H3>\n";
}



#####################################################################################
#	display Expression data
#####################################################################################
print "<H2>Expression Data</H2>\n";
print "<H3>Gene Atlas Tissues</H3>\n";
if (($species_common eq 'Human') || ($species_common eq 'Mouse')) {
	if ($species_common eq 'Mouse') { $class_sys = 'Microarray_GeneAtlas_Mouse' }
	else { $class_sys = 'Microarray_GeneAtlas_Human' }
	%SeenBefore = ();
	print '<TABLE border="1">';
	print '<TR><TH>Flags</TH><TH>Tissue</TH><TH>Support linking gene to tissue.</TH></TR>';
	$not_flagged = 0;
	$number_flagged = 0;
	foreach $id_gene_class (@SortClassList) {
		my $tox_issue_flag = 'F';
		if (($ClassHash{$id_gene_class}{SYSTEM} ne $class_sys)) { next }
		my $native = $ClassHash{$id_gene_class}{NATIVE};
		my $name = $ClassHash{$id_gene_class}{NAME};
		if ($SeenBefore{$name} eq 'T') { next }
		my $desc = $ClassHash{$id_gene_class}{DESC};
		my $id_class = $ClassHash{$id_gene_class}{CLASS};
		my $id = $native;
		my $term = $name;
		$term =~ s/\s+/\+/g;
		my $link = $MiscLinks{MESH_SEARCH} . $term;
		my $reason = "<UL>";
		my $class_id = $ClassHash{$id_gene_class}{CLASS};
		if (defined $Issues{CLASS}{$class_id}) {
			$tox_issue_flag = 'T';
			$number_flagged++;
			my $tti = $Issues{CLASS}{$class_id}{TOX_TERM_ID};
			foreach $evid_id (keys %{$Issues{CLASS}{$class_id}{EVID}}) {
				$reason .= "<LI>" . $Issues{CLASS}{$class_id}{EVID}{$evid_id} . "</LI>";
			}
		}
		$reason .= "</UL>";
		if ($tox_issue_flag eq 'T') {
			$reason =~ s/'/\\&quot;/g;
			$reason =~ s/"/\\&quot;/g;
			$reason =~ s/[\n\r\f]+//g;
			print "<TR VALIGN='top'>";
			print "<TD><span class='evid_info' tooltip-data='$reason'><img src='$image_path/RedFlag_25.png'height='26' width='20' /></span></TD>\n";
			print "<TD>$name</TD><TD>";
			$SeenBefore{$name} = 'T';

		}
		elsif ($show_all eq 'T') {
			print "<TR VALIGN='top'><TD>-</TD>\n";	
			print "<TD><A HREF='$link' title = '$desc'>$name</A></TD><TD>";
			$SeenBefore{$name} = 'T';
		}
		else {
			$not_flagged++;	
		}
		%Evidence = %{$ClassHash{$id_gene_class}{EVID}};

		if (($show_all eq 'T') || ($tox_issue_flag eq 'T')) {
			foreach $idclass_evid (keys %Evidence) {
				my $type = $Evidence{$idclass_evid}{TYPE};
				my $evidence = $Evidence{$idclass_evid}{EVIDENCE};
				my $probeset = "";
				if ($evidence =~ /Based on probeset - '([^']+)'/) { $probeset = $1 }
				$evidence =~ s/'/"/g;
				my $link = "";
				if ($species_common eq 'Human') { $link = $MiscLinks{GEO_HUMAN_ATLAS} . $probeset }
				elsif ($species_common eq 'Mouse') { $link = $MiscLinks{GEO_MOUSE_ATLAS} . $probeset }
				print "&nbsp;&nbsp;<A HREF='$link' title='$evidence'>$type</A><BR>";
			}
		print "</TD></TR>\n";
		}
	}
	if ($show_all ne 'T') {
		print "<TR><TD COLSPAN='3'><I>$not_flagged unflagged terms.</I></TD></TR>\n";
	}
	print '</TABLE>';
}



#####################################################################################
#####################################################################################
#	display Homolog data
#####################################################################################
#####################################################################################
print "<HR WIDTH=\"100%\"><BR>\n";
print "<H2>Homolog Information</H2>\n";
my $sql = "SELECT G.entrezID, S.idSpecies, S.commonName,  S.sciName, G.GeneBook_ID, G.idGene"
			. " FROM Gene G, Species S"
			. " WHERE G.idHomolog = '$homologene_id'"
			. " AND S.idSpecies = G.idSpecies";
$statement = $db_handle->prepare($sql);
$statement->execute;
while (@row = $statement->fetchrow_array) {
	my $hom_entrez = $row[0];
	my $hom_species_id = $row[1];
	my $hom_species_common = $row[2];
	my $hom_species_sci = $row[3];
	my $hom_genebook = $row[4];
	my $hom_id_gene = $row[5];
	my $hom_gene_desc = '';
	my $sql_2 = "SELECT Name, Name_Type FROM Names"
					. " WHERE idGene = '$hom_id_gene'"
					. " AND (Name_Type = 'Name' OR Name_Type = 'Symbol')";
	$statement_2 = $db_handle->prepare($sql_2);
	$statement_2->execute;
	while (@row_2 = $statement_2->fetchrow_array) {
		if ($row_2[1] eq 'Symbol') { $hom_gene_desc = $row_2[0] . ' - ' . $hom_gene_desc; }
		else { $hom_gene_desc = $hom_gene_desc . $row_2[0]; }
	}
	if ($hom_species_id == $species_id) { next }
	print "<H3>$hom_species_common</H3>\n";
	print "Entrez: <A HREF='$entrez_link$hom_entrez'>$hom_entrez</A> ($hom_gene_desc)",
			" <A HREF='ToxReport.cgi?TOX_SYS_ID=$tox_sys_id&TOXTERM=$tox_info&ENTREZ=$hom_entrez'>ToxReport</A><BR>\n";
}
$statement_2->finish;

$statement->finish;
$db_handle->disconnect;


print "<BR><BR><HR WIDTH=\"50%\"><BR>For questions or problem contact: <A HREF=\"mailto:$MiscVariables{ADMINISTRATOR_EMAIL}\">$MiscVariables{ADMINISTRATOR_NAME}</A>";
print "<BR><I><FONT SIZE=\"2\">Developed by <A HREF='http://www.linkedin.com/pub/mark-gosink/0/a77/b5b'>Mark Gosink</A>, Investigative Toxicology, DSRD @ Pfizer Inc.</I><BR></FONT>";
print "</DIV>\n";

print end_html();

exit;

sub make_xml_safe {
	my $text = $_[0];
	$text =~ s/\&/&amp;/g;
	$text =~ s/\>/&gt;/g;
	$text =~ s/\</&lt;/g;
	$text =~ s/\"/&quot;/g;
	return $text;
}

sub find_child_tox_terms {
	my $parent_id = $_[0];
	my $sql = "SELECT TT.idToxTerm, TT.Tox_Term, TT.Tox_Desc FROM"
				. " ToxTerm TT, ToxParent TP"
				. " WHERE TP.Parent_idToxTerm = '$parent_id'"
				. " AND TT.idToxTerm = TP.Child_idToxTerm";
	my $statement = $db_handle->prepare($sql);
	$statement->execute;
	while (my @row = $statement->fetchrow_array) {
		$AllTermIDs{$row[0]}{TERM} = $row[1];
		$AllTermIDs{$row[0]}{TERMDESC} = $row[2];
		find_child_tox_terms($row[0]);
	}
}

sub find_tox_term_issues {
	my $all_ids = join(', ', keys(%AllTermIDs));
	my %PreviouslySeenEvidence = ();		#	this is a hack to correct multiple evidence link need to figure out how to clean up

	my @All_IDs = keys(%AllTermIDs);
	my $num_ids = $#All_IDs;
	$sql = "";
	for ($idx = 0; $idx <= $num_ids; $idx += 900) {
		my $start_idx = $idx;
		my $end_idx = $idx + 899;
		if ($end_idx > $num_ids) { $end_idx = $num_ids }
		if ($start_idx == 0) {
		$sql = "SELECT TL.idToxTerm, TL.idToxLink, TL.Gene_idGene, TL.Xref_idXref, TL.Class_idClass,"
				. " TLE.idToxLink_Evid, TLE.Tox_Evidence"
				. " FROM ToxLink TL, ToxLink_Evid TLE"
				. " WHERE TL.idToxTerm IN (" . join(", ", @All_IDs[$start_idx..$end_idx]) . ")"
				. " AND TL.idToxLink = TLE.idToxLink";
		}
		else {
		$sql .= " UNION SELECT TL.idToxTerm, TL.idToxLink, TL.Gene_idGene, TL.Xref_idXref, TL.Class_idClass,"
				. " TLE.idToxLink_Evid, TLE.Tox_Evidence"
				. " FROM ToxLink TL, ToxLink_Evid TLE"
				. " WHERE TL.idToxTerm IN (" . join(", ", @All_IDs[$start_idx..$end_idx]) . ")"
				. " AND TL.idToxLink = TLE.idToxLink";
		}
	}

	$statement = $db_handle->prepare($sql);
	$statement->execute;
	while (@row = $statement->fetchrow_array) {
		if ($row[2]) {
			if ($PreviouslySeenEvidence{$row[6]} eq 'T') { next }
			$Issues{GENE}{$row[2]}{TOX_TERM_ID} = $row[0];
			$Issues{GENE}{$row[2]}{TOX_LINK_ID} = $row[1];
			$Issues{GENE}{$row[2]}{EVID}{$row[5]} = $row[6];
			$PreviouslySeenEvidence{$row[6]} = 'T';
		}
		elsif ($row[3]) {
			if ($PreviouslySeenEvidence{$row[6]} eq 'T') { next }
			$Issues{XREF}{$row[3]}{TOX_TERM_ID} = $row[0];
			$Issues{XREF}{$row[3]}{TOX_LINK_ID} = $row[1];
			$Issues{XREF}{$row[3]}{EVID}{$row[5]} = $row[6];
			$PreviouslySeenEvidence{$row[6]} = 'T';
		}
		elsif ($row[4]) {
			if ($PreviouslySeenEvidence{$row[6]} eq 'T') { next }
			$Issues{CLASS}{$row[4]}{TOX_TERM_ID} = $row[0];
			$Issues{CLASS}{$row[4]}{TOX_LINK_ID} = $row[1];
			$Issues{CLASS}{$row[4]}{EVID}{$row[5]} = $row[6];
			$PreviouslySeenEvidence{$row[6]} = 'T';
		}
	}
}

sub find_tox_term_issues_by_type {
	my $type = $_[0];
	my $id_list = $_[1];
	my $all_ids = join(', ', keys(%AllTermIDs));
	my %PreviouslySeenEvidence = ();		#	this is a hack to correct multiple evidence link need to figure out how to clean up


	my @All_IDs = split(/, /, $id_list);
	my $num_ids = $#All_IDs;
	$sql = "";
	for ($idx = 0; $idx <= $num_ids; $idx += 900) {
		my $start_idx = $idx;
		my $end_idx = $idx + 899;
		if ($end_idx > $num_ids) { $end_idx = $num_ids }
		if ($start_idx == 0) {
			$sql = "SELECT TL.idToxTerm, TL.idToxLink, TL.Gene_idGene, TL.Xref_idXref, TL.Class_idClass,"
						. " TLE.idToxLink_Evid, TLE.Tox_Evidence"
						. " FROM ToxLink TL, ToxLink_Evid TLE"
						. " WHERE TL.idToxTerm IN ($all_ids)"
						. " AND TL.idToxLink = TLE.idToxLink";
			if ($type eq 'XREF') { $sql .= " AND TL.Xref_idXref in (" . join(", ", @All_IDs[$start_idx..$end_idx]) . ")" }
			elsif ($type eq 'CLASS') { $sql .= " AND TL.Class_idClass in (" . join(", ", @All_IDs[$start_idx..$end_idx]) . ")" }
			elsif ($type eq 'GENE') { $sql .= " AND TL.Gene_idGene in (" . join(", ", @All_IDs[$start_idx..$end_idx]) . ")" }
		}
		else {
			$sql .= " UNION SELECT TL.idToxTerm, TL.idToxLink, TL.Gene_idGene, TL.Xref_idXref, TL.Class_idClass,"
						. " TLE.idToxLink_Evid, TLE.Tox_Evidence"
						. " FROM ToxLink TL, ToxLink_Evid TLE"
						. " WHERE TL.idToxTerm IN ($all_ids)"
						. " AND TL.idToxLink = TLE.idToxLink";
			if ($type eq 'XREF') { $sql .= " AND TL.Xref_idXref in (" . join(", ", @All_IDs[$start_idx..$end_idx]) . ")" }
			elsif ($type eq 'CLASS') { $sql .= " AND TL.Class_idClass in (" . join(", ", @All_IDs[$start_idx..$end_idx]) . ")" }
			elsif ($type eq 'GENE') { $sql .= " AND TL.Gene_idGene in (" . join(", ", @All_IDs[$start_idx..$end_idx]) . ")" }
		}
	}

	$statement = $db_handle->prepare($sql);
	$statement->execute;
	while (@row = $statement->fetchrow_array) {
		if ($row[2]) {
			if ($PreviouslySeenEvidence{$row[6]} eq 'T') { next }
			$Issues{GENE}{$row[2]}{TOX_TERM_ID} = $row[0];
			$Issues{GENE}{$row[2]}{TOX_LINK_ID} = $row[1];
			$Issues{GENE}{$row[2]}{EVID}{$row[5]} = $row[6];
			$PreviouslySeenEvidence{$row[6]} = 'T';
		}
		elsif ($row[3]) {
			if ($PreviouslySeenEvidence{$row[6]} eq 'T') { next }
			$Issues{XREF}{$row[3]}{TOX_TERM_ID} = $row[0];
			$Issues{XREF}{$row[3]}{TOX_LINK_ID} = $row[1];
			$Issues{XREF}{$row[3]}{EVID}{$row[5]} = $row[6];
			$PreviouslySeenEvidence{$row[6]} = 'T';
		}
		elsif ($row[4]) {
			if ($PreviouslySeenEvidence{$row[6]} eq 'T') { next }
			$Issues{CLASS}{$row[4]}{TOX_TERM_ID} = $row[0];
			$Issues{CLASS}{$row[4]}{TOX_LINK_ID} = $row[1];
			$Issues{CLASS}{$row[4]}{EVID}{$row[5]} = $row[6];
			$PreviouslySeenEvidence{$row[6]} = 'T';
		}
	}
}

sub by_xref_source { return $Xrefs{$a}{SOURCE} cmp $Xrefs{$b}{SOURCE} }
