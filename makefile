#####################################################################################
# job parameters
#####################################################################################

# job label (unique string identifier)
JOB?=evo-test

# job version (allows to submit the same job multiple times)
JOB_VERSION?=v18

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

INCLUDE_EMBEDDING?=true
EMBEDDING_LAYERS?=blocks.28.mlp.l3

# machine type
MACHINE_TYPE?=a3-highgpu-1g

# accelerator type
ACCELERATOR_TYPE?=nvidia-h100-80gb

# accelerator count
ACCELERATOR_COUNT?=1

#####################################################################################
# Combo rules
#####################################################################################

# run once 
all_once: docker_image create_bucket upload_model upload_code

# run per job
all: submit

# after job is done
get: download

#####################################################################################
# build and upload docker image to GCR
#####################################################################################

DOCKER_LOCAL?=evo2
DOCKER_IMAGE?=gcr.io/relman-yaffe/evo2

docker_image:
	docker build -t $(DOCKER_LOCAL) .
	docker tag $(DOCKER_LOCAL) $(DOCKER_IMAGE)
	docker push $(DOCKER_IMAGE)

# open local container for testing and debugging
env:
	mkdir -p jobs/$(JOB_TAG)
	cp $(INPUT_FASTA) jobs/$(JOB_TAG)/input.fasta
	docker run -it \
		-v /tmp:/tmp \
		-v $(PWD):/work \
		-w /work \
		-e JOB=$(JOB_TAG) \
		-e JOB_JSON=$(JOB_JSON) \
		-e BUCKET_NAME=$(BUCKET_NAME) \
		-e DOCKER_IMAGE=$(DOCKER_IMAGE) \
		-e JOB_TAG=$(JOB_TAG) \
		-e MODEL_NAME=$(MODEL_NAME) \
		-e INCLUDE_EMBEDDING=$(INCLUDE_EMBEDDING) \
		-e EMBEDDING_LAYERS="$(EMBEDDING_LAYERS)" \
		-e MACHINE_TYPE=$(MACHINE_TYPE) \
		-e ACCELERATOR_TYPE=$(ACCELERATOR_TYPE) \
		-e ACCELERATOR_COUNT=$(ACCELERATOR_COUNT) \
		-e RUN_SCRIPT_PATH=$(SCRIPT_PATH) \
		-e MNT_DIR=/work \
		$(DOCKER_LOCAL) \
		bash

#####################################################################################
# prepare GCR bucket with model, scripts, configs
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
# prepare and submit job
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
		$(if $(filter true,$(INCLUDE_EMBEDDING)),--include_embedding_env,) \
		$(if $(EMBEDDING_LAYERS),--embedding_layers_env "$(EMBEDDING_LAYERS)",) \
		--machine_type $(MACHINE_TYPE) \
		--accelerator_type $(ACCELERATOR_TYPE) \
		--accelerator_count $(ACCELERATOR_COUNT) \
		--run_script_path $(SCRIPT_PATH)

# submit job
submit: upload_code upload_fasta build_json
	gcloud batch jobs submit $(JOB_TAG) --config=$(JOB_JSON) --location=$(LOCATION)

#####################################################################################
# download results to local computer
#####################################################################################

# download results
download:
	gsutil -m cp -r gs://$(BUCKET_NAME)/jobs/$(JOB_TAG)/output $(JOB_DIR)

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

#####################################################################################
# large input testing
#####################################################################################

INPUT_FASTA_TEST?=examples/large_test.fasta
READ_COUNT?=10
READ_LENGTH?=1000000

INPUT_FASTA_TEST_MEDIUM?=examples/medium_test.fasta

# generate large fasta
generate_fasta:
	python3 utils/generate_fasta.py \
		--output_file $(INPUT_FASTA_TEST) \
		--read_count $(READ_COUNT) \
		--read_length $(READ_LENGTH)

# run evo on large fasta
test_long:
	$(MAKE) submit \
		INPUT_FASTA=$(INPUT_FASTA_TEST) \
		JOB=evo-large \
		INCLUDE_EMBEDDING=false \
		MACHINE_TYPE=a3-highgpu-4g \
		ACCELERATOR_COUNT=4 \
		JOB_VERSION=v8

# run evo on large fasta
test_medium:
	$(MAKE) generate_fasta \
		INPUT_FASTA_TEST=$(INPUT_FASTA_TEST_MEDIUM) \
		READ_LENGTH=100000
	$(MAKE) submit \
		INPUT_FASTA=$(INPUT_FASTA_TEST_MEDIUM) \
		JOB=evo-medium \
		INCLUDE_EMBEDDING=false \
		MACHINE_TYPE=a3-highgpu-2g \
		ACCELERATOR_COUNT=2 \
		JOB_VERSION=v1

#####################################################################################
# replace codon
#####################################################################################

INPUT_FASTA_WT?=examples/gyrA_sensitive.fasta
INPUT_FASTA_RESISTANT?=examples/gyrA_resistant.fasta
CODON_POSITION?=83
CODON_NEW?=ATC

# replace codon
replace_codon:
	python3 utils/replace_codon.py \
		--fasta_file $(INPUT_FASTA_WT) \
		--aa_position $(CODON_POSITION) \
		--new_codon $(CODON_NEW) \
		--output_file $(INPUT_FASTA_RESISTANT)

# both gyrA sequences in one fasta file
INPUT_FASTA_COMBINED?=examples/gyrA_combined.fasta

# run evo on combined fasta
test_combined:
	$(MAKE) submit \
		INPUT_FASTA=$(INPUT_FASTA_COMBINED) \
		JOB=evo-combined \
		JOB_VERSION=v5
download_combined:
	$(MAKE) download JOB=evo-combined JOB_VERSION=v5
