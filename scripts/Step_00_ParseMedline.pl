#!/usr/bin/perl -I..

################################################################
#
#  Author(s) - Mark M. Gosink, Ph.D.
#  Company     Pfizer Inc
#
#  Creation Date - April 30, 2009
#
#  Function - parse Medline files to generate files of MESH
#					terms and pubmed IDs for each; because of the
#					number of Medline files, this script should be
#					run before initiating the remaining scripts
#
################################################################

use conf::ToxGene_Defaults;

use DBI;

use Getopt::Long;

#	Required Files
$pubmed_file = $SetupFiles{GENE2PUBMED};
$hologene_file = $SetupFiles{HOMOLOGENE};
$path_to_medline_base = $SetupFiles{MEDLINE_BASE};
$path_to_medline_incr = $SetupFiles{MEDLINE_INCR};
$path_to_temporary_storage = $SetupFiles{TEMP_STORE};

$cmd = 'ls -1r ' . $path_to_medline_incr . '/medline*.xml.gz ' . $path_to_medline_base . '/medline*.xml.gz';
@MedlineFiles = split(/\n/, `$cmd`);

if ((!(-s $pubmed_file)) || (!(-T $pubmed_file))) {
	die "Required file '$pubmed_file' not found or is in the wrong format.\n\n";
}
if ((!(-s $hologene_file)) || (!(-T $hologene_file))) {
	die "Required file '$hologene_file' not found or is in the wrong format.\n\n";
}

$pubmed_gene_count_threshold = 100;		#	any articles linked to more than this value are skipped, they are assumed to be too non-specific i.e. microarray papers
$search_org_id = 9606;						#	gene IDs are converted to human (NCBI taxomomy ID 9606) homolog ID 

$date = `date`;
chomp($date);
log_err("Running '$0' on '$date'.");
log_err("\tParsing the '$pubmed_file' file for gene to publication references.");

($weekday, $month, $day, $time, $zone, $year) = split(/\s+/, $date);
$rundate = $month . '_' . $day . '_' . $year;

$temp_storage = $path_to_temporary_storage . '/ToxReporter_' . $rundate;	#	temp storage directory for large files
$temp_storage =~ s/\s+/_/g;
`mkdir  $temp_storage`;
$temp_storage_mesh = $temp_storage .'/MESH';
`mkdir  $temp_storage_mesh`;

log_err("\tFiles stored in '$temp_storage'.");

#	Parse the homolog data to merge different species
%Homo_to_Gene = ();
%Gene_to_Homo = ();
open (FILE, $hologene_file);
while ($line = <FILE>) {
	chomp($line);
	my ($homol_id, $org_id, $gene_id, undef) = split(/\t/, $line);
	if ($org_id == $search_org_id) {
		$Homo_to_Gene{$homol_id} = $gene_id;
	}
	else {
		$Gene_to_Homo{$gene_id} = $homol_id;
	}
}
close(FILE);
log_err("\tFinished parsing homolog file'$hologene_file'.");

#	Load data linking PubMed IDs to the gene IDs discussed with the PubMed article
%PubmedGenes = ();
open(FILE, $pubmed_file);
while ($line = <FILE>) {
	if ($line =~ /^#/) { next }	#	skip comment lines
	chomp($line);
	my ($tax_id, $gene_id, $pubmed_id) = split(/\t/, $line);
	if ($tax_id != $search_org_id) {
		$gene_id = $Homo_to_Gene{$Gene_to_Homo{$gene_id}};
		if ($gene_id eq "") { next }
	}
	$PubmedGenes{$pubmed_id}{$gene_id} = 'T';		#	concatenate all genes mentioned in a single paper into a hash by pubmed id
}
close(FILE);
foreach $pubmed_id (keys (%PubmedGenes)) {
	my @TmpArray = keys(%{$PubmedGenes{$pubmed_id}});
	if ($#TmpArray > $pubmed_gene_count_threshold) { delete $PubmedGenes{$pubmed_id} }
}
log_err("\tFinished parsing pubmed to gene file'$pubmed_file'.");

#	articles are parsed in reverse order is it is assumed largest number is most recent
foreach $file (@MedlineFiles) {
	$major_heading = 'F';
	$mesh_head_flag = 'F';
	%MeshCounts = ();
	log_err("\t... Parsing '$file' ...");
#	open(FILE, $file);
	open(FILE, "gunzip -c $file 2>&1 |");
	$found_article_pmid_flag = 'F';
	$ignore_repeat = 'F';
	$current_id = $descriptor = $gene_id = "";
	while ($line = <FILE>) {
		chomp($line);
		if ($line =~ /^\<MedlineCitation/) { $found_article_pmid_flag = 'T' }		#	this flag should only be on for the first line after the start of the citation
		if (($line =~ /\<PMID\s+[^\>]*\>(\d+)\<\/PMID\>/) && ($found_article_pmid_flag eq 'T')) {
			$current_id = $1;
			$found_article_pmid_flag = 'F';
			if (not(defined $PubmedGenes{$pubmed_id})) { next }	#	skip articles which are not linked to genes
		}
		elsif (($line =~ /<MeshHeading>/) && ($ignore_repeat ne 'T')) { $mesh_head_flag = 'T' }

		elsif (($line =~ /<\/MeshHeading>/) && ($ignore_repeat ne 'T')) {
			if ($descriptor ne '') {
				foreach $gene_id (keys(%{$PubmedGenes{$current_id}})) {
					if ($major_heading ne 'T') { $MeshCounts{$descriptor}{$gene_id}{$current_id} = 'MAJOR'; }
					elsif ($MeshCounts{$descriptor}{$gene_id}{$current_id} ne 'MAJOR') { $MeshCounts{$descriptor}{$gene_id}{$current_id} = 'minor'; }
				}
			}
			$descriptor = '';
			$major_heading = 'F';
			$mesh_head_flag = 'F'
		}

		elsif (($mesh_head_flag eq 'T')
					&& ($line =~ /<DescriptorName MajorTopicYN="([YN])"[^\>]*>([^<]+)<\/DescriptorName>/)
					&& ($ignore_repeat ne 'T')) {
			my $major_topic_flag = $1;
			$descriptor = $2;
			if ($major_topic_flag eq 'Y') { $major_heading = 'T' }
		}
		elsif (($mesh_head_flag eq 'T')
					&& ($line =~ / MajorTopicYN="Y">/)
					&& ($ignore_repeat ne 'T')) {
			$major_heading = 'T';
		}
	}
	close(FILE);

	foreach $descriptor (keys %MeshCounts) {
		my @Genes = keys %{$MeshCounts{$descriptor}};
		my $genes = '';
		foreach $gene_id (@Genes) {
			$genes .= "\t$gene_id\|\|";
			my @PMIDs = keys(%{$MeshCounts{$descriptor}{$gene_id}});
			foreach $pubmed_id (@PMIDs) {
				if ($MeshCounts{$descriptor}{$gene_id}{$pubmed_id} eq 'MAJOR') { $genes .= ":M\|$pubmed_id" }
				else { $genes .= ":m\|$pubmed_id" }
			}
		}
		$genes =~ s/^\t//;
		save_mesh_counts($descriptor, $genes);
	}

}

$date = `date`;
chomp($date);
log_err("\t...completed parsing of MedLine files on '$date'.");


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

sub save_mesh_counts {
	my $mesh = $_[0];
	my $genes = $_[1];
	my $mesh_file = $temp_storage_mesh . '/' . $mesh;
	$mesh_file =~ s/\s+/_/g;
	open (LOG, ">>$mesh_file");
	print LOG "$genes\n";
	close(LOG);
}
