package conf::ToxGene_Defaults;

################################################################
#
#  Author(s) - Mark M. Gosink, Ph.D.
#  Company     Pfizer
#
#  Creation Date - March 16, 2009
#  Modified - 
#
#  Function - This package holds many of the default values
#
################################################################

use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw( %MiscVariables %MiscLinks %GO_Sup_Def %IssueCatagories %ToolBox_2_ToxGene %SetupFiles %ToolTips);


###	ENVIRONMENT VARIABLES
%MiscVariables = (
'ADMINISTRATOR_NAME'		=>	'ToxReporter Administrator',
'ADMINISTRATOR_EMAIL'	=>	'email_name@address.com',

'TOXGENE_USER'				=>	'ToxGene_Guest',
'TOXGENE_PSWD'				=>	'guest',

'DATABASE_TYPE'			=>	'DBI:mysql',
'DATABASE_NAME'			=>	'ToxReport_A',
'DATABASE_HOST'			=>	'localhost',		#	change as appropriate
'DATABASE_PORT'			=>	'3606',				#	change as appropriate
'DATABASE_SOCKET'			=>	'/opt2/data/mysql/mysql.sock',				#	change as appropriate
#'DATABASE_SOCKET'			=>	'/mysql.sock',				#	only use if you local mysql socket is in a non-standard location

'BASE_TOX_SYS_ID'			=>	'1',
'BASE_TOX_ID'				=>	'81',		#	Database identifier (idToxTerm) for glabal parent ie for Safety Lexicon 81 = DB ID for 'PT:0000071'
'LEGEND'						=>	'Legend/90th percentile:2/80th percentile:3/60th percentile:4/40th percentile:6/20th percentile:8/>0th percentile:9/no data:10',
'IMAGE_PATH'				=>	'/ToxReporter'
);
$MiscVariables{DATABASE}  = $MiscVariables{DATABASE_TYPE}
										. ':database=' . $MiscVariables{DATABASE_NAME}
										. ';host=' . $MiscVariables{DATABASE_HOST}
										. ';port=' . $MiscVariables{DATABASE_PORT};

%IssueCatagories = (
'Adipose'						=>	'Adipose|86|PT:0000015',
'Cardiovascular_System'		=>	'Cardiovascular_System|88|PT:0000004',
'Dermal'							=>	'Dermal|55|PT:0000003',
'Endocrine_System'			=>	'Endocrine_System|7|PT:0000012',
'Gastrointestinal_System'	=>	'Gastrointestinal_System|50|PT:0000002',
'Hemolymphatic'				=>	'Hemolymphatic|25|PT:0000013',
'Hepatobiliary_System'		=>	'Hepatobiliary_System|85|PT:0000008',
'Immune_System'				=>	'Immune_System|22|PT:0000009',
'Inflammation'					=>	'Inflammation||PT:0000024',
'Musculoskeletal_System'	=>	'Musculoskeletal_System|97|PT:0000011',
'Nervous_System'				=>	'Nervous_System|18|PT:0000005',
'Olfactory'						=>	'Olfactory|37|PT:0000017',
'Ocular'							=>	'Ocular|76|PT:0000014',
'Pulmonary_System'			=>	'Pulmonary_System|66|PT:0000007',
'Renal_System'					=>	'Renal_System|100|PT:0000006',
'Reproductive_System'		=>	'Reproductive_System|2|PT:0000010',
'Mitochondrial_toxicity'	=>	'Mitochondrial_toxicity|15|PT:0000023',
'Carcinogenicity'				=>	'Carcinogenicity|11|PT:0000021'
);


