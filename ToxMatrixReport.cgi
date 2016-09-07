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

use GD;

use DBI;

$as_bioservice = param(BIOSERV_XML);

$image_path = $MiscVariables{IMAGE_PATH};
$dsrd_link = $MiscLinks{DSRD_HOME};

if (not $as_bioservice) {

print header();

print start_html(-title=>"ToxReporter: Matrix Search",
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

# vvvvvvvvvvvv Log the use of this application vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
#	Log the use of this application
eval {
	my $add = $ENV{HTTP_X_FORWARDED_FOR}?$ENV{HTTP_X_FORWARDED_FOR}:$ENV{REMOTE_ADDR};
	`/cssi/data/neusentis_data1/cgi/comptoxdev.pfizer.com/TOOLS/Log_Use $add $0`;
#	print " $add $0<BR>\n";
};
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

print<<MENU;
<table class="header">
  <tr>
    <td class="header_1">
      <a href="$dsrd_link"><img border="0" height=74px width=170px src="$image_path/DSRD.jpg" ALT="Drug Safety Research & Development"></a>
    </td>
    <td class="header_2">
      <div class="header">
        <i><font color="blue">T</font>ox<font color="blue">M</font>atrix <font color="orangered">R</font>eport</i><BR>
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
    <td class="menu_current">
      <A class="menu_current" href="ToxMatrixReport.cgi"><span  class='help_info' tooltip-data='$ToolTips{ToxMatrix_But}'>ToxMatrix Genes:</span></A>
    </td>
  </tr>
</table>
MENU

print '<DIV class="body_indent">';
}
else { print header(-type=>'text/xml') }

$gene_id_list = join("\t", param(GENELIST));
$list_type = param(ID_TYPE);
if ($gene_id_list eq "") {		#	if a genelist hasn't been submitted, display the form
	print start_form();

	print "<TABLE>\n";
	print "<TR><TD VALIGN=TOP ALIGN=RIGHT>Enter a list of gene identifiers to matrix:</TD>",
			"<TD><TEXTAREA NAME='GENELIST' ROWS='8' COLS='50'>$gene_list</TEXTAREA></TD></TR>\n",
			"<TR><TD VALIGN=TOP ALIGN=RIGHT>Type of ID's being used:</TD>",
			"<TD><INPUT TYPE='RADIO' NAME='ID_TYPE' VALUE='ENTREZ' CHECKED>Entrez ID's</INPUT>",
# The following line can be uncommented and modified to search internal gene identifiers
#"<INPUT TYPE='RADIO' NAME='ID_TYPE' VALUE='GENEBOOK'>Genebook ID's</INPUT>",
			"</TD></TR>";
	print "</TABLE>\n";
	
	print submit('Search');
	print end_form();
}
else {
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

	my @SubmittedEntrez_IDs = ();
	if ($list_type eq 'GENEBOOK') {
		$gene_id_list =~ s/^\W+//;
		$gene_id_list =~ s/\W+$//;
		my @Genebooks = split(/\W+/, $gene_id_list);
		my $genebooks = '"' . join('", "', @Genebooks) . '"';
		my %GeneHash = ();
		my $sql = "SELECT entrezID FROM Gene WHERE GeneBook_ID IN ($genebooks)";
		$statement = $db_handle->prepare($sql);
		$statement->execute;
		while (@row = $statement->fetchrow_array) { $GeneHash{$row[0]} = 'T' }
		@SubmittedEntrez_IDs = keys(%GeneHash);
	}
	else {
		$gene_id_list =~ s/^[^\d]+//;
		$gene_id_list =~ s/[^\d]+$//;
		@SubmittedEntrez_IDs = split(/[^\d]+/, $gene_id_list);
	}
	
	%Submitted2Homolog = ();
	%AllHomologs = ();
	my $genes = join(', ', @SubmittedEntrez_IDs);
	my $sql = "SELECT entrezID, idHomolog from Gene WHERE entrezID in ($genes)";
	$statement = $db_handle->prepare($sql);
	$statement->execute;
	$no_homo_id = -1;
	while (@row = $statement->fetchrow_array) {
		my $submitted_id = $row[0];
		my $homolog_id = $row[1];
		if ($homolog_id ne ''){
			$Submitted2Homolog{$submitted_id} = $homolog_id;
			$AllHomologs{$homolog_id}{HUMAN} = 'empty';
		}
		else {
			$Submitted2Homolog{$submitted_id} = $no_homo_id;
			$AllHomologs{$no_homo_id}{HUMAN} = 'empty';
			$no_homo_id--;
		}
	}
	my $homologs = join(', ', keys(%AllHomologs));
	my $sql = "SELECT G.idHomolog, G.entrezID, S.commonName"
				. " from Gene G, Species S"
				. " WHERE G.idHomolog in ($homologs)"
				. " AND G.idSpecies = S.idSpecies"
				. " AND (S.commonName = 'Human' OR S.commonName = 'Mouse')";
	$statement = $db_handle->prepare($sql);
	$statement->execute;
	%AllGenes = ();
	while (@row = $statement->fetchrow_array) {
		my $homolog_id = $row[0];
		my $gene = $row[1];
		my $species = $row[2];
		$AllGenes{$gene} = 'T';
		if ($species eq 'Human') {
			$AllHomologs{$homolog_id}{HUMAN} = $gene;
		}
		elsif ($species eq 'Mouse') {
			$AllHomologs{$homolog_id}{MOUSE} = $gene;
		}
	}
	@Entrez_IDs = keys(%AllGenes);
	
	my $genes = join(', ', @Entrez_IDs);
	my $sql = "SELECT G.entrezID, N.Name"
				. " FROM Names N, Gene G"
				. " WHERE G.entrezID in ($genes)"
				. " AND N.Name_Type = 'Symbol'"
				. " AND N.idGene = G.idGene";
	$statement = $db_handle->prepare($sql);
	$statement->execute;
	%Entrex_2_Info = ();
	while (@row = $statement->fetchrow_array) { $Entrex_2_Info{$row[0]}{SYMBOL} = $row[1] }
	my $sql = "SELECT A.Annot_Text, G.idGene, G.entrezID, G.GeneBook_ID"
				. " FROM Annotation A, Gene G"
				. " WHERE A.Annot_Link = 'TOX_AT_GLANCE'"
				. " AND A.idGene = G.idGene"
				. " AND G.entrezID in ($genes)";
	$statement = $db_handle->prepare($sql);
	$statement->execute;
	%Gene_2_Tox = ();
	while (@row = $statement->fetchrow_array) {
		my $tox_percentiles = $row[0];
		my $gene_id = $row[1];
		my $entrez_id = $row[2];
		my $genebook_id = $row[3];
		if ($entrez_id ne '') {
			$Entrex_2_Info{$entrez_id}{ID_GENE} = $gene_id;
			$Entrex_2_Info{$entrez_id}{GENEBOOK} = $genebook_id;
			$tox_percentiles =~ s/^\|\|//;
			my @ValuePairs = split(/\|\|/, $tox_percentiles);
			foreach $val_pair (@ValuePairs) {
				my ($tox_term, $percentile) = split(/\:/, $val_pair);
				$Gene_2_Tox{$entrez_id}{$tox_term} = $percentile;
			}
		}
	}
	$statement->finish;
	$db_handle->disconnect;

	if (not $as_bioservice) {
		print "<TABLE BORDER=1>\n";
		print "<TR>";
		print "<TH ALIGN='center' VALIGN='bottom'>HUMAN GENE</TH>";
		foreach $tox_term (@ToxCategories) {
			my $heading = $tox_term;
			print "<TH ALIGN='center' VALIGN='bottom' WIDTH=30>";
			$heading =~ s/_System//i;
			$heading =~ s/_toxicity//i;
			my @Letters = split(//, $heading);
			foreach $letter (@Letters) { print uc($letter), "<BR>" }
			print "</TH>";
		}
		print "<TH ALIGN='center' VALIGN='bottom'>MOUSE GENE</TH>";
		foreach $tox_term (@ToxCategories) {
			my $heading = $tox_term;
			print "<TH ALIGN='center' VALIGN='bottom' WIDTH=30>";
			$heading =~ s/_System//i;
			$heading =~ s/_toxicity//i;
			my @Letters = split(//, $heading);
			foreach $letter (@Letters) { print uc($letter), "<BR>" }
			print "</TH>";
		}
		print "</TR>\n";

		%SeenList = ();
		@SortedGeneList = sort by_symbol (@SubmittedEntrez_IDs);
		foreach $gene (@SortedGeneList) {
			my $entrez_id = $AllHomologs{$Submitted2Homolog{$gene}}{HUMAN};
			my $symbol = $Entrex_2_Info{$entrez_id}{SYMBOL};
			my $gene_id = $Entrex_2_Info{$entrez_id}{ID_GENE};
			my $gene_book = $Entrex_2_Info{$entrez_id}{GENEBOOK};
			my $base_link = $MiscLinks{TOXREPORTBASELINK} . $entrez_id . ';TOXTERM=';
#			if (($entrez_id eq '') || ($entrez_id eq 'empty') || ($SeenList{$entrez_id} eq 'T') || ($SeenList{$gene_book} eq 'T')) { next }
			if (($entrez_id eq '') || ($entrez_id eq 'empty') || ($SeenList{$entrez_id} eq 'T')) { next }

			print "<TR>";
			print "<TD ALIGN='center'><B>$symbol / $gene_book</B> - $entrez_id</TD>";
			foreach $tox_term (@ToxCategories) {
				my $link = $base_link . $IssueCatagories{"$tox_term"};
				my $percentile = $Gene_2_Tox{$entrez_id}{$tox_term};
				$percentile = sprintf "%.4f", $percentile;
				my $desc = "Red flag count for $symbol falls in the normalized " . ($percentile*100) . "th percentile in $tox_term risk links.";
				if ($percentile >= 0.90) { $color = '#FF0000' }
				elsif ($percentile >= 0.50) { $color = 'orange' }
				elsif ($percentile == 0.00) {
					$color = 'lightgreen';
					$desc .= " Note: Zero percentile does not mean no risk."
				}
				else { $color = 'yellow' }
				print "<TD BGCOLOR='$color' ALIGN='center'><span  class='help_info' tooltip-data='$desc'><A HREF='$link'>$percentile</A></span></TD>";
			}
			$SeenList{$entrez_id} = 'T';
			$SeenList{$gene_book} = 'T';

			my $entrez_id = $AllHomologs{$Submitted2Homolog{$gene}}{MOUSE};
			my $symbol = $Entrex_2_Info{$entrez_id}{SYMBOL};
			my $gene_id = $Entrex_2_Info{$entrez_id}{ID_GENE};
			my $gene_book = $Entrex_2_Info{$entrez_id}{GENEBOOK};
			my $base_link = $MiscLinks{TOXREPORTBASELINK} . $entrez_id . ';TOXTERM=';
			$SeenList{$entrez_id} = 'T';
			$SeenList{$gene_book} = 'T';
			print "<TD ALIGN='center'><B>$symbol / $gene_book</B> - $entrez_id</TD>";
			foreach $tox_term (@ToxCategories) {
				my $link = $base_link . $IssueCatagories{$tox_term};
				my $percentile = $Gene_2_Tox{$entrez_id}{$tox_term};
				$percentile = sprintf "%.4f", $percentile;
				my $desc = "Red flag count for $symbol falls in the normalized " . ($percentile*100) . "th percentile in $tox_term risk links.";
				if ($percentile >= 0.90) { $color = '#FF0000' }
				elsif ($percentile >= 0.75) { $color = 'orange' }
				elsif ($percentile == 0.00) {
					$color = 'lightgreen';
					$desc .= " Note: Zero percentile does not mean no risk."
				}
				else { $color = 'yellow' }
				print "<TD BGCOLOR='$color' ALIGN='center'><span  class='help_info' tooltip-data='$desc'><A HREF='$link'>$percentile</A></span></TD>";
			}
			print "</TR>\n";
			$SeenList{$entrez_id} = 'T';
			$SeenList{$gene_book} = 'T';
		}
		print "</TABLE>\n";
	}
	else {
		@SortedGeneList = sort by_symbol (@SubmittedEntrez_IDs);
		my $row_count = $#SortedGeneList + 1;
		print "<ROWSET row_count='$row_count'>\n";
		for ($rox_idx = 0; $rox_idx < $row_count; $rox_idx++) {
			my $gene = $SubmittedEntrez_IDs[$rox_idx];
			my $entrez_id = $AllHomologs{$Submitted2Homolog{$gene}}{HUMAN};
			my $symbol = $Entrex_2_Info{$entrez_id}{SYMBOL};
			my $gene_id = $Entrex_2_Info{$entrez_id}{ID_GENE};
			my $gene_book = $Entrex_2_Info{$entrez_id}{GENEBOOK};
			my $num = $rox_idx + 1;
			print "<ROW num='$num'>\n";
			print "<Gene_Symbol>$symbol</Gene_Symbol>\n";
			print "<Entrez_ID>$entrez_id</Entrez_ID>\n";
			print "<GeneBook_ID>$gene_book</GeneBook_ID>\n";
			my $base_link = $MiscLinks{TOXREPORTBASELINK2} . $entrez_id . ';TOXTERM=';
			foreach $tox_term (@ToxCategories) {
				my $link = $base_link . $IssueCatagories{$tox_term};
				my $tag = $tox_term . '_URL';
				my $percentile = $Gene_2_Tox{$entrez_id}{$tox_term};
				$percentile = sprintf "%.4f", $percentile;
				print "<$tox_term>$percentile</$tox_term>\n";
				print "<$tag>$link</$tag>\n";
			}
			print "</ROW>\n";
		}
		print "</ROWSET>\n";
	}
}

if (not $as_bioservice) {	
	print "<BR><BR><HR WIDTH=\"50%\"><BR>For questions or problem contact: <A HREF=\"mailto:$MiscVariables{ADMINISTRATOR_EMAIL}\">$MiscVariables{ADMINISTRATOR_NAME}</A>";
	print "<BR><I><FONT SIZE=\"2\">Developed by <A HREF='http://www.linkedin.com/pub/mark-gosink/0/a77/b5b'>Mark Gosink</A>, Investigative Toxicology, DSRD @ Pfizer Inc.</I><BR></FONT>";
	print "</DIV>\n";

	print end_html();
}
exit;

sub by_symbol {
	$Entrex_2_Info{$a}{SYMBOL} cmp $Entrex_2_Info{$b}{SYMBOL}
}

