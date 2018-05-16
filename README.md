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
3. Built and push Docker container ($ cd gke; docker build -t gcr.io/${PROJECT_ID}/iost-worker .; docker push gcr.io/${PROJECT_ID}/iost-worker)
3. Create GKE cluster
4. Deploy workload
5. Deploy dashboard App Engine application ($ cd dashboard; goapp deploy -application ${PROJECT_ID} -version 1 app.yaml)
