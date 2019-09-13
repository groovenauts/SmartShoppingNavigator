# Smart Shopping Navigator

Smart Shopping Navigator is the demonstration application where it combines [Cloud IoT Core](https://cloud.google.com/iot-core/)
and [Cloud Machine Learning Engine](http://cloud.google.com/ml).

## Requirements

- Google Cloud Platform billing enabled project
  - Enable the following APIs
    - Google Cloud Storage JSON API
    - Cloud IoT API
    - BigQuery API
    - Cloud Machine Learning Engine
    - Kubernetes Engine API
- Raspberry Pi, Camera module and touch display
  - See [Setup Raspberry Pi](raspberrypi/README.md) for more details

## Setup

1. Name device ID for a new device and register it to Cloud IoT Core registory
2. Assemble Raspberry Pi device (see [Setup Raspberry Pi](raspberrypi/README.md) for more details)
3. Built and push Docker container
```
$ export PROJCT_ID="REPLACE WITH YOUR GCP PROJECT ID HERE"
$ cd gke
$ docker build -t gcr.io/${PROJECT_ID}/iost-worker . && docker push gcr.io/${PROJECT_ID}/iost-worker
```
4. Create GKE cluster

```
$ gcloud container clusters create [CLUSTER_NAME] --zone [COMPUTE_ZONE]
$ gcloud container clusters get-credentials [CLUSTER_NAME] --zone [COMPUTE_ZONE]
```
  See [Creating cluster](https://cloud.google.com/kubernetes-engine/docs/how-to/creating-a-cluster) for more details.
5. Deploy workload
```
$ cd gke
$ cp deployment.yml.example deployment.yml
  Edit depoyment.yml
$ kubectl create -f deployment.yml
```
6. Deploy dashboard App Engine application
```
$ cd dashboard
$ gcloud app deploy --version v1 app.yaml
```
