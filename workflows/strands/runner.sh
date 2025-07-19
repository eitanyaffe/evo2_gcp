#!/bin/bash

# position to analyze, the only parameter in this bash script
export POS=$1
echo "generating codon variants at position $POS"

# generate all codon variants at position 83
mkdir -p output
python3 scripts/generate_codon_variants.py \
	--fasta input/gene_variants.fasta \
	--codon-table input/codon_table \
	--aa-coord $POS \
	--seq-id 83_S1 \
	--output-fasta output/query_$POS.fasta \
	--output-codon-table output/query_$POS.tab

# submit job
evo_gcp submit --job rc-job \
  --output_type logits \
  --input_fasta `pwd`/output/query_$POS.fasta \
	--job_version $POS \
  --wait

# create job directory
mkdir -p jobs/rc-job-$POS

# download job results
evo_gcp download --job rc-job --job_version $POS --jobs_dir `pwd`/jobs

# crete strand comparison table
Rscript -e "
library(reticulate)
use_python(Sys.which('python3'), required=TRUE)
source('scripts/create_strand_table.r')
create_strand_table(
  ifn='output/query_$POS.fasta',
  idir='jobs/rc-job-$POS/output',
  ofn='output/compare_strands_$POS.tab')
"

# plot strand comparison
Rscript -e "
source('scripts/plot_strand_scatter.r')
plot_strand_scatter(
  ifn_tab='output/compare_strands_$POS.tab', 
  ifn_codon='output/query_$POS.tab',
	title=$POS,
  fdir='figures')
"
