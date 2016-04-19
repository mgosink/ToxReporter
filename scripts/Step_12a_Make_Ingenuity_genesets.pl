#!/usr/bin/perl -I..

################################################################
#
#  Author(s) - Mark M. Gosink, Ph.D.
#  Company -   Pfizer Inc.
#
#  Creation Date - Thu Mar 5, 2009
#  Modified - 
#
#  Function - Take output of 'pathwaylist' Ingenuity integration
#					module and create human, mouse, & rat pathway genesets
#		Requires - assumes HTML file contains pathways in rows and
#					gene columns in the order: human, mouse, rat
#		Input - HTML output from 'pathwaylist'
#		Output - FILE: 'Organism_Name'_Ingenuity.gene_sets
#
################################################################

use Text::CSV;

#	Required Files
$ingenuity_file = $SetupFiles{ING_PATHWAYS};

#	check that the Ingenuity file looks OK
if ((not(-s $ingenuity_file)) || (not(-T $ingenuity_file))) {
	die "\n\tRequired Ingenuity pathways file not found or in wrong format at '$ingenuity_file'!\n\n";
}
$file_listing = `ls -l $ingenuity_file`;
chomp($file_listing);

$date = `date`;
chomp($date);

log_err("Running '$0' on '$date'.");

my $desc = "#\tIngenuity Pathways Genesets\n";
$desc .= "#\t" . $0 . ' run on ' . $date . "\n";
$desc .= "#\tusing '" . $ingenuity_file . "'\n";
$desc .= "#\t\tfile listing at runtime '" . $file_listing . "'\n\n";

open(OUTFILE, ">./tmp_files/Mouse_Ingenuity.gene_sets");
print OUTFILE $desc;
my $csv = Text::CSV->new ( { binary => 1 } )  # should set binary attribute.
                 or die "Cannot use CSV: ".Text::CSV->error_diag ();
open($fh, "<:encoding(utf8)", $ingenuity_file);
binmode STDOUT, ":utf8";
while ($csv->getline( $fh )) {
	my @Columns = $csv->fields();
	my $id_data = $Columns[0];
	$id_data =~ s/.*(ING:[A-Za-z0-9]+).*/$1/;
	my $current_path_id = utf_to_html($id_data);
	my $current_pathname = utf_to_html($Columns[1]);
	my $current_pathtype = utf_to_html($Columns[2]);
	my $current_pathentities = utf_to_html($Columns[3]);
	my $human = utf_to_html($Columns[4]);
	my $mouse = utf_to_html($Columns[5]);
	my $rat = utf_to_html($Columns[6]);
	$mouse =~ s/\s+//g;
	$mouse =~ s/,/\t/g;
	print OUTFILE "$current_path_id\t$current_pathname\t$mouse\n";
}
close($fh);
close(OUTFILE);

$date = `date`;
chomp($date);
log_err("Finished '$0' on '$date'.");

exit;

sub utf_to_html {
	my $term = $_[0];
	$term =~ s/\x{03B1}/&alpha;/g;	#	alpha
	$term =~ s/\x{03B2}/&#976;/g;	#	beta
	$term =~ s/\x{0394}/&#916;/g;	#	delta, upper case
	$term =~ s/\x{03B4}/&#948;/g;	#	delta, lower case
	$term =~ s/\x{03B7}/&#951;/g;	#	eta
	$term =~ s/\x{03B9}/&#953;/g;	#	iota
	$term =~ s/\x{03B3}/&#947;/g;	#	gamma
	$term =~ s/\x{03BA}/&#954;/g;	#	kappa
	$term =~ s/\x{03BB}/&#955;/g;	#	
	$term =~ s/\x{03B5}/&#949;/g;	#	epsilon
	$term =~ s/\x{03C9}/&#969;/g;	#	omega
	$term =~ s/\x{03C3}/&#963;/g;	#	sigma
	$term =~ s/\x{03B8}/&#952;/g;	#	theta
	$term =~ s/\x{03B6}/&#950;/g;	#	zeta

	$term =~ s/\s+/ /g;					#	remove extra spaces
	$term =~ s/\x{2424}//g;			#	remove newline
	$term =~ s/\x{000A}//g;			#	remove line feed
	$term =~ s/\x{2013}/-/g;
	$term =~ s/[^[:ascii:]]+/***FOOBAR***/g;
	return $term;
}

sub log_err {
	my $msg = $_[0];
	my $log_file = $0 . ".log";
	open (LOG, ">>$log_file");
	print LOG "$msg\n";
	close(LOG);
}
