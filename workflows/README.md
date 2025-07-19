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

### `strands/` - Reverse Complement Analysis Pipeline

A comprehensive pipeline for analyzing codon variants to compare evolutionary pressures between DNA strands.

**Purpose**: Compares variant likelihoods between forward and reverse complement sequences to understand strand-specific evolutionary constraints.

**Key Features**:
- Generates all possible codon variants at specified amino acid positions
- Analyzes both forward (plus) and reverse complement (minus) strands
- Calculates log-likelihood scores from Evo2 model predictions
- Creates comparative visualizations

**Documentation**: See [`strands/README.md`](strands/README.md) for detailed usage instructions.

**Quick Start**:
```bash
cd workflows/strands
./runner.sh 83  # Analyze position 83
```

## Workflow Structure

Each workflow follows a standard structure:

```
workflow_name/
├── README.md or workflow_name.md  # Workflow documentation
├── runner.sh                      # Main pipeline script
├── scripts/                       # Analysis scripts
├── input/                         # Input data and templates
├── output/                        # Generated results (created during runs)
└── figures/                       # Generated plots (created during runs)
```

## Requirements

All workflows require:
- Configured Evo2 GCP environment (see main README)
- Workflow-specific dependencies (documented in each workflow)
- Appropriate cloud resources and permissions

## Adding New Workflows

To contribute a new workflow:

1. Create a new subdirectory with a descriptive name
2. Follow the standard workflow structure above
3. Include comprehensive documentation
4. Ensure the workflow integrates properly with the Evo2 GCP infrastructure
5. Update this README to include your workflow in the "Available Workflows" section 