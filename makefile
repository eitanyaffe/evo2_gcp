#####################################################################################
# job parameters
#####################################################################################

# job label (unique string identifier)
JOB?=evo-test

# job version (allows to submit the same job multiple times)
JOB_VERSION?=v7

# add version to job tag
JOB_TAG?=$(JOB)-$(JOB_VERSION)

# input fasta file of job
INPUT_FASTA?=examples/test.fasta

#####################################################################################
# GCP paths
#####################################################################################

# bucket name
BUCKET_NAME?=relman-evo2

# bucket and job location
LOCATION?=us-central1

#####################################################################################
# runtime and output parameters
#####################################################################################

# Evo 2 model name
MODEL_NAME?=evo2_7b

# output types (logits and/or embeddings)
OUTPUT_TYPES?=logit

# machine type
MACHINE_TYPE?=a3-highgpu-1g

# accelerator type
ACCELERATOR_TYPE?=nvidia-h100-80gb

# accelerator count
ACCELERATOR_COUNT?=1

#####################################################################################
#####################################################################################

# run once 
all_once: docker_image create_bucket upload_model upload_code

# run per job
all: submit

# after job is done
get: download

#####################################################################################
# A) build and upload docker image to GCR
#####################################################################################

DOCKER_LOCAL?=evo2
DOCKER_IMAGE?=gcr.io/relman-yaffe/evo2

docker_image:
	docker build -t $(DOCKER_LOCAL) .
	docker tag $(DOCKER_LOCAL) $(DOCKER_IMAGE)
	docker push $(DOCKER_IMAGE)

# open local container for testing and debugging
env:
	docker run -it \
		-v /tmp:/tmp \
		-v $(PWD):/work \
		-w /work \
		$(DOCKER_LOCAL) \
		bash

#####################################################################################
# B) prepare GCR bucket with model, scripts, configs
#####################################################################################

# create bucket
create_bucket:
	gsutil mb -l $(LOCATION) gs://$(BUCKET_NAME)

# model
MODEL_NAME_FULL?=arcinstitute/$(MODEL_NAME)
MODEL_DIR?=/tmp/$(MODEL_NAME)

# upload model to bucket
upload_model:
	python model_to_bucket.py \
		--model_name $(MODEL_NAME_FULL) \
		--bucket $(BUCKET_NAME) \
		--gcs_path "models/$(MODEL_NAME)" \
		--tmp_dir $(MODEL_DIR)

# scripts
SCRIPTS_DIR?=scripts
CONFIGS_DIR?=configs

# upload code to bucket
upload_code:
	gsutil -m rsync -r $(SCRIPTS_DIR) gs://$(BUCKET_NAME)/scripts
	gsutil -m rsync -r $(CONFIGS_DIR) gs://$(BUCKET_NAME)/configs

#####################################################################################
# C) prepare and submit job
#####################################################################################

# job directory
JOB_DIR?=jobs/$(JOB_TAG)


# checkpoint path
CHECKPOINT_PATH?=$(MODEL_DIR)/$(MODEL_NAME).pt

# wraper script sh path in container
SCRIPT_PATH?=scripts/run_evo.sh

# job json
JOB_JSON?=$(JOB_DIR)/job.json

# upload fasta file to bucket
upload_fasta:
	gsutil -m cp $(INPUT_FASTA) gs://$(BUCKET_NAME)/jobs/$(JOB_TAG)/input.fasta

# build json file
build_json:
	mkdir -p $(JOB_DIR)
	python3 scripts/build_json.py \
		--output_file_path $(JOB_JSON) \
		--remote_path $(BUCKET_NAME) \
		--image_uri $(DOCKER_IMAGE) \
		--job_env $(JOB_TAG) \
		--model_name_env $(MODEL_NAME) \
		--output_types_env $(OUTPUT_TYPES) \
		--machine_type $(MACHINE_TYPE) \
		--accelerator_type $(ACCELERATOR_TYPE) \
		--accelerator_count $(ACCELERATOR_COUNT) \
		--run_script_path $(SCRIPT_PATH)

# submit job
submit: upload_fasta build_json
	gcloud batch jobs submit $(JOB_TAG) --config=$(JOB_JSON) --location=$(LOCATION)

#####################################################################################
# D) download results to local computer
#####################################################################################

# download results
download:
	gsutil -m cp -r gs://$(BUCKET_NAME)/jobs/$(JOB_TAG)/output $(JOB_DIR)/output

#####################################################################################
# monitering jobs and debugging
#####################################################################################

# show job directory
show:
	gsutil ls gs://$(BUCKET_NAME)/jobs/$(JOB_TAG)

# list jobs
list_jobs:
	gcloud batch jobs list --location=$(LOCATION)
