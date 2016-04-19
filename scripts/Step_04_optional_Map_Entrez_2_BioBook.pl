#!/usr/bin/perl

################################################################
#
#  Author(s) - Mark M. Gosink, Ph.D.
#  Company     Pfizer Inc
#
#  Creation Date - 25-Jan-10
#  Modified - 
#
#  Function - This is a template file ONLY!; It is meant as an example
#					of how users can create links between their own internal
#					gene identifiers and entrezgene IDs;
#					External users should either not run this script
#					or modify the sql to pull their own internal gene IDs
#
################################################################

$date = `date`;
chomp($date);
log_err("Running '$0' on '$date'.");

use DBI;

use Getopt::Long;

$result = GetOptions( 'user=s'	=> \$username,
								'pass=s'	=> \$password);
if (($username eq "") || ($password eq "")) {
	die "\nUSAGE:\n\t$0 -u(ser) username -p(ass) password\n\n";
}

$dsn = 'DBI:Oracle:'
			. 'database=db;'
			. 'sid=SID;'
			. 'host=host.address.com;'
			. 'port=number';

$db_handle = DBI->connect( $dsn, $username, $password, { PrintError => 1 }) or die "Can't connect!!\n\n";

$sql = "SELECT INTERNAL_GENEID, ENTREZ_GENE"
			. " FROM INTERNAL_GENEID_2_ENTREZ_GENE"
			. " WHERE ENTREZ_GENE != 'ENTREZ_GENE'";		#	only entrez ids
$statement = $db_handle->prepare($sql);
$statement->execute;
open(OUTFILE, ">./tmp_files/INTERNAL_GENEID_2_ENTREZ.txt");
print OUTFILE "#INTERNAL_ID\tENTREZ_ID\n";
while(@row = $statement->fetchrow_array) {
	print OUTFILE join("\t", @row) . "\n";
}
close(OUTFILE);

$statement->finish;
$db_handle->disconnect;

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
