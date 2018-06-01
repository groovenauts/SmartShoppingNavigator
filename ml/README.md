# Smart Shopping Navigator demo (ML models)

## Deploy ML models to Cloud Machine Learning Engine (ML Engine)

### Requirements

- Google Cloud Platform billing enabled project
  - Enable the following APIs
    - Google Cloud Storage JSON API
    - Cloud Machine Learning Engine

### Preparation

See [Set up and test your Cloud environment](https://cloud.google.com/ml-engine/docs/tensorflow/getting-started-training-prediction#setup) section in ML Engine documentation.

### Pretrained models

There are two pre-trained models for SmartShoppingNavigator demo.

- Object Detection Model
  - gs://gcp-iost-models/object_detection/20180525/saved_model/
- Cart Prediction Model
  - gs://gcp-iost-models/cart_prediction/20180522/saved_model/

### Deploy models to ML Engine

See [Deploying Models](https://cloud.google.com/ml-engine/docs/tensorflow/deploying-models) for details.

```
gcloud --project=PROJECT ml-engine models create MODEL
gcloud --project=PROJECT ml-engine versions create VERSION --model MODEL --origin GCS_URL_OF_SAVED_MODEL --config=ml_engine_versions.yaml
```

Note that you should create two ML engine models and deploy models under each of them.
The ML Engine model names should be specified in gke/deployment.yml.
See [gke/deployment.yml.example](../gke/deployment.yml.example).

Please note that the config file [ml_engine_versions.yaml](ml_engine_versions.yaml) used in above commands contains [autoScaling](https://cloud.google.com/ml-engine/reference/rest/v1/projects.models.versions#autoscaling) parameter.
The ML Engine version deployed with the configuration always running at least one node for online prediction.
As a result each ML models cost for online prediction even if you don't run the demo applications.
See [Pricing](https://cloud.google.com/ml-engine/docs/pricing) page for details.