###	ENVIRONMENT VARIABLES
%MiscLinks = (
'DSRD_HOME'				=>	'http://wrd.pfizer.com/GLOBALLINES/dsrd/Pages/DSRDHome.aspx',
'GENEBOOK'				=>	'http://pharmamatrix.pfizer.com/pharmamatrix/selPriMenuItem.htm?&priId=geneMenuItem',
'TARGETPEDIA'			=>	'http://targetpedia.pfizer.com/index.php/',
'NCBI_GENE'				=>	'http://www.ncbi.nlm.nih.gov/sites/entrez?db=gene',
'NCBI_HAPMAP'			=>	'http://hapmap.ncbi.nlm.nih.gov/cgi-perl/gbrowse/hapmap28_B36/?name=',
'DB_SNP'					=>	'http://www.ncbi.nlm.nih.gov/SNP/snp_ref.cgi?locusId=',
'DB_SNP2'				=>	'http://www.ncbi.nlm.nih.gov/projects/SNP/snp_ref.cgi?searchType=adhoc_search&type=rs&rs=',
'GO_URL'					=>	'http://amigo.geneontology.org/amigo/term/',
'TRANSFAC_URL'			=>	'http://www.gene-regulation.com/cgi-bin/pub/databases/transfac/getTF.cgi?AC=',
'GENEID_URL'			=>	'http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?db=gene&cmd=Retrieve&dopt=full_report&list_uids=',
'PMXID_URL'				=>	'http://pharmamatrix.pfizer.com/pharmamatrix/displayGene.htm?requested=',
'ENSEMBLGENE_URL'		=>	'http://www.ensembl.org/Homo_sapiens/Gene/Summary?g=',
'HUGO_GENE_URL'		=>	'http://www.genenames.org/data/hgnc_data.php?hgnc_id=',
'MGI_GENE_URL'			=>	'http://www.informatics.jax.org/searches/accession_report.cgi?id=MGI:',
'MGI_PHENO_URL'		=>	'http://www.informatics.jax.org/searches/Phat.cgi?id=',
'RGD_GENE_URL'			=>	'http://rgd.mcw.edu/rgdweb/report/gene/main.html?id=',
'RATMAP_GENE_URL'		=>	'http://ratmap.gen.gu.se/ShowSingleLocus.htm?accno=',
'MIM_GENE_URL'			=>	'http://www.ncbi.nlm.nih.gov/omim/',
'ZFIN_GENE_URL'		=>	'http://zfin.org/cgi-bin/webdriver?MIval=aa-markerview.apg&OID=',
'INGENUITY_URL'		=>	'https://pfizer.analysis.ingenuity.com/pa/api/v2/pathwayquery?geneidtype=entrezgene&applicationame=ToxGene&ingenuitypathwayid=',
'PUBMED_URL'			=>	'http://www.ncbi.nlm.nih.gov/pubmed/',
'BODY_MAP'				=>	'http://bodymap.pfizer.com/local-bin/get_bodymap.pl?output_type=whole&id=',
'HPRD_URL'				=>	'http://www.hprd.org/protein/',
'GEO_HUMAN_ATLAS'		=>	'http://www.ncbi.nlm.nih.gov/geoprofiles/?term=(GDS594%5BGEO+Accession%5D+OR+GDS596%5BGEO+Accession%5D)+AND+',
'GEO_MOUSE_ATLAS'		=>	'http://www.ncbi.nlm.nih.gov/geoprofiles/?term=GDS592[GEO Accession]+AND+',
'GENETIC_ASSOC'		=>	'http://geneticassociationdb.nih.gov/cgi-bin/tableview.cgi?table=allview&cond=LOCUSNUM=',
#'GENETIC_ASSOC_RPT'	=>	'http://geneticassociationdb.nih.gov/cgi-bin/view.cgi?table=allview&id=',
'GENETIC_ASSOC_RPT'	=>	'DisplayGenAssoc.cgi?GEN_ASSOC=',
'ALLEN_ADULT_HUMAN'	=>	'http://human.brain-map.org/microarray/search/show?exact_match=false&search_type=gene&search_term=',
'ALLEN_ADULT_MOUSE'	=>	'http://mouse.brain-map.org/search/show?page_num=0&page_size=31&no_paging=false&exact_match=false&search_type=gene&search_term=',
'ALLEN_DEV_MOUSE'		=>	'http://developingmouse.brain-map.org/data/search/gene/index.html?term=',
'MESH_SEARCH'			=>	'http://www.ncbi.nlm.nih.gov/sites/entrez?cmd=search&db=mesh&doptcmdl=detailed&term=',
'HOMO_PUBMAJOR_REDIR'	=>	'HomoPubMedRedirect.cgi?TERMTYPE=MAJOR&HOMOLOG=',
'HOMO_PUBMED_REDIR'	=>	'HomoPubMedRedirect.cgi?HOMOLOG=',
'FETALMAP_V1'			=>	'http://genomics.pfizer.com/local-bin/get_bodymap.pl?output_type=fetal&id=',
'ABI_PRIMERS'			=>	'https://products.appliedbiosystems.com/ab/en/US/adirect/ab?cmd=ABGEKeywordResults&searchBy=all&assayType=ge&searchValue=',
'MOUSEFETALMAP_V2'	=>	'http://sanlnx33.uk.pfizer.com:8777/ExpressionPortal/Rplot?DATASET=16&GENE=',
'TOXREPORTBASELINK'	=>	'ToxReport.cgi?ENTREZ=',
'TOXREPORTBASELINK2'	=>	'http://comptox.pfizer.com/cgi/ToxGene/ToxReport.cgi?ENTREZ=',
'TOOLBOX'				=>	'http://ecf.pfizer.com/sites/dsrdlajolla/dsrdadb/AssayDatabaseFilter.aspx?Organ=',
'HUM_PROT_REF_DB'		=>	'http://www.hprd.org/protein/',
'VEGA_GENOME'			=>	'http://vega.sanger.ac.uk/id/',
'HUGE_NAVIGATOR'		=>	'http://www.hugenavigator.net/HuGENavigator/huGEPedia.do?typeSubmit=GO&check=y&typeOption=gene&which=2&pubOrderType=pubD&firstQuery=x&geneID='
);
$MiscLinks{TOXREPORTBASELINK_full} = 'http://comptox.pfizer.com/cgi/' . $MiscVariables{IMAGE_PATH} . '/ToxReport.cgi?TOX_SYS_ID=1;GENE=';


