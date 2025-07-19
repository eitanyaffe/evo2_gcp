# Evo2 Analysis Workflows

This directory contains specialized analysis workflows that build on top of the core Evo2 GCP infrastructure to perform specific biological analyses.

## Overview

Each workflow is designed to address a particular research question or analysis type using the Evo2 model. Workflows are implemented in bash for simplicity and portability, making them easy to adapt to other workflow management systems (e.g., Snakemake, Nextflow, WDL).

Workflows are organized into subdirectories, each containing:

- Complete analysis pipeline scripts
- Input data files and templates
- Documentation specific to that workflow
- Output directories for results

## Available Workflows

### `strands/` - Strand Analysis Pipeline

An example pipeline for analyzing codon variants to compare DNA strands. By default, focuses on the *gyrA* gene in *E. coli* as an example that can be easily modified for other genes/organisms.

See [`strands/README.md`](strands/README.md) for detailed usage instructions.

**Quick Start**:
```bash
cd workflows/strands
./runner.sh 83  # Analyze amino acid position 83
```

## Customizing or Creating New Workflows

To create your own workflow, copy an existing workflow directory (or parts of it) to your own working location. Edit the scripts and input files as needed for your analysis. You should run workflows from your own directories rather than modifying the originals.