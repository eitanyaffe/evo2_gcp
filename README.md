# Evo2 on Google Cloud Platform

This repo runs the Evo2 model on the Google Cloud. It simplifies the process, by uploading all relevant files to a Google bucket, running Evo 2 in Docker container on a cloud machine with one or more GPUs, and downloading the results.

## Overview

The system uses a `makefile` to orchestrate the different steps involved:

1.  **Docker Image Management**: Building a local Docker image with the necessary environment and pushing it to Google Container Registry (GCR).
2.  **GCS Bucket Preparation**: Creating a dedicated GCS bucket and uploading the pre-trained model and runtime scripts.
3.  **Job Preparation**:
    *   Uploading an input FASTA file to a job-specific directory in the GCS bucket.
    *   Generating a JSON configuration file (`job.json`) that defines the batch job parameters, including the Docker image to use, environment variables, machine type, GPU requirements, and data paths.
4.  **Job Submission**: Submitting the configured job to Google Cloud Batch.
5.  **Monitoring**: Providing commands to list and monitor jobs.
6. **Downloading**: Downloading the Evo 2 results.  

## Prerequisites

*   Google Cloud SDK (`gcloud`, `gsutil`) installed and configured.
*   Docker installed and running.
*   Access to a Google Cloud Project with Batch API, Compute Engine API, and Cloud Storage API enabled.

## Makefile Structure and Customization

The `makefile` is the central control point for this project. You can customize various aspects of the job submission by modifying the variables defined in the file.

### Key Makefile Variables for Customization

Here are some of the most important variables you might want to change:

#### 1. Input Data

*   `JOB`: A unique user-specified job identifier.
*   `INPUT_FASTA`: Specifies the path to the input FASTA file.
    *   Default: `examples/test.fasta`
    *   This file will be uploaded to `gs://$(BUCKET_NAME)/jobs/$(JOB_TAG)/input.fasta` before the job starts.

#### 2. Google Cloud Parameters

*   `BUCKET_NAME`: The name of the GCS bucket used for storing models, scripts, input data, and outputs.
    *   Default: `relman-evo2`
*   `LOCATION`: The GCP region where the bucket will be created and where the batch jobs will run.
    *   Default: `us-central1`
*   `MACHINE_TYPE`: The type of GCP Compute Engine machine to use for the batch job.
    *   Default: `a3-highgpu-1g` (an A3 machine with 1 H100 GPU)
*   `ACCELERATOR_TYPE`: The type of GPU accelerator to attach to the machine.
    *   Default: `nvidia-h100-80gb`
*   `ACCELERATOR_COUNT`: The number of GPUs to attach.
    *   Default: `1`

#### 2. Runtime Parameters and Output Configuration

*   `MODEL_NAME`: The short name of the model to be used (e.g., `evo2_7b`).
    *   Default: `evo2_7b`
*   `OUTPUT_TYPES`: Specifies the types of output to generate. This can be a comma-separated list (though the current example `run_evo.py` might expect a single string or be adapted). Common values could be `logits`, `embeddings`, or both. The `run_evo.py` script will need to be written or modified to handle these types.
    *   Default: `logit`

### Main Makefile Targets

*   `make docker_image`: Builds the local Docker image and pushes it to GCR.
*   `make create_bucket`: Creates the GCS bucket specified by `BUCKET_NAME`.
*   `make upload_model`: Downloads the specified model and uploads it to `gs://$(BUCKET_NAME)/models/$(MODEL_NAME)`.
*   `make upload_code`: Uploads the contents of the `scripts` and `configs` directories to GCS.
*   `make build_json`: Generates the `job.json` configuration file for a job.
*   `make upload_fasta`: Uploads the `INPUT_FASTA` of the job file to GCS.
*   `make submit`: Submits the job to GCP Batch.
*   `make list_jobs`: Lists active batch jobs.
*   `make download`: Gets results for a job.

## Running a Job

1.  **Configure Makefile**: Update the variables in the `makefile` (especially `BUCKET_NAME`, `DOCKER_IMAGE`, `MODEL_NAME`, `INPUT_FASTA`, `JOB`) to match your GCP project, desired model, and input data.
2.  **Build Docker Image**:
    ```bash
    make docker_image
    ```
3.  **Prepare GCS Bucket (One-time or if content changes)**:
    ```bash
    make create_bucket  # If the bucket doesn't exist
    make upload_model
    make upload_code
    ```
4.  **Submit a Job**:
    ```bash
    make submit
    ```
    This will:
    *   Upload your FASTA file (`make upload_fasta`).
    *   Generate the `job.json` (`make build_json`).
    *   Submit the job to Google Cloud Batch.

5.  **Monitor Job**:
    ```bash
    make list_jobs
    ```
    You can also check the job status and logs in the Google Cloud Console under the Batch section.

6.  **Download Output**:
    Once the job is complete, you can download the results using:
    ```bash
    make download
    ```