%GO_Sup_Def = (
'EXP'	=>	'Inferred from Experiment',
'IDA'	=>	'Inferred from Direct Assay',
'IPI'	=>	'Inferred from Physical Interaction',
'IMP'	=>	'Inferred from Mutant Phenotype',
'IGI'	=>	'Inferred from Genetic Interaction',
'IEP'	=>	'Inferred from Expression Pattern',
'ISS'	=>	'Inferred from Sequence or Structural Similarity',
'ISO'	=>	'Inferred from Sequence Orthology',
'ISA'	=>	'Inferred from Sequence Alignment',
'ISM'	=>	'Inferred from Sequence Model',
'IGC'	=>	'Inferred from Genomic Context',
'RCA'	=>	'inferred from Reviewed Computational Analysis',
'TAS'	=>	'Traceable Author Statement',
'NAS'	=>	'Non-traceable Author Statement',
'IC'	=>	'Inferred by Curator',
'ND'	=>	'No biological Data available',
'IEA'	=>	'Inferred from Electronic Annotation',
'NR'	=>	'Not Recorded'
);

%SetupFiles = (
	'HOMOLOGENE' 		=> 	'../data/homologene.data',
	'GENE2PUBMED'  	=> 	'../data/gene2pubmed',

	'GENEINFO'  		=> 	'../data/gene_info',
	'MIM2GENE' 			=> 	'../data/mim2gene_medgen',
	'GENE2GO' 			=> 	'../data/gene2go',

	'GENEONTOL' 		=> 	'../data/go.obo',

	'MOUPHENOONT' 		=> 	'../data/MPheno_OBO.ontology',
	'MOUPHENOS' 		=> 	'../data/MGI_PhenoGenoMP.rpt',

	'MESH_TREE' 		=> 	'../data/2016MeshTree.txt',

	'ING_PATHWAYS' 	=> 	'../data/IngenuityIdList.csv',

#	'R_APPLICATION' 	=> 	'/usr/bin/R',
	'R_APPLICATION' 	=> 	'/opt2/misc_apps/R-3.0.2/bin/R',

	'PFIZER_TOX' 		=> 	'../data/static/Pfizer_Tox.0.4.obo',

	'EXP_ANN_FILES' 		=> 	'../data/static/GPL96.annot||../data/static/GPL1073.annot',
	'HUM_EXP_DATA' 		=> 	'../data/static/GDS596.soft',
	'MOU_EXP_DATA' 		=> 	'../data/static/GDS592.soft',

	'GEN_ASSOC_FILE' 		=> 	'../data/static/GAD.txt',

	'GWASCATALOG' 		=> 	'../data/gwas_catalog_v1.0-associations_e84_r2016-04-10.tsv',

	'PUBMED_CITED' 	=> 	'../data/pubmed_cited'
);

