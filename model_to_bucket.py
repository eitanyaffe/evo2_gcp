import os
import argparse
from huggingface_hub import snapshot_download
from google.cloud import storage
from pathlib import Path
import atexit
import signal
import subprocess
import sys

def _get_child_pids(pid):
    """Returns a list of child PIDs for a given PID."""
    try:
        children = subprocess.check_output(["pgrep", "-P", str(pid)])
        return [int(p) for p in children.decode("utf-8").split()]
    except subprocess.CalledProcessError:
        return []

def _kill_process_tree(pid):
    """Recursively kills a process and all its descendants."""
    children = _get_child_pids(pid)
    for child_pid in children:
        _kill_process_tree(child_pid)
    
    try:
        # Use SIGKILL for forceful termination
        os.kill(pid, signal.SIGKILL)
    except ProcessLookupError:
        pass # Process already finished

def _cleanup():
    """Cleanup function to kill all child processes of the current process."""
    print("\nCleaning up child processes...")
    parent_pid = os.getpid()
    children = _get_child_pids(parent_pid)
    for child_pid in children:
        _kill_process_tree(child_pid)

atexit.register(_cleanup)

def download_model(model_name: str, local_dir: str):
    print(f"Downloading model '{model_name}' to '{local_dir}'...")
    snapshot_download(repo_id=model_name, local_dir=local_dir, resume_download=True)
    print("Download complete.")

def upload_directory_to_gcs(local_dir: str, bucket_name: str, gcs_prefix: str = ""):
    client = storage.Client()
    bucket = client.bucket(bucket_name)
    local_path = Path(local_dir)

    print(f"Uploading contents of '{local_dir}' to 'gs://{bucket_name}/{gcs_prefix}'...")
    for path in local_path.rglob("*"):
        if path.is_file():
            rel_path = path.relative_to(local_path)
            blob_path = f"{gcs_prefix}/{rel_path}".strip("/")
            blob = bucket.blob(blob_path)
            blob.upload_from_filename(str(path))
            print(f"Uploaded: gs://{bucket_name}/{blob_path}")
    print("Upload complete.")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model_name", required=True, help="Hugging Face model name, e.g., 'arcinstitute/evo2_7b'")
    parser.add_argument("--bucket", required=True, help="GCS bucket name")
    parser.add_argument("--gcs_path", default="", help="Path prefix within the GCS bucket")
    parser.add_argument("--tmp_dir", default="hf_model_tmp", help="Local temp directory to store the model")
    args = parser.parse_args()

    try:
        download_model(args.model_name, args.tmp_dir)
        upload_directory_to_gcs(args.tmp_dir, args.bucket, args.gcs_path)
    except KeyboardInterrupt:
        print("\nProcess interrupted by user. Exiting.", file=sys.stderr)
        # The atexit handler will be called automatically.
        # Exit with a status code indicating interruption.
        sys.exit(130)

if __name__ == "__main__":
    main()
