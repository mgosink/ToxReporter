#!/usr/bin/perl -I..

################################################################
#
#  Author(s) - Mark M. Gosink, Ph.D.
#  Company -   DSRD, Pfizer Inc.
#
#  Creation Date - Wed Mar 11 14:05:48 EDT 2009
#  Modified - 
#
#  Function - Create R cmds to run on cluster for comparing
#					genesets to genesets
#
################################################################

use conf::ToxGene_Defaults;

$date = `date`;
chomp($date);

log_err("Running '$0' on '$date'.");

#	Required Files
$geneset_1 = './tmp_files/Mouse_Ingenuity.gene_sets';
$geneset_2 = './tmp_files/Mouse_phenotype.gene_sets';
$min_num_common = 3;

$r_app = $SetupFiles{R_APPLICATION};

log_err("Using gene_set files '$geneset_1' & '$geneset_2'.");
log_err("Gene sets must have at least '$min_num_common' overlapping genes before statistics are run.");

#	check that the Ingenuity file looks OK
if ((not(-s $geneset_1)) || (not(-T $geneset_1))|| (not(-s $geneset_2)) || (not(-T $geneset_2))) {
	die "\n\tRequired one or more geneset file not found or in wrong format at '$geneset_1 & $geneset_2'!\n\n";
}

$base_dir = './tmp_files/';

