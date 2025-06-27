#!/bin/bash

set -e

usage() {
  echo "Usage: $0 --job-name <job-name> --location <location> --job-json <job-json-path> [--wait]"
  exit 1
}

# Parse command-line arguments
WAIT_FLAG=""
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --job-name) JOB_NAME="$2"; shift ;;
    --location) LOCATION="$2"; shift ;;
    --job-json) JOB_JSON="$2"; shift ;;
    --wait) WAIT_FLAG="--wait" ;;
    *) echo "Unknown parameter passed: $1"; usage ;;
  esac
  shift
done

if [ -z "$JOB_NAME" ] || [ -z "$LOCATION" ] || [ -z "$JOB_JSON" ]; then
  usage
fi

# Check if the job exists and delete it if it does
if gcloud batch jobs describe "$JOB_NAME" --location="$LOCATION" &> /dev/null; then
    echo "Job '$JOB_NAME' exists. Deleting it now..."
    gcloud batch jobs delete "$JOB_NAME" --location="$LOCATION" --quiet

    echo "Waiting for job to be fully deleted..."
    while gcloud batch jobs describe "$JOB_NAME" --location="$LOCATION" &> /dev/null; do
        printf "."
        sleep 5
    done
    echo " Job fully deleted."
fi

echo "Submitting job $JOB_NAME..."
gcloud batch jobs submit "$JOB_NAME" --config="$JOB_JSON" --location="$LOCATION"

if [ "$WAIT_FLAG" == "--wait" ]; then
    echo "Waiting for job $JOB_NAME to complete..."
    while true; do
      STATUS=$(gcloud batch jobs describe "$JOB_NAME" --location="$LOCATION" --format='value(status.state)')
      echo "Current status: $STATUS"
      if [[ "$STATUS" == "SUCCEEDED" || "$STATUS" == "FAILED" || "$STATUS" == "DELETION_IN_PROGRESS" ]]; then
        break
      fi
      sleep 60
    done

    echo "Job finished with status: $STATUS"

    if [[ "$STATUS" == "FAILED" ]]; then
      exit 1
    fi
fi 