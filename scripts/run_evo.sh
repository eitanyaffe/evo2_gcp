#!/bin/sh

set -e -o pipefail
trap 'echo "Command failed. Exiting."; exit 1' ERR

SCRIPTS_DIR=$MNT_DIR/scripts
JOB_DIR=$MNT_DIR/jobs/$JOB

OUTPUT_DIR=$JOB_DIR/output

CHECKPOINT_DIR=$MNT_DIR/models
CHECKPOINT_PATH=$CHECKPOINT_DIR/$MODEL_NAME/$MODEL_NAME.pt

FASTA_FILE=$JOB_DIR/input.fasta
QUERY_TABLE=$JOB_DIR/query_table.csv
STEERING_VECTOR_FILE_PATH=$JOB_DIR/steering_vector.tsv

echo "Running job: $JOB"
echo "Mount directory: $MNT_DIR"
echo "Input fasta file: $FASTA_FILE"
echo "Query table: $QUERY_TABLE"
echo "Output directory: $OUTPUT_DIR"
echo "Scripts directory: $SCRIPTS_DIR"
echo "Model name: $MODEL_NAME"
echo "Checkpoint path: $CHECKPOINT_PATH"
echo "Output type: $OUTPUT_TYPE"
echo "Embedding layers: $EMBEDDING_LAYERS"
echo "Steering layer: $STEERING_LAYER"
echo "Steering vector file: $STEERING_VECTOR_FILE_PATH"
echo "Steering scales: $STEERING_SCALES"
echo "CUDA_VISIBLE_DEVICES: $CUDA_VISIBLE_DEVICES"
mkdir -p $OUTPUT_DIR

# Construct arguments for run_evo.py
SCRIPT_ARGS="--fasta_file $FASTA_FILE --model_name $MODEL_NAME --checkpoint_path $CHECKPOINT_PATH"
SCRIPT_ARGS="$SCRIPT_ARGS --output_dir $OUTPUT_DIR"
SCRIPT_ARGS="$SCRIPT_ARGS --output_type $OUTPUT_TYPE"

if [ -f "$QUERY_TABLE" ]; then
    SCRIPT_ARGS="$SCRIPT_ARGS --query_table $QUERY_TABLE"
fi

if [ "$OUTPUT_TYPE" = "logits_and_embedding" ] || [ "$OUTPUT_TYPE" = "embedding" ]; then
    if [ -n "$EMBEDDING_LAYERS" ]; then
        SCRIPT_ARGS="$SCRIPT_ARGS --embedding_layers $EMBEDDING_LAYERS"
    fi
fi

if [ -n "$STEERING_LAYER" ] && [ -f "$STEERING_VECTOR_FILE_PATH" ]; then
    SCRIPT_ARGS="$SCRIPT_ARGS --steering_layer $STEERING_LAYER"
    SCRIPT_ARGS="$SCRIPT_ARGS --steering_vector_file $STEERING_VECTOR_FILE_PATH"
    if [ -n "$STEERING_SCALES" ]; then
        SCRIPT_ARGS="$SCRIPT_ARGS --steering_scale $STEERING_SCALES"
    fi
fi

export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

{
  echo "running: python3 $SCRIPTS_DIR/run_evo.py $SCRIPT_ARGS"
  python3 "$SCRIPTS_DIR/run_evo.py" $SCRIPT_ARGS
} 2>&1 | tee "$OUTPUT_DIR/run_evo.log"
