#!/usr/bin/perl

################################################################
#
#  Author(s) - Mark M. Gosink, Ph.D.
#  Company     Pfizer Inc
#
#  Creation Date - 25-Jan-10
#  Modified - 
#
#  Function - Creates a modified copy of the database creation
#					SQL code to point to the appropriate database;
#					Script also modifies the config file to point at
#					the correct instance
#
################################################################

use Getopt::Long;

$date = `date`;
chomp($date);
log_err("Running '$0' on '$date'.");

GetOptions ('database=s'	=> \$database_name );
if ($database_name eq "") {
	die "\nUSAGE:\n\t$0 -d(atabase) database_name\n\n";
}

open(FILE, "./MasterCopy_Step_02_Create_ToxGene.sql");
open(OUTFILE, ">Step_02_Create_ToxGene.sql");
while ($line = <FILE>) {
	$line =~ s/\s`TOXREPORTER_DBNAME`/ `$database_name`/;
	print OUTFILE $line;
}
close(OUTFILE);
close(FILE);


open(FILE, "./MasterCopy_Step_03_AddDefaultSpecies.sql");
open(OUTFILE, ">Step_03_AddDefaultSpecies.sql");
while ($line = <FILE>) {
	$line =~ s/\s`TOXREPORTER_DBNAME`/ `$database_name`/;
	print OUTFILE $line;
}
close(OUTFILE);
close(FILE);


open(FILE, "./MasterCopy_ToxGene_Defaults.pm");
open(OUTFILE, ">../conf/ToxGene_Defaults.pm");
while ($line = <FILE>) {
	$line =~ s/^'DATABASE_NAME'			=>	'[^']+',/'DATABASE_NAME'			=>	'$database_name',/;
	print OUTFILE $line;
}
close(OUTFILE);
close(FILE);

$date = `date`;
chomp($date);
log_err("Finished '$0' on '$date'.");

exit;

sub log_err {
	my $msg = $_[0];
	my $log_file = $0 . ".log";
	open (LOG, ">>$log_file");
	print LOG "$msg\n";
	close(LOG);
}
