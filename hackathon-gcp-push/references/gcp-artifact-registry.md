# GCP Artifact Registry

Use Artifact Registry for Docker images.

## Required Inputs

- `PROJECT_ID`: organization GCP project.
- `REGION`: registry region, for example `asia-south1`, `us-central1`, or `europe-west1`.
- `REPOSITORY`: Artifact Registry Docker repository.
- `IMAGE_NAME`: team or project image name, lowercase and hyphenated.
- `TAG`: usually `final`, a team number, or a submission timestamp.

## Final URL Format

```text
REGION-docker.pkg.dev/PROJECT_ID/REPOSITORY/IMAGE_NAME:TAG
```

## Safe Commands

- `gcloud auth list`
- `gcloud config get-value project`
- `gcloud auth configure-docker REGION-docker.pkg.dev`
- `docker tag LOCAL_IMAGE FINAL_URL`
- `docker push FINAL_URL`

Create repositories only when organizers permit it.

## Docker Swarm

After the image is pushed, judges can deploy it to a Swarm service with a command like:

```text
docker service create --name TEAM_SERVICE --publish 8080:8080 FINAL_IMAGE_URL
```

For an existing service:

```text
docker service update --image FINAL_IMAGE_URL TEAM_SERVICE
```
