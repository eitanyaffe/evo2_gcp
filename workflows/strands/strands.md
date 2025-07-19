# Reverse Complement Analysis Pipeline

## Overview
This pipeline analyzes codon variants at a specific amino acid position to compare variant likelihoods between strands.

## Files and Functions

### Core Pipeline
- `runner.sh` - Main pipeline script that orchestrates all steps
- `input/gene_variants.fasta` - Input gene sequences for analysis
- `input/codon_table` - Codon to amino acid mapping table

### Scripts
- `scripts/generate_codon_variants.py` - Generates all 2x64 possible codon variants at specified position, creating both forward (P) and reverse complement (M) sequences
- `scripts/create_strand_table.r` - Calculates log-likelihood scores for plus and minus strands from model predictions
- `scripts/plot_strand_scatter.r` - Creates scatter plot comparing plus vs minus strand preferences with codon labels
- `scripts/utils.r` - Utility functions for R scripts

### Input/Output
- **Input**: Gene sequences (`input/gene_variants.fasta`) and codon table (`input/codon_table`)
- **Output**: 
  - `output/query_<POS>.fasta` - Codon variants fasta
  - `output/query_<POS>.tab` - Original codon information
  - `output/compare_strands_<POS>.tab` - Strand comparison table
  - `figures/P_vs_M_strands_<POS>.pdf` - Output scatter plot

## Pipeline Steps
1. Generate all 2x64 codon variants at specified position (both forward and reverse complement)
2. Submit variants to cloud evolutionary model service (`evo_gcp`)
3. Download model predictions as logit files
4. Calculate log-likelihood scores for plus and minus strands
5. Create scatter plot comparing strand preferences

## Usage
Run the pipeline with a position parameter:
```bash
./runner.sh <POS>
```

Where `<POS>` is the amino acid coordinate (1-based) you want to analyze.

**Example:**
```bash
./runner.sh 83
```

This will analyze all codon variants at amino acid position 83 and generate results in the `output/` and `figures/` directories. 