#	Load the first geneset
%GS1 = ();
%GS1_Genes = ();
open (FILE, $geneset_1);
while ($line = <FILE>) {
	if ($line =~ /^[#\s]/) { next }
	$line =~ s/[\n\f\r]+//g;
	my ($gs_id, $gs_desc, @Genes) = split(/\t/, $line);
	$GS1{$gs_id}{DESC} = $gs_desc;
	foreach $gene_id (@Genes) {
		$gene_id =~ s/\s+//g;
		$GS1{$gs_id}{GENES}{$gene_id} = 'T';
		$GS1_Genes{$gene_id} = 'T';
	}
}
close(FILE);
@List1 = keys(%GS1_Genes);
$all_gs1_cnt = $#List1 + 1;

#	Load the second geneset
%GS2 = ();
%GS2_Genes = ();
open (FILE, $geneset_2);
while ($line = <FILE>) {
	if ($line =~ /^[#\s]/) { next }
	$line =~ s/[\n\f\r]+//g;
	my ($gs_id, $gs_desc, @Genes) = split(/\t/, $line);
	$GS2{$gs_id}{DESC} = $gs_desc;
	foreach $gene_id (@Genes) {
		$gene_id =~ s/\s+//g;
		$GS2{$gs_id}{GENES}{$gene_id} = 'T';
		$GS2_Genes{$gene_id} = 'T';
	}
}
close(FILE);
@List2 = keys(%GS2_Genes);
$all_gs2_cnt = $#List2 + 1;

#	Parse the geneset names and make a combined name for output
$geneset_1 =~ s/.+\/([^\/]+)$/$1/;
$geneset_1 =~ s/\.gene_sets*$//;
$geneset_2 =~ s/.+\/([^\/]+)$/$1/;
$geneset_2 =~ s/\.gene_sets*$//;
$out_file_prefix = $geneset_1 . '_VS_' . $geneset_2;
$r_cmds_outfile = $base_dir . $out_file_prefix . '.R.cmds';

foreach $gs_id_1 (keys %GS1) {
	my $desc_1 = $GS1{$gs_id_1}{DESC};
	my @GS1_List = keys(%{$GS1{$gs_id_1}{GENES}});
	$gs1_cnt = $#GS1_List + 1;
	foreach $gs_id_2 (keys %GS2) {
		if (($geneset_1 eq $geneset_2) && ($gs_id_1 eq $gs_id_2)) { next }		#	skip self comparisons

		my $desc_2 = $GS2{$gs_id_2}{DESC};
		my @GS2_List = keys(%{$GS2{$gs_id_2}{GENES}});

		$gs2_cnt = $#GS2_List + 1;
		my $num_common = $possible_num_common = 0;
		foreach $gene_id_1 (keys %{$GS1{$gs_id_1}{GENES}}) {
			if ($GS2{$gs_id_2}{GENES}{$gene_id_1} eq 'T') { $num_common++ }
		}
		foreach $gene_id_1 (keys %GS1_Genes) {
			if ($GS2{$gs_id_2}{GENES}{$gene_id_1} eq 'T') { $possible_num_common++ }
		}

		if ($num_common < $min_num_common) { next }
		my $ratios = $num_common . ', ' . $possible_num_common . ', ' . ($gs1_cnt - $num_common) . ', ' . ($all_gs1_cnt - $possible_num_common);
		my $r_cmd = "#GeneSet1 ($desc_1)\|GeneSet2 ($desc_2): $gs_id_1\|$gs_id_2\nfisher.test(matrix(c($ratios), 2))\n";
		open (OUTFILE, ">>$r_cmds_outfile");
#		print $r_cmd;
		print OUTFILE $r_cmd;
		close(OUTFILE);
	}
}


$date = `date`;
chomp($date);
log_err("\t... finished creating R commands file '$r_cmds_outfile' on '$date'.");

$r_results_file = $r_cmds_outfile . '.Rout';
my $r_cmd = "$r_app CMD BATCH --vanilla  $r_cmds_outfile $r_results_file";
`$r_cmd`;
$date = `date`;
chomp($date);
log_err("\t... finished running R commands file '$r_cmds_outfile' on '$date'.");

%GS_1 = ();
%GS_2 = ();
%GS_Stats = ();
@Pval_list = ();
open (FILE, $r_results_file);
while ($line = <FILE>) {
	chomp($line);
	if ($line =~ /^> #GeneSet1 (\([^\)]+\))\|GeneSet2 (\([^\)]+\)): (\S+)/) {
		($cur_gs_id_1, $cur_gs_id_2) = split(/\|/, $3);
		$cur_gs_id_1 .= " $1";
		$cur_gs_id_2 .= " $2";
		$GS_1{$cur_gs_id_1} = 'T';
		$GS_2{$cur_gs_id_2} = 'T';
	}
	elsif ($line =~ /^> fisher.test\(matrix\(c\((\d+),/) {
		my $cnt = $1;
		$GS_Stats{$cur_gs_id_1}{$cur_gs_id_2}{CNT} = $cnt;
	}
	elsif ($line =~ /p-value ([=\<]) (\S+)/) {
		my $pval = $2;
		if ($1 =~ /\</) { $pval = 0 }
		$pval += 0;
		$GS_Stats{$cur_gs_id_1}{$cur_gs_id_2}{PVAL} = $pval;
		push(@Pval_list, $pval);
		push(@Pval_keys, "$cur_gs_id_1\t$cur_gs_id_2");
	}
	elsif ($line =~ /^odds ratio/) {
		$line = <FILE>;
		chomp($line);
		$line =~ s/\s+//g;
		$line += 0;
		$GS_Stats{$cur_gs_id_1}{$cur_gs_id_2}{ODDS} = $line;
	}
}
close(FILE);
$tmp_pval_file = $$ . '.pvals.tmp';
open (OUTFILE, ">./tmp_files/$tmp_pval_file");
foreach $pval (@Pval_list) {
	print OUTFILE "$pval\n";
}
close(OUTFILE);
$date = `date`;
chomp($date);
log_err("\t... finished extracting results from '$r_results_file' on '$date'.");


$tmp_rcmd_file = $$ . '.rcmd.tmp';
open(TMPFILE, ">$tmp_rcmd_file");
print TMPFILE "options(max.print=1000000)\n",
					"library(qvalue)\n",
					"data<-scan('$tmp_pval_file', sep=',')\n",
					"qvalue(data)\n";
close(TMPFILE);
my $r_cmd = "$r_app CMD BATCH --vanilla  $tmp_rcmd_file $tmp_rcmd_file.Rout";
`$r_cmd`;
my $data_type = '';
$idx = 0;
open(TMPFILE, "$tmp_rcmd_file.Rout");
while ($line = <TMPFILE>) {
	if (($line =~ /^^\$lambda/) || ($line =~ /^\n/)) { $data_type = '';next }
	elsif ($line =~ /^\$qvalues/) { $data_type = 'Q';next }
	elsif ($line =~ /^\$pvalues/) { $data_type = 'P';next }

	if ($data_type eq 'Q') {
		$line =~ s/^\s*\[\d+\]\s+//;	#	remove index
		my @Vals = split(/\s+/, $line);
		foreach $qval (@Vals) {
			if ($qval eq "") { next }
			my ($cur_gs_id_1, $cur_gs_id_2) = split(/\t/, $Pval_keys[$idx]);
			$GS_Stats{$cur_gs_id_1}{$cur_gs_id_2}{QVAL} = $qval;
			$idx++;
		}
	}
}
close(TMPFILE);
$date = `date`;
chomp($date);
log_err("\t... finished calculating Q-values on '$date'.");


unlink("$tmp_pval_file");
unlink("$tmp_rcmd_file");
unlink("$tmp_rcmd_file.Rout");

$outfile = $out_file_prefix . '.stats';
open(OUTFILE, ">./tmp_files/$outfile");
foreach $gs_id_1 (keys %GS_Stats) {
	print OUTFILE $gs_id_1;
	foreach $gs_id_2 (keys %{$GS_Stats{$gs_id_1}}) {
		print OUTFILE "\t$gs_id_2\|",
							$GS_Stats{$gs_id_1}{$gs_id_2}{ODDS}, "\|",
							$GS_Stats{$gs_id_1}{$gs_id_2}{PVAL}, "\|",
							$GS_Stats{$gs_id_1}{$gs_id_2}{QVAL}, "\|",
							$GS_Stats{$gs_id_1}{$gs_id_2}{CNT};
	}
	print OUTFILE "\n";
}
close(OUTFILE);

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