%ToolTips = (
'ToxIssues_But'		=>	'Click on this button to open the toxicity selection page. You must select a toxicity category before you select a gene so that the appropriate data can be flagged. If you select a higher level term, all items linked to that term or one of its subterms will be flagged.',
'ToxMatrix_But'		=>	'Click on this button to open the toxicity matrix page. ToxMatrix allows you to enter a list of genes using either Entrez gene IDs or GeneBook IDs. A linked heatmap of risks in a number of toxicity areas is displayed.',
'ToxAtGlance'			=>	'Tox-At-A-Glance provides a score based on the relative number of toxicty flags seen for this gene over a variety of toxicity issues. Where available, the human/mouse homolog is also shown.',
'SearchGene_But'		=>	'Once you select a toxicity, click here to search for a gene.',
'SearchMatrix_But'	=>	'Compare all selected genes for their toxicity profile via "ToxMatrix" tool.',
'Matrix_or_Individ'	=>	'Either click on the link to see the full report for this gene or click on the search button below to compare all the "checked" genes in the "ToxMatrix" tool.',
'DeriskLink'			=>	'Link to Safety Toolbox assays which may be useful to derisk the current potential issues.',
'HighFreqSNP'			=>	'Exome Variant Server indicates the coding region contains mis-sense SNP(s) which occur with high frequency within the European ancestry and/or African American population. This may result in an altered drug reponse in this population.',
''	=>	''
);

