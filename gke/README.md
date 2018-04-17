# Prediction on GKE

## How to use.

### Run locally

1. Setup Pub/Sub subscription.
2. Edit config.yml
3. `bundle install --path vendor/bundle`
4. `bundle exec ruby pull.rb config.yml`

### Run on GKE

1. Setup Pub/Sub subscription & GKE cluster.
2. `docker build -t gcr.io/MY-PROJECT-ID/iost-worker`
3. Edit deployment.yml
4. `kubectl create -f deployment.yml`
