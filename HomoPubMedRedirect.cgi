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
use LWP::Simple qw(!head);

print header();

$image_path = $MiscVariables{IMAGE_PATH};

print start_html(-title=>"ToxReporter: Homolog PubMed Lookup Tool",
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

# vvvvvvvvvvvv Log the use of this application vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
#	Log the use of this application
eval {
	my $add = $ENV{HTTP_X_FORWARDED_FOR}?$ENV{HTTP_X_FORWARDED_FOR}:$ENV{REMOTE_ADDR};
	`/cssi/data/neusentis_data1/cgi/comptoxdev.pfizer.com/TOOLS/Log_Use $add $0`;
#	print " $add $0<BR>\n";
};
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

$debug_code = param(DEBUG);

print<<MENU;
<table class="header">
  <tr>
    <td class="header_1">
      <a href="$dsrd_link"><img border="0" height=74px width=170px src="$image_path/DSRD.jpg" ALT="Drug Safety Research & Development"></a>
    </td>
    <td class="header_2">
      <div class="header">
        <i><font color="blue">T</font>ox<font color="blue">G</font>ene <font color="orangered">R</font>eport</i><BR>
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

print '<DIV class="body_indent">';
$term = param(TERM);
$term =~ s/\s+/\+/g;

$term_type = param(TERMTYPE);
if ($term_type eq "MAJOR") { $term_type = '[major]' }
elsif ($term_type eq "TITLE") { $term_type = '[title]' }
else {$term_type = '[mesh]' }

$homologene_id = param(HOMOLOG);

print h3("Searching PubMed for literature pretaining to Homologene ID: $homologene_id with MESH term '$term'");

if (($homologene_id =~ /^\d+$/) && ($term ne "")) {
	my %PubMedIDs = ();
	
	$url = 'http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?'
			. 'db=homologene'
			. '&usehistory=y'
			. '&term=' .$homologene_id;
if ($debug_code =~ /1/){print "Fetching URL 1 - $url<br>\n";}
	$result = get($url);
	my $web_env = $query_key = "";
	my @ResultLines = split(/\n/, $result);
	foreach $line (@ResultLines) {
		if ($line =~ /<WebEnv>([^<]+)<\/WebEnv>/) { $web_env = $1 }
		if ($line =~ /<QueryKey>([^<]+)<\/QueryKey>/) { $query_key = $1 }
	}
	if (($query_key eq "") || ($web_env eq "")) { die "FAILED" }
	
	#	Elink from Homologene to genes
	$url = 'http://eutils.ncbi.nlm.nih.gov/entrez/eutils/elink.fcgi?'
			. 'db=gene'
			. '&dbfrom=homologene'
			. '&WebEnv=' . $web_env
			. '&query_key=' . $query_key
			. '&cmd=neighbor_history';
if ($debug_code =~ /2/){print "Fetching URL 2 - $url<br>\n";}
	$result = get($url);
	my $web_env = $query_key = "";
	my @ResultLines = split(/\n/, $result);
	foreach $line (@ResultLines) {
		if ($line =~ /<WebEnv>([^<]+)<\/WebEnv>/) { $web_env = $1 }
		if ($line =~ /<QueryKey>([^<]+)<\/QueryKey>/) { $query_key = $1 }
	}
	if (($query_key eq "") || ($web_env eq "")) { die "FAILED" }
	
	#	Elink from genes to pubmed
	$url = 'http://eutils.ncbi.nlm.nih.gov/entrez/eutils/elink.fcgi?'
			. 'db=pubmed'
			. '&dbfrom=gene'
			. '&linkname=gene_pubmed'
			. '&WebEnv=' . $web_env
			. '&query_key=' . $query_key
			. '&cmd=neighbor_history';
if ($debug_code =~ /3/){print "Fetching URL 3 - $url<br>\n";}
	$result = get($url);
	my $web_env = $query_key = "";
	my @ResultLines = split(/\n/, $result);
	foreach $line (@ResultLines) {
		if ($line =~ /<WebEnv>([^<]+)<\/WebEnv>/) { $web_env = $1 }
		if ($line =~ /<QueryKey>([^<]+)<\/QueryKey>/) { $query_key = $1 }
	}
	if (($query_key eq "") || ($web_env eq "")) { die "FAILED" }
	
	#	Esearch in Pubmed using the term:
	$url = 'http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?'
			 . 'db=pubmed'
			 . '&usehistory=y'
			 . '&WebEnv=' . $web_env
			 . '&query_key=' . $query_key
			 . '&term="' . $term . '"' . $term_type;
if ($debug_code =~ /4/){print "Fetching URL 4 - $url<br>\n";}
	$result = get($url);
	my $web_env = $query_key = "";
	my @ResultLines = split(/\n/, $result);
	foreach $line (@ResultLines) {
if ($debug_code > 2){print "L-$line<BR>\n";}
		if ($line =~ /<WebEnv>([^<]+)<\/WebEnv>/) { $web_env = $1 }
		if ($line =~ /<QueryKey>([^<]+)<\/QueryKey>/) { $query_key = $1 }
	}
	if (($query_key eq "") || ($web_env eq "")) { die "FAILED" }
	
	#	Elink from genes to pubmed
	$url = 'http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?'
			. 'db=pubmed'
			. '&rettype=docsum'
			. '&retmode=text'
			. '&WebEnv=' . $web_env
			. '&query_key=' . $query_key;
if ($debug_code =~ /5/){print "Fetching URL 5 - $url<br>\n";}
	$result = get($url);
	my @ResultLines = split(/\n/, $result);
	my $pmid_url = 'http://www.ncbi.nlm.nih.gov/pubmed/';
	print "<OL>\n";
	my $found_start = 'F';
	$next_line_pmid_flag = 'F';
	foreach $line (@ResultLines) {
if ($debug_code > 2){print "L-$line<BR>\n";}
		$line =~ s/^\d+:\s+/<LI>/;
		$line =~ s/PMID: (\d+)/PMID: <A HREF="$pmid_url$1">$1<\/A>/;
		$line =~ s/(\[PubMed - indexed for MEDLINE\])/$1<\/LI>/;
		if ($next_line_pmid_flag eq 'T') {
			$line =~ s/^(\d+)/<A HREF="$pmid_url$1">$1<\/A>/;
			$next_line_pmid_flag = 'F';
		}
		print "$line\n";
		if ($line =~ /PMID:\s*$/) { $next_line_pmid_flag = 'T' }
	}
	print "</OL>\n";
}

print "<BR><BR><HR WIDTH=\"50%\"><BR>For questions or problem contact: <A HREF=\"mailto:$MiscVariables{ADMINISTRATOR_EMAIL}\">$MiscVariables{ADMINISTRATOR_NAME}</A>";
print "<BR><I><FONT SIZE=\"2\">Developed by Mark Gosink, Investigative Toxicology, DSRD @ Pfizer Inc.</I><BR></FONT>";
print '</DIV>';

print end_html();

exit;