%ToolBox_2_ToxGene = (
#	Adipose
'19'	=>	'PT:0000015',

#	Cardiovascular
'Cardiovascular'	=>	'PT:0000004,PT:0000042,PT:0000043,PT:0000044,PT:0000045',
#''	=>	'PT:0000045',				#	Blood  <-> Blood_vessel
#''	=>	'PT:0000042',				#	Electrophysiology/ECG  <-> Electrophysiology
#''	=>	'PT:0000044',				#	N.A.  <-> Heart
#''	=>	'PT:0000043',				#	Hemodynamic effects (BP/HR)  <-> Hemodynamic_effects

#	Dermal
'Skin/Dermal'	=>	'PT:0000003,PT:0000038,PT:0000039,PT:0000040,PT:0000041,PT:0000099',
#''	=>	'PT:0000039',				#	Flushing  <-> Flushing
#''	=>	'PT:0000099',				#	N.A.  <-> Skin_inflammation
#''	=>	'PT:0000038',				#	Rash  <-> Skin_Rash
#''	=>	'PT:0000041',				#	Structural  <-> Structural
#''	=>	'PT:0000040',			#	Wound healing  <-> Wound_Healing

#	Endocrine <-> Endrocrine_System
'Endocrine System'	=>	'PT:0000012,PT:0000079,PT:0000080,PT:0000081,PT:0000082,PT:0000083',
#''	=>	'PT:0000080',			#	Adrenal  <-> Adrenal
'Pancreas/Gallbladder'	=>	'PT:0000083',			#	Pancreatic islets  <-> Pancreatic_Islets
#''	=>	'PT:0000081',			#	Thyroid  <-> Thyroid
#''	=>	'PT:0000079',			#	Pituitary  <-> Pituitary
#''	=>	'PT:0000082',			#	Parathyroid  <-> Parathyroid

#	Gastrointestinal <-> Gastrointestinal_System
'Gastrointestinal'	=>	'PT:0000002,PT:0000033,PT:0000034,PT:0000035,PT:0000036,PT:0000037,PT:0000094,',
#''	=>	'PT:0000034',				#	Altered Bowel Function  <-> Altered_bowel_function
#''	=>	'PT:0000033',				#	Emesis/Nausea  <-> Emesis
#''	=>	'PT:0000094',				#	N.A.  <-> Exocrine_Pancrease
#''	=>	'PT:0000037',				#	Large intestine  <-> Large_Intestine
#''	=>	'PT:0000036',				#	Small Intestine  <-> Small_Intestine
#''	=>	'PT:0000035,PT:0000002',	#	Stomach  <-> Stomach

#	 Hematopoietic <-> Hemolymphatic
'Hematopoietic'	=>	'PT:0000013,PT:0000084,PT:0000085,PT:0000086,PT:0000087,PT:0000095,PT:0000096',
#''	=>	'PT:0000084',				#	Blood <-> Blood_cell_function
#''	=>	'PT:0000085',				#	Bone marrow <-> Bone_marrow
#''	=>	'PT:0000087',				#	Coagulation system <-> Coagulation
#''	=>	'PT:0000096',				#	 <-> Lymph_nodes
#''	=>	'PT:0000086',				#	Spleen <-> Spleen
#''	=>	'PT:0000095',				#	 <-> Thymus

#	Hepatobiliary <-> Hepatobilliary_System
'Liver'	=>	'PT:0000008,PT:0000067,PT:0000068,PT:0000069,PT:0000070',
#''	=>	'PT:0000067',				#	 <-> Biliary_Enzymes
#''	=>	'PT:0000069',				#	 <-> Biliary_parenchyma
#''	=>	'PT:0000070',				#	 <-> Liver_parenchyma
#''	=>	'PT:0000068',				#	 <-> Metabolism/Liver_Enzymes

#	Immune System <-> Immune_System
'Immune%20System'	=>	'PT:0000009,PT:0000072,PT:0000073,PT:0000074,PT:0000075',
#''	=>	'PT:0000074',				#	Autoimmunity  <-> Autoimmunity
#''	=>	'PT:0000073',				#	Hypersensitivity  <-> Hypersensitivity
#''	=>	'PT:0000072',				#	Immune modulation <-> Immune_Modulation
#''	=>	'PT:0000075',				#	Immunogenicity  <-> Immunogenicity

#	  <-> Musculoskeletal_System
#''	=>	'PT:0000011,PT:0000076,PT:0000077,PT:0000078',
'Bone'	=>	'PT:0000011,PT:0000076',			#	Bone <-> Bone
#''	=>	'PT:0000077',				#	 <-> Joint/Cartilage
'Muscle'	=>	'PT:0000011,PT:0000078',			#	Muscle  <-> Skeletal_muscle

#	  <-> Nervous_System
'Neural'	=>	'PT:0000005,PT:0000046,PT:0000047,PT:0000049,PT:0000050,PT:0000052,PT:0000054,PT:0000091,PT:0000092,PT:0000093',
#''	=>	'PT:0000046',			#	Abuse potential  <-> Abuse_potential
#''	=>	'PT:0000052',			#	Behavioral/activity  <-> Altered_Behavior/Activity/Sedation
#''	=>	'PT:0000091',				#	  <-> Brain
#''	=>	'PT:0000049',				#	Seizures/Tremors/Dizziness  <-> Dizziness/Ataxia
#''	=>	'PT:0000054',				#	Memory/Cognition  <-> Memory/Cognition
#''	=>	'PT:0000050',			#	 Motor <-> Motor/Tremors
#''	=>	'PT:0000093',				#	  <-> Peripheral_Nerve/Ganglion
#''	=>	'PT:0000047',				#	  <-> Seizures
#''	=>	'PT:0000092',				#	  <-> Spinal_cord

#	Ocular
'Ocular'	=>	'PT:0000014,PT:0000088,PT:0000089,PT:0000097,PT:0000098',
#''	=>	'PT:0000097',				#	  <-> Altered_vision
#''	=>	'PT:0000089',				#	Cataracts  <-> Lens
#''	=>	'PT:0000098',				#	  <-> Other_ocular_structures
#''	=>	'PT:0000088',				#	Retinal  <-> Retina

#	Ototoxicity/Olfactory  <-> Ototoxicity or Olfactory
'Ototoxicity'	=>	'PT:0000016,PT:0000017',

#	Lung/Respiratory  <-> Pulmonary_System
'Lung/Respiratory'	=>	'PT:0000007,PT:0000059,PT:0000060,PT:0000064,PT:0000065,PT:0000066',
#''	=>	'PT:0000066',				#	  <-> Larynx
#''	=>	'PT:0000064',				#	  <-> Lung
#''	=>	'PT:0000060',			#	 Lung Function (TV/RR) <-> Lung_Function
#''	=>	'PT:0000059',				#	  <-> Nasal
#''	=>	'PT:0000065',				#	  <-> Trachea

#	Renal
'Kidney/Renal'	=>	'PT:0000006,PT:0000055,PT:0000056,PT:0000057,PT:0000058',
#''	=>	'PT:0000056',				#	Bladder  <-> Bladder/Urinary_tract
#''	=>	'PT:0000055',				#	  <-> Kidney
#''	=>	'PT:0000058',				#	Urinary composition  <-> Urinary_composition
#''	=>	'PT:0000057',				#	Urination (diuresis, etc)  <-> Urination

#	Reproductive
'Testis/Ovary/Reproductive'	=>	'PT:0000010,PT:0000030,PT:0000031,PT:0000032',
#''	=>	'PT:0000031',				#	Female Tract  <-> Female_tract
#''	=>	'PT:0000030',				#	Male Tract  <-> Male_tract
#''	=>	'PT:0000032',				#	Fetal/Developmental  <-> Fetal/Developmental

''	=>	''				#	Blank
);

1;
