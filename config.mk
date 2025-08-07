#####################################################################################
# Google parameters
#####################################################################################

# GCP project
GCP_PROJECT?=relman-yaffe

# bucket and job location
LOCATION?=us-central1

#####################################################################################
# docker
#####################################################################################

# local docker image name
IMAGE_NAME?=evo2

# docker image CUDA version
CUDA_VERSION?=12.4.1

# docker image Ubuntu version
UBUNTU_VERSION?=22.04

# docker image name
DOCKER_IMAGE?=gcr.io/$(GCP_PROJECT)/$(USER)/evo2:$(UBUNTU_VERSION)_$(CUDA_VERSION)

# if you have access to an existing image such as the one below you can use it
# by commenting out the line above and uncommenting the line below
#DOCKER_IMAGE?=gcr.io/relman-yaffe/eitany/evo2:22.04_12.4.1

#####################################################################################
# GCP paths
#####################################################################################

# bucket name
BUCKET_NAME?=$(GCP_PROJECT)-$(USER)-evo2

#####################################################################################
# job parameters
#####################################################################################

# job label (unique string identifier)
JOB?=evo-$(USER)-test

# job version (allows to submit the same job multiple times)
JOB_VERSION?=v1

# input fasta file of job
INPUT_FASTA?=examples/test.fasta

# query table: table to restrict nt-level analysis to specified regions
QUERY_TABLE?=none

# wait for job to complete
WAIT?=true

#####################################################################################
# runtime and output parameters
#####################################################################################

# Evo 2 model name
MODEL_NAME?=evo2_7b

# output type: logits, logits_and_embedding, embedding or summary_only
OUTPUT_TYPE?=logits

# embedding layers to extract (only used if OUTPUT_TYPE includes embeddings)
EMBEDDING_LAYERS?=blocks.28.mlp.l3

# steering vector parameters (optional)
STEERING_LAYER?=
STEERING_VECTOR_FILE?=
STEERING_SCALES?=

# machine type
MACHINE_TYPE?=a3-highgpu-1g

# accelerator type
ACCELERATOR_TYPE?=nvidia-h100-80gb

# accelerator count
ACCELERATOR_COUNT?=1

# jobs directory (description and output of the job)
JOBS_DIR?=jobs
