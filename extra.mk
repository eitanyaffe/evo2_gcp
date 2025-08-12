
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
		OUTPUT_TYPE=logits \
		MACHINE_TYPE=a3-highgpu-8g \
		ACCELERATOR_TYPE=nvidia-h100-80gb \
		ACCELERATOR_COUNT=8 \
		JOB_VERSION=v16

# run evo on large fasta
test_medium:
	$(MAKE) generate_fasta \
		INPUT_FASTA_TEST=$(INPUT_FASTA_TEST_MEDIUM) \
		READ_LENGTH=100000
	$(MAKE) submit \
		INPUT_FASTA=$(INPUT_FASTA_TEST_MEDIUM) \
		JOB=evo-medium \
		OUTPUT_TYPE=logits \
		JOB_VERSION=v5

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
# INPUT_FASTA_COMBINED?=examples/gyrA_combined.fasta
INPUT_FASTA_COMBINED?=examples/combo.fasta

# run evo on combined fasta
compare:
	$(MAKE) submit \
		INPUT_FASTA=$(INPUT_FASTA_COMBINED) \
		JOB=evo-combined \
		JOB_VERSION=v9
download_compare:
	$(MAKE) download JOB=evo-combined JOB_VERSION=v9

#####################################################################################
# steering vector examples
#####################################################################################

STEERING_VECTOR_FILE_EXAMPLE?=examples/steering_vector.tsv
STEERING_LAYER_EXAMPLE?=blocks.28.mlp.l3
STEERING_SCALES_EXAMPLE?=n1,1

# run evo with steering vector example
test_steering:
	$(MAKE) submit \
		INPUT_FASTA=examples/test.fasta \
		JOB=evo-steering \
		OUTPUT_TYPE=logits \
		STEERING_LAYER=$(STEERING_LAYER_EXAMPLE) \
		STEERING_VECTOR_FILE=$(STEERING_VECTOR_FILE_EXAMPLE) \
		STEERING_SCALES="$(STEERING_SCALES_EXAMPLE)" \
		JOB_VERSION=v1

# download steering results
download_steering:
	$(MAKE) download JOB=evo-steering JOB_VERSION=v1

# plot steering results
plot_steering:
	Rscript scripts/steering_example.r

# download and plot steering results
analyze_steering: download_steering plot_steering

#####################################################################################
# open local container for testing and debugging
#####################################################################################

ENV_IMAGE?=$(IMAGE_NAME)
env:
	mkdir -p jobs/$(JOB_TAG)
	cp $(INPUT_FASTA) jobs/$(JOB_TAG)/input.fasta
	docker run -it \
		--platform=linux/amd64 \
		-v /tmp:/tmp \
		-v $(PWD):/work \
		-w /work \
		-e JOB=$(JOB_TAG) \
		-e JOB_JSON=$(JOB_JSON) \
		-e BUCKET_NAME=$(BUCKET_NAME) \
		-e DOCKER_IMAGE=$(DOCKER_IMAGE) \
		-e JOB_TAG=$(JOB_TAG) \
		-e MODEL_NAME=$(MODEL_NAME) \
		-e OUTPUT_TYPE=$(OUTPUT_TYPE) \
		-e EMBEDDING_LAYERS="$(EMBEDDING_LAYERS)" \
		-e MACHINE_TYPE=$(MACHINE_TYPE) \
		-e ACCELERATOR_TYPE=$(ACCELERATOR_TYPE) \
		-e ACCELERATOR_COUNT=$(ACCELERATOR_COUNT) \
		-e RUN_SCRIPT_PATH=$(SCRIPT_PATH) \
		-e MNT_DIR=/work \
		$(ENV_IMAGE) \
		bash
