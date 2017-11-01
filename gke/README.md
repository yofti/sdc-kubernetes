# Sysdig Cloud on Kubernetes

## Installation Guide

### Requirements

- Running Kubernetes cluster, Kubernetes version >= 1.3.X (this guide has been tested with Kubernetes 1.3.6)
- Sysdig Cloud quay.io pull secret
- Sysdig Cloud license

### Infrastructure Overview

![Sysdig Cloud infrastructure](images/sysdig_cloud_infrastructure.png?raw=true "Infrastructure")

### Step 1: Namespace creation

It is recommended to create a separate Kubernetes namespace for Sysdig Cloud. The installation manifests don't assume a specific one in order to give the user more flexibility. In the rest of this guide, the chosen namespace will be `sysdigcloud`:

```
kubectl create namespace sysdigcloud
```

### Step 2: User settings

The file `sysdigcloud/config.yaml` contains a ConfigMap with all the available user settings. The file must be edited with the proper settings, including the mandatory `sysdigcloud.license`. After editing, then the Kubernetes object can be created:

```
kubectl create -f sysdigcloud/config.yaml --namespace sysdigcloud
``` 

Most settings can also be edited after the initial deployment, as they will be known just after the deployment of some Kubernetes services.

### Step 3: Quay pull secret

To download Sysdig Cloud Docker images it is mandatory to create a Kubernetes pull secret. Edit the file `sysdigcloud/pull-secret.yaml` and change the place holder `<PULL_SECRET>` with the provided pull secret.
Create the pull secret object using kubectl:

```
kubectl create -f sysdigcloud/pull-secret.yaml --namespace sysdigcloud
```

### Step 4: SSL certificates

Sysdig Cloud api and collector services use SSL to secure the communication between the customer browser and sysdigcloud agents.

If you want to use a custom SSL secrets, make sure to obtain the respective `server.crt` and `server.key` files, otherwise you can also create a self-signed certificate with:

```
openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -subj "/C=US/ST=CA/L=SanFrancisco/O=ICT/CN=onprem.sysdigcloud.com" -keyout server.key -out server.crt
```

Once done, create a Kubernetes secret:

```
kubectl create secret tls sysdigcloud-ssl-secret --cert=server.crt --key=server.key --namespace=sysdigcloud
```

##### Optional: Custom SSL certificates

If you want to use services that implement SSL self-signed certificates you can import those certificates and their chains, storing them in PEM format and injecting them as a generic kubernets secret.
For each certificate you want to import create a file, for example: certs1.crt, cert2.crt, ... and then the kubernetes secret using the following command line:

```
kubectl create secret generic sysdigcloud-java-certs --from-file=certs1.crt --from-file=certs2.crt --namespace=sysdigcloud
```

### Step 5: Datastore deployment

Sysdig Cloud requires MySQL, Cassandra, Redis and Elasticsearch to properly work. Deployment of stateful services in Kubernetes can be done in several ways. It is recommended to tweak the deployment of those depending on the individual needs. Some examples (mostly meant as guidelines) are:

- [Kubernetes pods](datastores/as_kubernetes_pods): datastores deployed within Kubernetes, with optional data persistency
- [External services](datastores/external_services): more flexible method, giving full control to the user about the location and deployment types of the databases

### Step 6: Expose Sysdig Cloud services

To expose the Sysdig Cloud api and collector deployments you can create a Kubernetes NodePort or LoadBalacer service, depending on the specific needs.

#### NodePort

Using a NodePort service the Kubernetes master will allocate a port on each node and will proxy that port (the same port number on every Node) towards the service.
After this step, it should be possible to correctly fill all the parameters in the ConfigMap, such as `collector.endpoint`, `collector.port` and `api.url`.

It is possible to create a NodePort service for Sysdig Cloud api and collector using kubectl and the templates in the sysdigcloud directory:

```
kubectl create -f sysdigcloud/api-nodeport-service.yaml -f sysdigcloud/collector-nodeport-service.yaml --namespace sysdigcloud
```

#### LoadBalancer

On cloud providers which support external load balancers, using a LoadBalancer service will provision a load balancer for the service. The actual creation of the load balancer happens asynchronously. Traffic from the external load balancer will be directed at the backend pods, though exactly how that works depends on the cloud provider.

It is possible to create a LoadBalancer Service for Sysdig Cloud api and collector using kubectl and the templates in the sysdigcloud folder:

```
kubectl create -f sysdigcloud/api-loadbalancer-service.yaml -f sysdigcloud/collector-loadbalancer-service.yaml --namespace sysdigcloud
```

### Step 7: Deploy Sysdig Cloud components

The Sysdig Cloud tiers can be created with the proper manifests:

```
kubectl create -f sysdigcloud/sdc-api.yaml -f sysdigcloud/sdc-collector.yaml -f sysdigcloud/sdc-worker.yaml --namespace sysdigcloud
```

