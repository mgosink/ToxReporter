#!/usr/bin/perl -I..

################################################################
#
#  Author(s) - Mark M. Gosink, Ph.D.
#  Company -   DSRD, Pfizer Inc.
#
#  Creation Date - Mon Mar 16 11:20:50 EDT 2009
#  Modified - 
#
#  Function - Create Insert statements to load Gene table,
#					load it, and then export Entrez to idGene table
#
################################################################

use conf::ToxGene_Defaults;

use Getopt::Long;

$date = `date`;
chomp($date);
log_err("Running '$0' on '$date'.");

$result = GetOptions ('user=s'		=> \$username,
								'pass=s'		=> \$password);
if (($username eq "") || ($password eq "")) {
	die "\nUSAGE:\n\t$0 -u(ser) username -p(ass) password\n\n";
}

#	Set up mysql command and DBI mysql connection string
$dsn = "";
$mysql_cmd = "";
$db_name = $MiscVariables{DATABASE_NAME};
if ($MiscVariables{DATABASE_SOCKET} ne '') {
	$mysql_cmd = 'mysql -S' . $MiscVariables{DATABASE_SOCKET} . ' -u' . $username . ' -p' . $password;
}
else {
	my $host = $MiscVariables{DATABASE_HOST};
	my $port = $MiscVariables{DATABASE_PORT}
			. ':database=' . $MiscVariables{DATABASE_NAME}
			. ';host=' . $MiscVariables{DATABASE_HOST}
			. ';port=' . $MiscVariables{DATABASE_PORT};
	$mysql_cmd = 'mysql -P' . $port . ' -h' . $host . ' -u' . $username . ' -p' . $password;
}

@Data_Files = qw( ./tmp_files/Human_Toxicity.SDgammaPercentiles ./tmp_files/Mouse_Toxicity.SDgammaPercentiles );
$percent_sql_file = './tmp_files/InsertSDGPercentiles.sql';
open(PERCENT_OUTFILE, ">$percent_sql_file");
print PERCENT_OUTFILE "use $db_name;\n";
print PERCENT_OUTFILE "DELETE FROM Annotation WHERE Annot_Link = 'SDGTOX_AT_GLANCE';\n";
foreach $filename (@Data_Files) {
	open(FILE, $filename);
	while ($line = <FILE>) {
		chomp($line);
		my ($idgene, $percentiles) = split(/\t/, $line);
		$percentiles = make_sql_safe($percentiles);
		print PERCENT_OUTFILE "INSERT INTO Annotation(idGene, Annot_Text, Annot_Link, Create_Time) VALUES ('$idgene', '$percentiles', 'SDGTOX_AT_GLANCE', NOW());\n";
	}
	close(FILE);
}
close(PERCENT_OUTFILE);
$date = `date`;
chomp($date);
log_err("\t... loading '$percent_sql_file' on '$date'.");
$cmd = $mysql_cmd . ' < ' . $percent_sql_file;
`$cmd`;

$date = `date`;
chomp($date);
log_err("Finished '$0' on '$date'.");

exit;

sub make_sql_safe {
	my $term = $_[0];
	$term =~ s/\\/\\\\/g;
	$term =~ s/'/\\'/g;
	$term =~ s/"/\\"/g;
	return $term;
}

sub log_err {
	my $msg = $_[0];
	my $log_file = $0 . ".log";
	open (LOG, ">>$log_file");
	print LOG "$msg\n";
	close(LOG);
}
