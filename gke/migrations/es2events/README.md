# Events Migration to Elasticsearch
To improve search capabilities and offer improved performance, beginning with version 494, Elasticsearch is used to store [Custom Events](https://support.sysdigcloud.com/hc/en-us/articles/209998743-Event-integrations-Custom-Events). In order to complete an update to version 494 or newer, it is mandatory to migrate previously-stored events into Elasticsearch.

## Prerequisites
Must be up & running Sysdig Cloud version 439 or older

**NOTE**: As in the [install README](https://github.com/draios/sysdigcloud-kubernetes), the commands in this guide assume your install is running in a Kubernetes namespace `sysdigcloud`. Adjust this as necessary to the specifics of your install.

## Step 1 - Verify existing events
Log in to the Sysdig Cloud application and familiarize yourself with recent events by navigating to the page **Events > Custom Events**. You may want to take a screenshot so you can refer to it later when confirming the success of the migration.

## Step 2 - Sysdig Cloud Configuration Update
Get the current configuration (you can use also a versioned one if you have it):
```
kubectl get configmap sysdigcloud-config --namespace sysdigcloud -o yaml > current_config.yaml
cp current_config.yaml new_config.yaml
```

Edit `new_config.yaml` and add the new parameters for Elasticsearch alongside existing config under `data`. Follow the tips in the comments to adjust them to the needs of your environment.

```
  # Elasticsearch URL. If Elasticsearch is deployed as a Kubernetes service,
  # this will be the service name. If using an external database, put the proper address
  elasticsearch.url: http://sysdigcloud-elasticsearch
  # Elasticsearch JVM options, when Elasticsearch is started as a Kubernetes service
  # using the provided manifests. For heavy load environments you'll need to tweak the
  # memory or garbage collection settings
  elasticsearch.jvm.options: ""
```

Apply the new config file with:
```
kubectl replace -f new_config.yaml --namespace sysdigcloud
```

## Step 3 - Deploy the Elasticsearch cluster
Read the documentation contained in the [sysdigcloud-kubernetes](https://github.com/draios/sysdigcloud-kubernetes) repository about [datastores in kubernetes](https://github.com/draios/sysdigcloud-kubernetes#step-5-datastore-deployment) and deploy the cluster using the type of datastore that fits your environment's needs for Elasticsearch.

## Step 4 - Update the application
Update the application to the latest tag as described [here](https://github.com/draios/sysdigcloud-kubernetes#updates).

## Step 5 - Migrate the events
Once you have the Elasticsearch cluster and Sysdig Cloud up and running in your Kubernetes installation, you can use the migration template in the repository to start the migration of the events to Elasticsearch:

```
kubectl create -f migrations/es2events/events_migration.yaml --namespace sysdigcloud
```

The pod will terminate right after the events migration is complete, you can check the logs of the migration with kubectl logs:

```
kubectl logs -f sysdigcloud-migration --namespace sysdigcloud
```

## Step 6 - Verify your events
Log in to the Sysdig Cloud application and check that all your events from before the migration are available by navigating to the page **Events > Custom Events**.

## Step 7 - Cleanup
Once the migration is correctly completed, perform the following clean-up command  to remove the remnants of the migration tool:
```
kubectl delete -f migrations/es2events/events_migration.yaml --namespace sysdigcloud
```
