# Evo2 on Google Cloud Platform

This repository simplifies running the Evo2 model on Google Cloud, a suite of public cloud computing services offered by Google. It provides a command-line wrapper, `evo_gcp.py`, to build a Docker container, manage cloud storage, submit jobs to Google Cloud Batch, and download the results.

## Prerequisites

1.  **[Google Cloud SDK](https://cloud.google.com/sdk/docs/install)**: `gcloud` and `gsutil` must be installed and authenticated.
2.  **[Docker](https://docs.docker.com/engine/install/)**: The Docker daemon must be installed and running.
3.  **Python 3**: Required for the `evo_gcp.py` wrapper.
4.  **GCP Project**: You need a Google Cloud Project with the Batch, Compute Engine, and Cloud Storage APIs enabled. See [google.md](./google.md) for setup details.

## Quickstart: Installation and Setup

### 1. Set the Environment Variable

The wrapper script needs to know the location of this repository. Set the `EVO_GCP_DIR` environment variable to the absolute path of the project's root directory.

Add the following line to your shell's configuration file (e.g., `~/.zshrc`, `~/.bashrc`):
```bash
export EVO_GCP_DIR=/path/to/your/evo2_gcp
```
Remember to reload your shell (`source ~/.zshrc`) or open a new terminal for the change to take effect.

### 2. Install the Wrapper (Optional)

For convenience, you can install the `evo_gcp.py` script to a system directory, allowing you to run it from anywhere.
```bash
# This may require superuser privileges
make install
```
This will install the script as `evo_gcp`. If you choose not to install it, you can run it directly from the repository root as `./evo_gcp.py`.

## The `evo_gcp.py` Script

The `evo_gcp.py` script orchestrates the entire workflow for running Evo2 on Google Cloud. It simplifies the process by wrapping a series of `make` commands and providing a clear command-line interface. Here's a breakdown of the main steps it manages:

1.  **Cloud Storage Setup (`setup_bucket`)**: The first step is to create a Google Cloud Storage (GCS) bucket. This bucket acts as a central repository for the Evo2 model, the project source code, and all job-related data, including inputs and outputs.

2.  **Docker Image Creation (`docker_image`)**: The script builds a Docker image that contains the complete Evo2 environment and all its dependencies. This image is then pushed to the Google Container Registry, making it available for cloud-based execution.

3.  **Job Submission (`submit`)**: When you submit a job, `evo_gcp.py` handles several actions:
    *   It uploads your input FASTA file to the GCS bucket.
    *   It submits a new job to Google Cloud Batch.
    *   The Batch job pulls the Docker image, runs the Evo2 model on your input data, and saves the results back to the GCS bucket.

4.  **Downloading Results (`download`)**: After a job completes, you can use the `download` command to retrieve the output files from the GCS bucket to your local machine.

To see a full list of commands and their descriptions, run:
```bash
evo_gcp
```

In terms of implementation, `evo_gcp.py` is a user-friendly wrapper around a `makefile`. It reads variables from `config.mk` (such as `JOB`, `BUCKET_NAME`, etc.) and makes them available as command-line arguments (e.g., `--job`, `--bucket_name`). When you run a command like `evo_gcp submit --job test`, the script constructs and executes the corresponding `make` command (`make submit JOB=test`) behind the scenes. This provides a simpler interface without needing to know `make` syntax. For a detailed explanation of the underlying `makefile` implementation, see [makefile.md](./makefile.md).

## Running a Job: Step-by-Step

### 1. Build the Docker Image (One-Time)

First, build the Docker image and push it to Google Container Registry.
```bash
evo_gcp docker_image
```

### 2. Initial Project Setup (One-Time per Project)

Next, you need to create the GCS bucket and upload the model and code. 
```bash
evo_gcp setup_bucket
```

You can override the default bucket name.
```bash
evo_gcp setup_bucket --bucket_name my-project-bucket
```

### 3. Submit a Job

Now you can submit a job. You must specify a job name and an input FASTA file. Use the `--wait` flag to make the command block until the job is finished.
```bash
evo_gcp submit --job my-first-job --input_fasta examples/test.fasta --wait
```

### 4. Monitor Jobs

Monitoring is only necessary for jobs submitted without the `--wait` flag, which run asynchronously.

You can list all active jobs:
```bash
evo_gcp list_jobs
```
Or view the remote files for a specific job:
```bash
evo_gcp show --job my-first-job
```

### 5. Download Results

Once the job has succeeded, download the output files.
```bash
evo_gcp download --job my-first-job
```
By default, the results will be downloaded to `jobs/my-first-job/output` in your current directory. You can specify a different parent directory with the `--jobs_dir` argument:
```bash
evo_gcp download --job my-first-job --jobs_dir /path/to/your/jobs
```
With this command, the results would be saved to `/path/to/your/jobs/my-first-job/output`.
