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

print header();

$image_path = $MiscVariables{IMAGE_PATH};

print start_html(-title=>"ToxReporter: Genetic Association View",
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

# vvvvvvvvvvvv Log the use of this application vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
#	Log the use of this application
eval {
	my $add = $ENV{HTTP_X_FORWARDED_FOR}?$ENV{HTTP_X_FORWARDED_FOR}:$ENV{REMOTE_ADDR};
#	`/cssi/data/neusentis_data1/cgi/comptoxdev.pfizer.com/TOOLS/Log_Use $add $0`;
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
        <i><font color="blue">T</font>ox<font color="blue">G</font>ene <font color="orangered">G</font>enetic Association Viewer</i>
      </div>
    </td>
  </tr>
</table>

MENU

print '<DIV class="body_indent">';

$genass_id = param(GEN_ASSOC);

%GeneAssoc = ();
@GeneAssocHeaders = (
	'ID',
	'Association(Y/N)',
	'Broad Phenotype',
	'Disease Class',
	'Disease Class Code',
	'MeSH Disease Terms',
	'Chromosom',
	'Chr-Band',
	'Gene',
	'DNA Start',
	'DNA End',
	'P Value',
	'Reference',
	'Pubmed ID',
	'Allele Author Description',
	'Allele Functional Effects',
	'Polymophism Class',
	'Gene Name',
	'RefSeq',
	'Population',
	'MeSH Geolocation',
	'Submitter',
	'Locus Number',
	'Unigene',
	'Narrow Phenotype',
	'Mole. Phenotype',
	'Journal',
	'Title',
	'rs Number',
	'OMIM ID',
	'Year',
	'Conclusion',
	'Study Info',
	'Env. Factor',
	'GI Gene A',
	'GI Allele of Gene A',
	'GI Gene B',
	'GI Allele of Gene B',
	'GI Gene C',
	'GI Allele of Gene C',
	'GI Association?',
	'GI combine Env. Factor',
	'GI relevant to Disease'
);
open (FILE, './data/static/all.txt');
while ($line = <FILE>) {
	if ($line =~ /^[#\s]/) { next }
	$line =~ s/[\n\r\f]+//;

	my @Vals = split(/\t/, $line);
	if ($Vals[0] eq $genass_id) {
		print "<TABLE BORDER=1>\n";
		print "<TR bgcolor='BLUE'><TH><FONT COLOR='WHITE'>Genetic Association ID</FONT></TH><TH><FONT COLOR='WHITE'>$Vals[0]</FONT></TH></TR>";
		for ($idx = 1; $idx <= $#Vals; $idx++) {
			if ($Vals[$idx] ne '') {
				if ($color eq 'lightblue') { $color = 'lightyellow' }
				else { $color = 'lightblue' }
				my $link_val = $Vals[$idx];
				if ($link_val =~ /^http/) { $link_val = "<A HREF='$link_val'>$link_val</A>" }
				elsif ($GeneAssocHeaders[$idx] =~ /OMIM ID/) { $link_val = "<A HREF='$MiscLinks{MIM_GENE_URL}$link_val'>$link_val</A>" }
				elsif ($GeneAssocHeaders[$idx] =~ /Pubmed ID/) { $link_val = "<A HREF='$MiscLinks{PUBMED_URL}$link_val'>$link_val</A>" }
				print "<TR bgcolor='$color'><TD>$GeneAssocHeaders[$idx]</TD><TD>$link_val</TD></TR>";
			}
		}
		print "</TABLE>\n";
		last;
	}
}
close(FILE);


print "<BR><BR><HR WIDTH=\"50%\"><BR>For questions or problem contact: <A HREF=\"mailto:$MiscVariables{ADMINISTRATOR_EMAIL}\">$MiscVariables{ADMINISTRATOR_NAME}</A>";
print "<BR><I><FONT SIZE=\"2\">Developed by Mark Gosink @ Scripps Florida, 5353 Parkside Dr. RF-A, Jupiter, FL 33458</I><BR>&copy; Mark Gosink</FONT>";
print '</DIV>';


print end_html();

exit;

