include config.mk
include extra.mk

# add version to job tag
JOB_TAG?=$(JOB)-$(JOB_VERSION)

#####################################################################################
# Combo rules
#####################################################################################

# every project has a dedicated bucket
# every job has a dedicated folder in the bucket

# run once per project
all_once: docker_image create_bucket upload_model upload_code

# submit job
all: submit

# after job is done
get: download

#####################################################################################
# build and upload docker image to GCR
#####################################################################################

# build docker image
docker_image:
	docker build --platform linux/amd64 -t $(IMAGE_NAME) \
		--build-arg CUDA_VERSION=$(CUDA_VERSION) \
		--build-arg UBUNTU_VERSION=$(UBUNTU_VERSION) .
	docker tag $(IMAGE_NAME) $(DOCKER_IMAGE)
	docker push $(DOCKER_IMAGE)

#####################################################################################
# prepare GCR bucket with model, scripts, configs
#####################################################################################

# create bucket
create_bucket:
	gsutil ls -b gs://$(BUCKET_NAME) >/dev/null 2>&1 || gsutil mb -l $(LOCATION) gs://$(BUCKET_NAME)

# model
MODEL_NAME_FULL?=arcinstitute/$(MODEL_NAME)
MODEL_DIR?=/tmp/$(MODEL_NAME)

# upload model to bucket
upload_model:
	python3 model_to_bucket.py \
		--model_name $(MODEL_NAME_FULL) \
		--bucket $(BUCKET_NAME) \
		--gcs_path "models/$(MODEL_NAME)" \
		--tmp_dir $(MODEL_DIR)

# folders uploaded to bucket
SCRIPTS_DIR?=scripts
CONFIGS_DIR?=configs

# upload code to bucket
upload_code:
	gsutil -m rsync -r $(SCRIPTS_DIR) gs://$(BUCKET_NAME)/scripts
	gsutil -m rsync -r $(CONFIGS_DIR) gs://$(BUCKET_NAME)/configs

#####################################################################################
# prepare and submit job
#####################################################################################

# job directory
JOB_DIR?=$(JOBS_DIR)/$(JOB_TAG)

# checkpoint path
CHECKPOINT_PATH?=$(MODEL_DIR)/$(MODEL_NAME).pt

# wraper script sh path in container
SCRIPT_PATH?=scripts/run_evo.sh

# job json
JOB_JSON?=$(JOB_DIR)/job.json

# upload fasta file to bucket
upload_fasta:
	gsutil -m cp $(INPUT_FASTA) gs://$(BUCKET_NAME)/jobs/$(JOB_TAG)/input.fasta

upload_query_table:
ifneq ($(QUERY_TABLE),none)
	gsutil -m cp $(QUERY_TABLE) gs://$(BUCKET_NAME)/jobs/$(JOB_TAG)/query_table.csv
endif
	
# build json file
build_json:
	mkdir -p $(JOB_DIR)
	python3 scripts/build_json.py \
		--output_file_path $(JOB_JSON) \
		--remote_path $(BUCKET_NAME) \
		--image_uri $(DOCKER_IMAGE) \
		--job_env $(JOB_TAG) \
		--model_name_env $(MODEL_NAME) \
		--output_type_env $(OUTPUT_TYPE) \
		$(if $(EMBEDDING_LAYERS),--embedding_layers_env "$(EMBEDDING_LAYERS)",) \
		--machine_type $(MACHINE_TYPE) \
		--accelerator_type $(ACCELERATOR_TYPE) \
		--accelerator_count $(ACCELERATOR_COUNT) \
		--run_script_path $(SCRIPT_PATH)

# submit job
submit: upload_code upload_fasta upload_query_table build_json
	bash submit_job.sh \
		--job-name $(JOB_TAG) \
		--location $(LOCATION) \
		--job-json $(JOB_JSON) \
		$(if $(WAIT),--wait)

#####################################################################################
# download results to local computer
#####################################################################################

# download results
download:
	gsutil -m cp -r gs://$(BUCKET_NAME)/jobs/$(JOB_TAG)/output $(JOB_DIR)
	echo "Downloaded results to $(JOB_DIR)"

save_vocab:
	python3 scripts/save_vocab.py

#####################################################################################
# monitering jobs and debugging
#####################################################################################

# show job directory
show:
	gsutil ls gs://$(BUCKET_NAME)/jobs/$(JOB_TAG)

# list jobs
list_jobs:
	gcloud batch jobs list --location=$(LOCATION)

# Generic rule to print the value of any makefile variable.
# Used by the Python wrapper to get evaluated default values.
# Example: make print-JOB_TAG
print-%:
	@echo $($*)

#####################################################################################
# Installation
#####################################################################################

# Default install location (can override with 'make install PREFIX=...')
PREFIX ?= ~/.local
BINDIR = $(PREFIX)/bin
INSTALL_NAME = evo_gcp

.PHONY: install uninstall

install:
	@mkdir -p $(BINDIR)
	@install -m 755 evo_gcp.py $(BINDIR)/$(INSTALL_NAME)
	@echo "✅ $(INSTALL_NAME) installed to $(BINDIR)"
	@echo "\nMake sure '$(BINDIR)' is in your PATH."

uninstall:
	@rm -f $(BINDIR)/$(INSTALL_NAME)
	@echo "🗑️ Uninstalled $(INSTALL_NAME) from $(BINDIR)"