This command will create three deployments named `sysdigcloud-api`, `sysdigcloud-collector`, `sysdigcloud-worker`

### Step 8: Connect to Sysdig Cloud

After all the components have been deployed and the pods are all in a ready state, it should be possible to continue the installation by opening the browser on the port exposed by the `sysdigcloud-api` service (the specific port depends on the chosen service type), for example `https://sysdigcloud-api:443`

# Additional topics

## Updates

Sysdig Cloud releases are listed [here](https://github.com/draios/sysdigcloud-kubernetes/releases). Each release has a version number (e.g. 353) and specific upgrade notes.

By default, the manifests use the image tag of the latest stable release. This way, scaling activities that occur at a later time will always work on a consistent version of the application. When a new version is released, the upgrade process will need to be run in order to move all the deployments to the newer release.

For the majority of the updates, the format of the manifests does not change in new releases, and the update process is as simple as bumping the version of the Docker images. For example, to upgrade to version 353:

```
kubectl set image deployment/sysdigcloud-api api=quay.io/sysdig/sysdigcloud-backend:353 --namespace sysdigcloud
kubectl set image deployment/sysdigcloud-collector collector=quay.io/sysdig/sysdigcloud-backend:353 --namespace sysdigcloud
kubectl set image deployment/sysdigcloud-worker worker=quay.io/sysdig/sysdigcloud-backend:353 --namespace sysdigcloud
```

Assuming the deployments have more than one replica each, the upgrade process will not cause any downtime.

In some circumstances, the manifests will change with a new release (the typical case being new parameters added to the ConfigMap). In these cases, the upgrade notes will clearly indicate what resources need to be recreated (the user can also inspect the changes by comparing different releases within the GitHub interface). The user should then choose the best upgrade strategy that satisfies the business requirement. In the simplest case, the user would just replace the deployments (causing downtime). In a more elaborate scenario, the user would create a new deployment alongside the old one, and would decommission the old one when the new one comes up, minimizing the downtime (which might still happen in case of some complicated database schema migrations, which will clearly be listed in the upgrade notes).

Although updating to the latest release is recommended, this repository is versioned, and a customer can feel free to pin a deployment to a particular release, and will always be able to fetch the specific manifests for the older version.

## Scale components

For performance and high availability reasons, it is possible to scale the Sysdig Cloud api, collector and worker by changing the number of replicas on the respective deployments:

```
kubectl --namespace sysdigcloud scale --replicas=2 deployment sysdigcloud-collector --namespace sysdigcloud
kubectl --namespace sysdigcloud scale --replicas=2 deployment sysdigcloud-worker --namespace sysdigcloud
kubectl --namespace sysdigcloud scale --replicas=2 deployment sysdigcloud-api --namespace sysdigcloud
```

It is also recommended to scale the Cassandra cluster (the specific procedure depends on the type of Cassandra deployment, follow the relevant guides for more information).

## Configuration changes

To change the original installation parameters, the ConfigMap can simply be edited:

```
kubectl edit configmap/sysdigcloud-config --namespace sysdigcloud
```

If the ConfigMap is edited on the client side (for example, to keep it synced in a git repository), it can be simply overridden with:

```
kubectl replace -f sysdigcloud/config.yaml --namespace sysdigcloud
```

After updating the ConfigMap, the Sysdig Cloud components need to be restarted in order for the changed parameters to take effect. This can be done by simply forcing a rolling update of the deployments. A possible way to do so is:

```
kubectl patch deployment sysdigcloud-api -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}" --namespace sysdigcloud
kubectl patch deployment sysdigcloud-collector -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}" --namespace sysdigcloud
kubectl patch deployment sysdigcloud-worker -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}" --namespace sysdigcloud
```

This will ensure that the application restarts with no downtime (assuming the deployments have more than one replica each).

## Troubleshooting data

When experiencing issues, you can collect troubleshooting data that can help the support team. The data can be collected by hand, or we provide a very simple `get_support_bundle.sh` script that takes as an argument the namespace where Sysdig Cloud is deployed and will generate a tarball containing some information (mostly log files):

```
$ ./scripts/get_support_bundle.sh sysdigcloud
Getting support logs for sysdigcloud-api-1477528018-4od59
Getting support logs for sysdigcloud-api-1477528018-ach89
Getting support logs for sysdigcloud-cassandra-2987866586-fgcm8
Getting support logs for sysdigcloud-collector-2526360198-e58uy
Getting support logs for sysdigcloud-collector-2526360198-v1egg
Getting support logs for sysdigcloud-mysql-2388886613-a8a12
Getting support logs for sysdigcloud-redis-1701952711-ezg8q
Getting support logs for sysdigcloud-worker-1086626503-4cio9
Getting support logs for sysdigcloud-worker-1086626503-sdtrc
Support bundle generated: 1473897425_sysdig_cloud_support_bundle.tgz
```
