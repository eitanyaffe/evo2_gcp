# Evo2 on Google Cloud

This repository provides tools to run the Evo2 model on Google Cloud. It features a command-line wrapper, `evo_gcp.py`, that simplifies building a Docker container, managing cloud storage, submitting jobs to Google Cloud Batch, and downloading results.

## Prerequisites

1.  **[Google Cloud SDK](https://cloud.google.com/sdk/docs/install)**: `gcloud` and `gsutil` must be installed. Make sure you are authenticated:
    ```bash
    gcloud auth login
    ```
2.  **[Docker](https://docs.docker.com/engine/install/)**: The Docker daemon must be installed and running.
3.  **Python 3**: Required for the `evo_gcp.py` wrapper.
4.  **GCP Project**: You need a Google Cloud Project with the necessary APIs and permissions enabled. See [docs/google.md](./docs/google.md) for instructions on enabling APIs and setting up user roles.

## Configuration

### Environment Variable

The wrapper script needs to know the location of this repository. Set the `EVO_GCP_DIR` environment variable to the absolute path of the project's root directory.

Add this line to your shell's configuration file (e.g., `~/.zshrc`, `~/.bashrc`):
```bash
export EVO_GCP_DIR=/path/to/your/evo2_gcp
```
Remember to reload your shell (`source ~/.zshrc`) or open a new terminal for the change to take effect.

### Project Settings (`config.mk`)

You can configure project-wide settings, such as the Google Cloud region and bucket name, by editing the `config.mk` file. These values can also be overridden at runtime using command-line arguments (e.g., `--region <REGION>`).

## Installation (Optional)

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

```bash
# Build the Docker image and push it to Google Container Registry
evo_gcp docker_image

# Create the GCS bucket and upload the model and code
evo_gcp setup_bucket
```
You can override the default bucket name during setup:
```bash
evo_gcp setup_bucket --bucket_name my-project-bucket
```

### 2. Running a Job

To run the model, submit a job with a name and an input FASTA file.

```bash
# Submit a job and wait for it to complete
evo_gcp submit --job my-first-job --input_fasta examples/test.fasta --wait
```

The `--wait` flag makes the command block until the job finishes. If you run a job without it, you can monitor its status using the following commands.

### 3. Monitoring Jobs

List all active jobs:
```bash
evo_gcp list_jobs
```

View the remote files and status for a specific job:
```bash
evo_gcp show --job my-first-job
```

### 4. Downloading Results

Once a job has succeeded, download its output files.
```bash
evo_gcp download --job my-first-job
```
By default, results are downloaded to `jobs/<JOB_NAME>/output`. You can specify a different parent directory with the `--jobs_dir` argument:
```bash
evo_gcp download --job my-first-job --jobs_dir /path/to/your/jobs
```
This would save results to `/path/to/your/jobs/my-first-job/output`.

## Implementation Details

The `evo_gcp.py` script is a user-friendly wrapper around a `makefile`. It reads variables from `config.mk` and makes them available as command-line arguments. For example, `evo_gcp submit --job test` constructs and executes the corresponding `make` command (`make submit JOB=test`) behind the scenes.

This design provides a simple, accessible interface without requiring knowledge of `make` syntax. For a detailed explanation of the `makefile` implementation, see [docs/makefile.md](./docs/makefile.md).

## Key Files and Directories

-   `evo_gcp.py`: The main command-line wrapper for interacting with Google Cloud.
-   `makefile`: Defines the core commands for building, deploying, and managing jobs.
-   `config.mk`: Contains default configuration variables (e.g., `PROJECT_ID`, `BUCKET_NAME`).
-   `jobs/`: The default local directory for storing downloaded job results.
-   `examples/`: Contains sample FASTA files for testing.
-   `docs/`: Contains additional documentation.
