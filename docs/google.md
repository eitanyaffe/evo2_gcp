# 🔧 GCP Setup: Enable a New User to Create Buckets and Run Batch Jobs

This document outlines how to grant a new user permissions to use **Google Cloud Storage** (create buckets) and **Google Cloud Batch** (submit jobs). It includes steps for both the **admin** (who sets up access) and the **user** (who performs the tasks).

---

## Admin — Grant Access

1. **Go to the IAM page**:  
   https://console.cloud.google.com/iam-admin/iam

2. **Click “Grant Access”** and enter the user’s email.

3. **Assign the following roles**:

   | Purpose                       | Role                            |
   |-------------------------------|---------------------------------|
   | Create/manage buckets         | `roles/storage.admin`           |
   | Submit/manage Batch jobs      | `roles/batch.admin`             |
   | Use service accounts for jobs | `roles/iam.serviceAccountUser`  |

4. **Grant service account access**:
   - Go to **IAM > Service Accounts**.
   - Find the service account used by Batch jobs.
   - Click **"Permissions"**, then **"Grant Access"**.
   - Add the user with `roles/iam.serviceAccountUser`.

5. **Ensure the service account itself has**:
   - `roles/compute.instanceAdmin.v1`
   - `roles/storage.objectAdmin`

## User — Enable necessary APIs

**Make sure APIs are enabled:**
   ```bash
   gcloud services enable \
     batch.googleapis.com \
     compute.googleapis.com \
     storage.googleapis.com