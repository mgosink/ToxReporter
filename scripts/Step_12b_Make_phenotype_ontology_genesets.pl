#!/usr/bin/perl -I..

################################################################
#
#  Author(s) - Mark M. Gosink, Ph.D.
#  Company -   Scripps Florida
#
#  Creation Date - Jul 2007
#
#  Function - parse JAX's phenotype ontology 'MPheno_OBO.ontology'
#					and gene files 'MGI_PhenoGenoMP.rpt' to create
#					gene_sets for use with Geneset Analyzer.
#		Requires - above files and NCBI's 'gene_info' file from
#						the Gene database
#		Input - NCBI's Taxonomy ID for the working organism,
#					fraction of total express needed to be found in
#					one tissue
#		Output - FILE: Mouse_phenotype.gene_sets
#
################################################################

use conf::ToxGene_Defaults;

%PHENO = ();
%MGI_to_Entrez = ();
%ParentChild = ();
%PHENO_to_Genes = ();
$depth = 0;

#	Required Files
$ontology_file = $SetupFiles{MOUPHENOONT};
$gene_2_pheno_file = $SetupFiles{MOUPHENOS};
$gene_info_file = $SetupFiles{GENEINFO};

#	check that the Ingenuity file looks OK
if ((not(-s $ontology_file)) || (not(-T $ontology_file))) {
	die "\n\tRequired Phenotype Ontology file not found or in wrong format at '$ontology_file'!\n\n";
}
elsif ((not(-s $gene_2_pheno_file)) || (not(-T $gene_2_pheno_file))) {
	die "\n\tRequired Genotype to Phenotype file not found or in wrong format at '$gene_2_pheno_file'!\n\n";
}
elsif ((not(-s $gene_info_file)) || (not(-T $gene_info_file))) {
	die "\n\tRequired Gene information file not found or in wrong format at '$gene_info_file'!\n\n";
}

$onto_file_listing = `ls -l $ontology_file`;
chomp($onto_file_listing);
$g2p_file_listing = `ls -l $gene_2_pheno_file`;
chomp($g2p_file_listing);
$ginf_file_listing = `ls -l $gene_info_file`;
chomp($ginf_file_listing);

$date = `date`;
chomp($date);

log_err("Running '$0' on '$date'.");

my $desc = "#\tMouse Mutant Phenotype Genesets\n";
$desc .= "#\t" . $0 . ' run on ' . $date . "\n";
$desc .= "#\tusing '" . $ontology_file . "'\n";
$desc .= "#\t\tfile listing at runtime '" . $onto_file_listing . "'\n";
$desc .= "#\tusing '" . $gene_2_pheno_file . "'\n";
$desc .= "#\t\tfile listing at runtime '" . $g2p_file_listing . "'\n";
$desc .= "#\tusing '" . $gene_info_file . "'\n";
$desc .= "#\t\tfile listing at runtime '" . $ginf_file_listing . "'\n\n";

#	Parse the mammalian phenotype ontology for terms and relationship
open (FILE, $ontology_file);
while ($line = <FILE>) {
	chomp($line);

	if ($line =~ /^\[Term\]/) {
		$current_obsolete = 'F';
		$current_id = $current_name = '';
	}
	if ($line =~ /^id:\s+(MP:\d+)/) {
		$current_obsolete = 'F';
		$current_id = $current_name = '';
		$current_id = $1;
	}
	if ($line =~ /^name:\s+(.+)/) {
		$PHENO{$current_id}{NAME} = $1;
	}
	if ($line =~ /^is_obsolete: true/) {
		$PHENO{$current_id}{OBSOLETE} = 'T';
	}

	if ($line =~ /^is_a: (MP:\d+)/) {
		$ParentChild{$1}{$current_id} = 'is_a';
	}
	if ($line =~ /^relationship: part_of (MP:\d+)/) {
		$ParentChild{$1}{$current_id} = 'part_of';
	}
}
close(FILE);

#	Extract MGI id to Entrez id info
open (FILE, $gene_info_file);
while ($line = <FILE>) {
	chomp($line);
	my @Vals = split(/\t/, $line);
	if ($Vals[0] != 10090) { next }	#	skip non-mouse
	my @XRefs = split(/\|/, $Vals[5]);
	foreach $xref (@XRefs) {
		$xref =~ s/MGI:MGI:/MGI:/;
		if ($xref =~ /MGI:\d+/) { $MGI_to_Entrez{$xref} = $Vals[1] }
	}
}
close(FILE);

#	link phenotype to genes
open (FILE, $gene_2_pheno_file);
while ($line = <FILE>) {
	chomp($line);
	my @Vals = split(/\t/, $line);
	my @MGIs = split(/,/, $Vals[5]);
	foreach $mgi (@MGIs) {
		my $gene = $MGI_to_Entrez{$mgi};
		if ($gene ne "") {
			$PHENO_to_Genes{$Vals[3]}{$gene} = 'T';
		}
	}
}
close(FILE);


open(OUTFILE, ">./tmp_files/Mouse_phenotype.gene_sets");
print OUTFILE $desc;
foreach $catagory (keys %PHENO) {
	my $desc = '';
	if ($PHENO{$catagory}{OBSOLETE} eq 'T') { $desc = 'OBSOLETE: ' }
	$desc .= $PHENO{$catagory}{NAME};
	@GeneList = ();
	$depth = 0;
	add_child_genes($catagory, 0);

	my %GeneHash = ();
	foreach $gene (@GeneList) { $GeneHash{$gene} = 'T' }
	my $nonredundantgenes = join("\t", keys(%GeneHash));
	if ($nonredundantgenes ne "") {
		print OUTFILE "$catagory\t$desc\t$nonredundantgenes\n"
	}
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

sub add_child_genes {
	my $id = $_[0];
	my $depth = $_[1]+1;
	if ($depth > 50) { die "Depth > 50!!\n\n" }		#	something must be wrong if you are more than 50 levels deep; infinite recursion escape clause
	push(@GeneList, keys(%{$PHENO_to_Genes{$id}}));
	my @Children = keys(%{$ParentChild{$id}});
	if ($#Children >= 0 ) {
		foreach $child (@Children) {
			add_child_genes($child, $depth)
		}
	}
	return;
}
