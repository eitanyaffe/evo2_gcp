#####################################################################################
# docker image
#####################################################################################

# local docker image name
IMAGE_NAME?=evo2

# docker image CUDA version
CUDA_VERSION?=12.4.1

# docker image Ubuntu version
UBUNTU_VERSION?=22.04

# GCP project
GCP_PROJECT?=relman-yaffe

# docker image name
DOCKER_IMAGE?=gcr.io/$(GCP_PROJECT)/$(USER)/evo2:$(UBUNTU_VERSION)_$(CUDA_VERSION)

# docker image tag
DOCKER_TAG?=latest

#####################################################################################
# GCP paths
#####################################################################################

# bucket name
BUCKET_NAME?=$(GCP_PROJECT)-$(USER)-evo2

# bucket and job location
LOCATION?=us-central1

#####################################################################################
# job parameters
#####################################################################################

# job label (unique string identifier)
JOB?=evo-test

# job version (allows to submit the same job multiple times)
JOB_VERSION?=v1

# input fasta file of job
INPUT_FASTA?=examples/test.fasta

# wait for job to complete
WAIT?=true

#####################################################################################
# runtime and output parameters
#####################################################################################

# Evo 2 model name
MODEL_NAME?=evo2_7b

INCLUDE_EMBEDDING?=true
EMBEDDING_LAYERS?=blocks.28.mlp.l3

# machine type
MACHINE_TYPE?=a3-highgpu-1g

# accelerator type
ACCELERATOR_TYPE?=nvidia-h100-80gb

# accelerator count
ACCELERATOR_COUNT?=1

# jobs directory (description and output of the job)
JOBS_DIR?=jobs
