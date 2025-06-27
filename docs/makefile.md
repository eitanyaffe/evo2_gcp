# Makefile Deep Dive

This document provides a detailed look into the `makefile` that underpins the operations in this repository. While the `evo_gcp.py` wrapper is the recommended way to interact with the system, this file offers a lower-level understanding for those who want to customize or extend the core logic.

## Overview

The `makefile` orchestrates the different steps involved in running Evo2 on Google Cloud:

1.  **Docker Image Management**: Building a local Docker image and pushing it to Google Container Registry (GCR).
2.  **GCS Bucket Preparation**: Creating a GCS bucket and uploading the model and scripts.
3.  **Job Preparation**: Uploading an input FASTA file and generating a `job.json` configuration.
4.  **Job Submission**: Submitting the job to Google Cloud Batch.
5.  **Monitoring**: Providing commands to list and monitor jobs.
6.  **Downloading**: Downloading the Evo 2 results.  

## Makefile Structure and Customization

You can customize the behavior by modifying the variables in `config.mk` and `extra.mk`.

### Key Makefile Variables (`config.mk`)

*   `JOB`: A unique user-specified job identifier.
*   `INPUT_FASTA`: Path to the input FASTA file (Default: `examples/test.fasta`).
*   `BUCKET_NAME`: The GCS bucket name (Default: `relman-evo2`).
*   `LOCATION`: The GCP region for the bucket and jobs (Default: `us-central1`).
*   `MACHINE_TYPE`: The Compute Engine machine type (Default: `a3-highgpu-1g`).
*   `ACCELERATOR_TYPE`: The GPU accelerator type (Default: `nvidia-h100-80gb`).
*   `ACCELERATOR_COUNT`: The number of GPUs (Default: `1`).
*   `MODEL_NAME`: The short name of the model to be used (Default: `evo2_7b`).

These variables can be overridden on the command line when calling `make`. For example: `make submit JOB=my-new-job`.

### Main Makefile Targets

*   `make docker_image`: Builds the local Docker image and pushes it to GCR.
*   `make create_bucket`: Creates the GCS bucket specified by `BUCKET_NAME`.
*   `make upload_model`: Downloads the specified model and uploads it to GCS.
*   `make upload_code`: Uploads the `scripts` and `configs` directories to GCS.
*   `make build_json`: Generates the `job.json` configuration file for a job.
*   `make upload_fasta`: Uploads the `INPUT_FASTA` file to GCS.
*   `make submit`: Submits the job to GCP Batch. This target has dependencies and will run `upload_code`, `upload_fasta`, and `build_json` first. You can also pass `WAIT=true` to make the command wait for the job to complete (e.g., `make submit WAIT=true`).
*   `make list_jobs`: Lists active batch jobs.
*   `make show`: Shows the contents of a job's remote directory.
*   `make download`: Downloads the results for a job.
*   `make install`: Installs the `evo_gcp.py` wrapper to `/usr/local/bin`.
*   `make uninstall`: Removes the `evo_gcp.py` wrapper. 