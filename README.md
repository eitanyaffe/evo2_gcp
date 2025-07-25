# Evo2 on Google Cloud

This repository provides tools to run the Evo2 model on Google Cloud. It features a command-line wrapper, `evo_gcp.py`, that simplifies building a Docker container, managing cloud storage, submitting jobs to Google Cloud Batch, and downloading results.

## Prerequisites

1.  **[Google Cloud SDK](https://cloud.google.com/sdk/docs/install)**: `gcloud` and `gsutil` must be installed. Make sure you are authenticated:
    ```bash
    gcloud auth login
    ```
2.  **[Docker](https://docs.docker.com/engine/install/)**: The Docker daemon must be installed and running. On macOS, you can start Docker by running:
    ```bash
    open -a Docker
    ```
3.  **Python 3**: Required for the `evo_gcp.py` wrapper.
4.  **GCP Project**: You need a Google Cloud Project with the necessary APIs and permissions enabled. See [docs/google.md](./docs/google.md) for instructions on enabling APIs and setting up user roles.

The tool was tested on macOS 13.3.1 with Python 3.9.6 and Docker 28.2.2.

### Google Cloud Configuration

Set up your Google Cloud environment:

```bash
# Initialize gcloud and log in
gcloud init

# Authorize application-level credentials (used by scripts/libraries)
gcloud auth application-default login
```

### Python Dependencies

Install the required Python packages:
```bash
pip install --upgrade huggingface-hub google google-api-python-client google-cloud-storage
```

## Installation

First, clone the repository to your local machine:
```bash
git clone git@github.com:eitanyaffe/evo2_gcp.git
cd evo2_gcp
```

### Environment Variable

The wrapper script needs to know the location of this repository. Set the `EVO_GCP_DIR` environment variable to the absolute path of the project's root directory.

Add this line to your shell's configuration file (e.g., `~/.zshrc`, `~/.bash_profile`):
```bash
export EVO_GCP_DIR=/path/to/your/evo2_gcp
```
Remember to reload your shell (e.g., `source ~/.zshrc`) or open a new terminal for the change to take effect.

> [!TIP]
> To determine which shell you are using, run `echo $SHELL` in your terminal. Common shells include:
> - `/bin/zsh` (Zsh - default on macOS Catalina and later)
> - `/bin/bash` (Bash - default on many Linux distributions)
> - `/bin/sh` (Bourne shell)
> 
> Once you know your shell, you can add the environment variable to the appropriate configuration file:
> - For Zsh: `~/.zshrc`
> - For Bash: `~/.bash_profile` or `~/.bashrc`
> - For other shells: check their documentation for the correct configuration file

### Project Settings (`config.mk`)

You can configure project-wide settings, such as the Google Cloud region and bucket name, by editing the `config.mk` file. These values can also be overridden at runtime using command-line arguments (e.g., `--region <REGION>`).

### Install Wrapper (Optional)

For convenience, you can install the `evo_gcp.py` script to a system directory, allowing you to run it from anywhere.
```bash
# This may require superuser privileges
make install
```
This installs the script as `evo_gcp`. If you choose not to install it, you can run it directly from the repository root as `./evo_gcp.py`. To see a full list of commands and options, run `evo_gcp --help`.

## Workflow

The typical workflow involves a one-time setup followed by running jobs.

### 1. One-Time Setup

First, build the Docker image and set up the Google Cloud Storage bucket. This prepares your cloud environment, uploads the Evo2 model, and syncs the source code.

To build the docker image run:
```bash
# Build the Docker image and push it to Google Container Registry
evo_gcp docker_image
```
> [!TIP]
> Building the image is time consuming. If you have access to an existing one you can skip this step by setting `DOCKER_IMAGE` in the `config.mk` file.

To prepare the bucket run:
```bash
# Create the GCS bucket and upload the model and code
evo_gcp setup_bucket
```

### 2. Running a Job

To run the model, submit a job with a name and an input FASTA file. The primary input for the model is a FASTA file, which must be specified for each job using the `--input_fasta` flag.

```bash
# Submit a job and wait for it to complete
evo_gcp submit --job my-first-run --input_fasta examples/gyrA_sensitive.fasta --wait
```

The `--wait` flag makes the command block until the job finishes. If you run a job without it, you can monitor its status using the following commands.

### 3. Monitoring Jobs

List all active jobs:
```bash
evo_gcp list_jobs
```

View the remote files for a specific job:
```bash
evo_gcp show --job my-first-run
```

### 4. Downloading Results

Once a job has succeeded, download its output files.
```bash
evo_gcp download --job my-first-run
```
By default, results are downloaded to `jobs/<JOB_NAME>/output`. You can specify a different parent directory with the `--jobs_dir` argument:
```bash
evo_gcp download --job my-first-run --jobs_dir /path/to/your/jobs
```
This would save results to `/path/to/your/jobs/my-first-run/output`.


### 5. Understanding Output Files

When a job completes successfully, the output directory contains several files:

- **`<input_basename>_summary_table.txt`**: A summary table containing metadata for all processed sequences with columns: `seq_id`, `start`, `end`, `total_log_likelihood`. The start and end coordinates show the genomic regions that were analyzed (either from the query table or full sequence), and the total log-likelihood provides an overall score for each sequence.

- **`<input_basename>_<sequence_id>_logits.npy`**: For each sequence in your input FASTA file, a NumPy file containing the model's logits (raw output scores). The filename includes the sequence identifier from the FASTA header. If a query table is provided, logits are restricted to the specified coordinate ranges.

- **`<input_basename>_<sequence_id>_embeddings_<layer_name>.npy`**: If you requested embeddings (using `--output_type logits_and_embedding` or `--output_type embedding`), additional NumPy files containing the embeddings from the specified layers. The filename includes both the sequence identifier and the layer name. If a query table is provided, embeddings are restricted to the specified coordinate ranges.

For example, if your FASTA contains a sequence with header `>Ecoli_gyrA_WT` and you requested both logits and embeddings from the `blocks.28.mlp.l3` layer, you would get:
- `input_Ecoli_gyrA_WT_logits.npy` - the logits for this sequence
- `input_Ecoli_gyrA_WT_embeddings_blocks_28_mlp_l3.npy` - the embeddings from the specified layer

The output files generated depend on your `OUTPUT_TYPE` setting: `logits` (logits only), `logits_and_embedding` (both), `embedding` (embeddings only), or `summary_only` (summary table only).

## Query Table Feature

The system supports an optional **query table** that allows you to specify which genomic regions to analyze for each sequence. This reduces file output sizes by restricting logits and embeddings to specified coordinate ranges, while total log-likelihood is still calculated for the entire sequence.

### Query Table Format

The query table is a TSV (tab-separated values) file with three columns:
- `seq_id`: Sequence identifier (must match FASTA headers)
- `start`: Start position (1-indexed, inclusive)
- `end`: End position (1-indexed, inclusive)

Example (`examples/test_query.tsv`):
```
seq_id	start	end
seq1	5	15
seq2	1	10
```

### Using Query Tables

You can specify a query table either globally in `config.mk` or per-job:

**Global Configuration:**
```makefile
# in config.mk
QUERY_TABLE?=examples/my_query.tsv
```

**Per-Job:**
```bash
evo_gcp submit --job my-job --input_fasta examples/test.fasta --query_table examples/test_query.tsv
```

## Parameters

You can customize the behavior of `evo_gcp` by modifying its parameters. There are two ways to set them:

1.  **Global Configuration (`config.mk`)**: For settings that you want to apply to all jobs, edit the `config.mk` file. This is the best way to set project-wide defaults like your `GCP_PROJECT` or preferred `MACHINE_TYPE`.
2.  **Command-Line Arguments**: For settings specific to a single command, you can override any variable from `config.mk`. The command-line flag is generated by converting the variable name to lowercase and prepending `--`. For example, `MODEL_NAME` becomes `--model_name`.

### Examples

**Per-Job Change (Command-Line)**

If you want to run a job with a specific input file without changing the default, use the `--input_fasta` flag:

```bash
evo_gcp submit --job my-sensitive-run --input_fasta examples/gyrA_sensitive.fasta
```

**Global Change (`config.mk`)**

If you want to use a different model for all subsequent jobs, you can change the `MODEL_NAME` in `config.mk`:
```makefile
# in config.mk
...
MODEL_NAME?=evo2_40b
...
```
Now, any `evo_gcp submit` command will use `evo2_40b` unless overridden by the `--model_name` flag.

### Available Parameters

Here is a list of all available parameters and their descriptions (see `config.mk`).

#### Google and docker parameters ####

| Variable               | Description                                                 |
| ---------------------- | ----------------------------------------------------------- |
| `GCP_PROJECT`          | GCP project ID.                                             |
| `LOCATION`             | GCP location for the bucket and batch jobs.                 |
| `IMAGE_NAME`           | Short Docker image name.                                    |
| `UBUNTU_VERSION`       | Docker image Ubuntu version.                                |
| `CUDA_VERSION`         | Docker image CUDA version.                                  |
| `DOCKER_IMAGE`         | Full Docker image name for Google Container Registry.       |
| `BUCKET_NAME`          | Google Cloud Storage bucket name.                           |

#### General evo parameters ####

| Variable               | Description                                                 |
| ---------------------- | ----------------------------------------------------------- |
| `MODEL_NAME`           | The Evo 2 model name to use.                                |
| `MACHINE_TYPE`         | The GCP machine type for the job (e.g., `a3-highgpu-1g`).   |
| `ACCELERATOR_TYPE`     | The accelerator type (e.g., `nvidia-h100-80gb`).            |
| `ACCELERATOR_COUNT`    | The number of accelerators to attach.                       |

#### Job-specific parameters ####

| Variable               | Description                                                 |
| ---------------------- | ----------------------------------------------------------- |
| `JOB`                  | A unique string identifier for a job.                       |
| `JOB_VERSION`          | The job version, allowing the same job to be run multiple times. |
| `INPUT_FASTA`          | The input FASTA file for a job.                             |
| `QUERY_TABLE`          | Optional TSV file specifying genomic regions to analyze for each sequence. |
| `WAIT`                 | When used with `submit`, blocks until the job completes.    |
| `OUTPUT_TYPE`          | Type of output to generate: `logits`, `logits_and_embedding`, `embedding`, or `summary_only`. |
| `EMBEDDING_LAYERS`     | Specific layers to use for embeddings (required when OUTPUT_TYPE includes embeddings). |
| `JOBS_DIR`             | The local directory for storing downloaded job results.     |

## Implementation Details

The `evo_gcp.py` script is a user-friendly wrapper around a `makefile`. It reads variables from `config.mk` and makes them available as command-line arguments. For example, `evo_gcp submit --job test` constructs and executes the corresponding `make` command (`make submit JOB=test`) behind the scenes.

This design provides a simple, accessible interface without requiring knowledge of `make` syntax. For a detailed explanation of the `makefile` implementation, see [docs/makefile.md](./docs/makefile.md).

## Key Files and Directories

-   `evo_gcp.py`: The main command-line wrapper for interacting with Google Cloud.
-   `makefile`: Defines the core commands for building, deploying, and managing jobs.
-   `config.mk`: Contains default configuration variables (e.g., `PROJECT_ID`, `BUCKET_NAME`).
-   `jobs/`: The default local directory for storing downloaded job results.
-   `examples/`: Contains sample FASTA files for testing.
-   `workflows/`: Analysis workflows (pipelines). See [`workflows/README.md`](workflows/README.md).
-   `docs/`: Contains additional documentation.

## Version History

### Development (v0.91)
- **Query Table Feature**: Added support for optional TSV query tables to restrict analysis to specific genomic coordinate ranges, with logits and embeddings respecting the specified boundaries
- **Output Type System**: Replaced `INCLUDE_EMBEDDING` with `OUTPUT_TYPE` parameter supporting four modes: `logits`, `logits_and_embedding`, `embedding`, `summary_only`
- **Summary Tables**: Added automatic generation of summary tables with sequence metadata and total log-likelihood scores
- **Analysis Workflows**: Added `workflows/` directory with specialized analysis workflows, starting with strand comparison analysis
- **Docker Updates**: Changed base image to `nvidia/cuda` and added explicit `linux/amd64` platform specification
- **Installation Changes**: Modified default install location from `/usr/local/bin` to `~/.local/bin` for user-local installation

