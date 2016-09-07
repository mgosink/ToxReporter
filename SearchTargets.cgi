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

print header();

$image_path = $MiscVariables{IMAGE_PATH};
$dsrd_link = $MiscLinks{DSRD_HOME};

print start_html(-title=>"ToxReporter: Gene Search",
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

$term = param(TERM);
#	remove leading and trailing spaces
$term =~ s/^\s+//;
$term =~ s/\s+$//;
$tox_sys_id = param(TOX_SYS_ID);
$tox_sys_name = param(TOX_SYS_NAME);
$tox_term = param(TOXTERM);

($tox_name, undef, undef) = split(/\|/, $tox_term);

print<<MENU;
<table class="header">
  <tr>
    <td class="header_1">
      <a href="$dsrd_link"><img border="0" height=74px width=170px src="$image_path/DSRD.jpg" ALT="Drug Safety Research & Development"></a>
    </td>
    <td class="header_2">
      <div class="header">
        <i><font color="blue">T</font>ox<font color="blue">G</font>ene <font color="orangered">S</font>earch</i><BR>
           $tox_system_name 
      </div>
    </td>
  </tr>
</table>

<table class="menu_table">
  <tr>
    <td class="menu">
      <A class="menu" href="ViewToxicities.cgi"><span  class='help_info' tooltip-data='$ToolTips{ToxIssues_But}'>Search Tox Issues:</span></A>
    </td>
  </tr>
  <tr>
    <td class="menu">
      <A class="menu" href="ToxMatrixReport.cgi"><span  class='help_info' tooltip-data='$ToolTips{ToxMatrix_But}'>ToxMatrix Genes:</span></A>
    </td>
  </tr>
</table>
MENU

print "<div id='loading'>\n";
print "   <div id='content'></div>\n";
print "</div>\n";

print '<DIV class="body_indent">';

# vvvvvvvvvvvv Log the use of this application vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
#	Log the use of this application
eval {
	my $add = $ENV{HTTP_X_FORWARDED_FOR}?$ENV{HTTP_X_FORWARDED_FOR}:$ENV{REMOTE_ADDR};
	`/cssi/data/neusentis_data1/cgi/comptoxdev.pfizer.com/TOOLS/Log_Use $add $0`;
#	print " $add $0<BR>\n";
};
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

if (($tox_name ne "") && ($tox_sys_name ne "")) {
	print h2("<I>$tox_name</I> <FONT SIZE='-1'>(from '$tox_sys_name')</FONT> issues will be flagged.<br>\n");
}
else {
	print h2("<I>Warning!</I> No toxicity issues have be flagged.<br>\n");
}

if ($term eq "") {
# The following line can be uncommented and modified to search internal gene identifiers
#	print "<I>For the most dependable search results, please use the Genebook ID, NCBI Gene ID or the official HUGO symbol.<BR>\n";
	print "<I>For the most dependable search results, please use the NCBI Gene ID or the official HUGO symbol.<BR>\n";
# The following line can be uncommented and modified to search internal gene identifiers
#	print "Genebook IDs available from <A HREF='$MiscLinks{TARGETPEDIA}'>TargetPedia</A><BR>\n";
	print "Entrez IDs & HUGO symbols available from <A HREF='$MiscLinks{NCBI_GENE}'>Entrez Gene</A></I><BR>\n";
	print start_form();
	print "<input type='hidden' name='TOX_SYS_ID' value='$tox_sys_id'></input>\n";
	print "<input type='hidden' name='TOX_SYS_NAME' value='$tox_sys_name'></input>\n";
	print "<input type='hidden' name='TOXTERM' value='$tox_term'></input>\n";
	print "<table>\n";
	print "<tr><td>Search for gene name, alias or ID:</td><td><input type='text' name='TERM' size=40></input></td></tr>\n";
	print "</table>\n";
	print submit('Search');
	print end_form();
}
else {
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
	$username = $MiscVariables{TOXGENE_USER};
	$password = $MiscVariables{TOXGENE_PSWD};
	$db_handle = DBI->connect( $dsn, $username, $password, { PrintError => 1 })
						or die "Can't connect to the database!!\n\n";

# The following line can be uncommented and modified to search internal gene identifiers
#	print "Searching Entrez IDs and GeneBook IDs ...<BR>\n<UL>\n";
	print "Searching Entrez IDs ...<BR>\n<UL>\n";
	my $sql = "SELECT G.entrezID, S.idSpecies, S.commonName,  S.sciName, G.GeneBook_ID, G.idGene"
				. " FROM Gene G, Species S"
				. " WHERE S.idSpecies = G.idSpecies"
				. " AND ( G.entrezID = '$term'"
				. " OR G.GeneBook_ID = '$term' )";
	$statement = $db_handle->prepare($sql);
	$statement->execute;
	$found_something = 'F';
	
	print start_form(-action=>"ToxMatrixReport.cgi", -method=>'POST');

	while (@row = $statement->fetchrow_array) {
		$entrez = $row[0];
		$species_id = $row[1];
		$species_common = $row[2];
		$species_sci = $row[3];
		$genebook = $row[4];
		$id_gene = $row[5];

		my $sql_2 = "SELECT idNames, Name, Name_Type"
					. " FROM Names"
					. " WHERE idGene = '$id_gene'";
		my $statement_2 = $db_handle->prepare($sql_2);
		$statement_2->execute;
		my %Names = ();
		$fullname = $symbol = "";
		while(@row_2 = $statement_2->fetchrow_array) {
			$Names{$row_2[0]}{NAME} = $row_2[1];
			$Names{$row_2[0]}{TYPE} = $row_2[2];
			if ($row_2[2] eq "Name") {
				$fullname = $row_2[1];
			}
			if ($row_2[2] eq "Symbol") {
				$symbol = $row_2[1];
			}
		}
		$statement_2->finish;
		$found_something = 'T';
		print "<LI><span  class='help_info' tooltip-data='$ToolTips{Matrix_or_Individ}'><input type='checkbox' name='GENELIST' value='$entrez' CHECKED>",
# The following line can be uncommented and modified to search internal gene identifiers
#						"<A HREF='ToxReport.cgi?TOX_SYS_ID=$tox_sys_id&TOXTERM=$tox_term&ENTREZ=$entrez'>$entrez / $genebook</A> $symbol - $fullname ($species_common)</span></LI>\n";
						"<A HREF='ToxReport.cgi?TOX_SYS_ID=$tox_sys_id&TOXTERM=$tox_term&ENTREZ=$entrez'>$entrez </A> $symbol - $fullname ($species_common)</span></LI>\n";
	}
	print "</UL>\n";

	print "Searching other names ...<BR>\n<UL>\n";
	my $sql = "SELECT G.entrezID, S.idSpecies, S.commonName,  S.sciName, G.GeneBook_ID, G.idGene, N.Name"
				. " FROM Gene G, Species S, Names N"
				. " WHERE S.idSpecies = G.idSpecies"
				. " AND N.idGene = G.idGene"
				. " AND UPPER(N.Name) LIKE UPPER('%$term%')";
	$statement = $db_handle->prepare($sql);
	$statement->execute;
	$found_something = 'F';
	%SeenBefore = ();
	while (@row = $statement->fetchrow_array) {
		$entrez = $row[0];
		$species_id = $row[1];
		$species_common = $row[2];
		$species_sci = $row[3];
		$genebook = $row[4];
		$id_gene = $row[5];
		$name = $row[6];
		
		if ($SeenBefore{$id_gene} eq 'T') { next }
		$SeenBefore{$id_gene} = 'T';

		my $sql_2 = "SELECT idNames, Name, Name_Type"
					. " FROM Names"
					. " WHERE idGene = '$id_gene'";
		my $statement_2 = $db_handle->prepare($sql_2);
		$statement_2->execute;
		my %Names = ();
		$fullname = $symbol = "";
		while(@row_2 = $statement_2->fetchrow_array) {
			$Names{$row_2[0]}{NAME} = $row_2[1];
			$Names{$row_2[0]}{TYPE} = $row_2[2];
			if ($row_2[2] eq "Name") {
				$fullname = $row_2[1];
			}
			if ($row_2[2] eq "Symbol") {
				$symbol = $row_2[1];
			}
		}
		$statement_2->finish;
		$found_something = 'T';
		if ($symbol =~ /$term/) {
			$symbol =~ s/($term)/<FONT COLOR='red'>$1<\/FONT>/ig;
			print "<LI><span  class='help_info' tooltip-data='$ToolTips{Matrix_or_Individ}'><input type='checkbox' name='GENELIST' value='$entrez' CHECKED>",
# The following line can be uncommented and modified to search internal gene identifiers
#						"<A HREF='ToxReport.cgi?TOX_SYS_ID=$tox_sys_id&TOXTERM=$tox_term&ENTREZ=$entrez'>$entrez / $genebook</A> $symbol - $fullname ($species_common)</span></LI>\n";
						"<A HREF='ToxReport.cgi?TOX_SYS_ID=$tox_sys_id&TOXTERM=$tox_term&ENTREZ=$entrez'>$entrez</A> $symbol - $fullname ($species_common)</span></LI>\n";
		}
		elsif ($fullname =~ /$term/) {
			$fullname =~ s/($term)/<FONT COLOR='red'>$1<\/FONT>/ig;
			print "<LI><span  class='help_info' tooltip-data='$ToolTips{Matrix_or_Individ}'><input type='checkbox' name='GENELIST' value='$entrez' CHECKED>",
# The following line can be uncommented and modified to search internal gene identifiers
#						"<A HREF='ToxReport.cgi?TOX_SYS_ID=$tox_sys_id&TOXTERM=$tox_term&ENTREZ=$entrez'>$entrez / $genebook</A> $symbol - $fullname ($species_common)</LI>\n";
						"<A HREF='ToxReport.cgi?TOX_SYS_ID=$tox_sys_id&TOXTERM=$tox_term&ENTREZ=$entrez'>$entrez</A> $symbol - $fullname ($species_common)</LI>\n";
		}
		else {
			$name =~ s/($term)/<FONT COLOR='red'>$1<\/FONT>/ig;
			print "<LI><span  class='help_info' tooltip-data='$ToolTips{Matrix_or_Individ}'><input type='checkbox' name='GENELIST' value='$entrez' CHECKED>",
# The following line can be uncommented and modified to search internal gene identifiers
#						"<A HREF='ToxReport.cgi?TOX_SYS_ID=$tox_sys_id&TOXTERM=$tox_term&ENTREZ=$entrez'>$entrez / $genebook</A> $symbol - $fullname ($species_common)<BR>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;$name</LI>\n";
						"<A HREF='ToxReport.cgi?TOX_SYS_ID=$tox_sys_id&TOXTERM=$tox_term&ENTREZ=$entrez'>$entrez</A> $symbol - $fullname ($species_common)<BR>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;$name</LI>\n";
		}
	}
	print "</UL>\n";

	$statement->finish;
	$db_handle->disconnect;

	print "<input type='hidden' name='ID_TYPE' value='ENTREZ'></input>\n";
	print "<span class='help_info' tooltip-data='$ToolTips{SearchMatrix_But}'><input type='submit' value='Matrix search selected genes'></span>\n";

	print end_form();
}

print "<BR><BR><HR WIDTH=\"50%\"><BR>For questions or problem contact: <A HREF=\"mailto:$MiscVariables{ADMINISTRATOR_EMAIL}\">$MiscVariables{ADMINISTRATOR_NAME}</A>";
print "<BR><I><FONT SIZE=\"2\">Developed by <A HREF='http://www.linkedin.com/pub/mark-gosink/0/a77/b5b'>Mark Gosink</A>, Investigative Toxicology, DSRD @ Pfizer Inc.</I><BR></FONT>";
print '</DIV>';

print end_html();

exit;

sub make_sql_safe {
	my $term = $_[0];
	$term =~ s/\\/\\\\/g;
	$term =~ s/'/\\'/g;
	$term =~ s/"/\\"/g;
	return $term;
}

sub make_xml_safe {
	my $text = $_[0];
	$text =~ s/\&/&amp;/g;
	$text =~ s/\>/&gt;/g;
	$text =~ s/\</&lt;/g;
	$text =~ s/\"/&quot;/g;
	return $text;
}
