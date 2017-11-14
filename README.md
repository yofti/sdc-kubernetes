# sdc-kubernetes: Sysdig Cloud Monitor Backend on Kubernetes

## Table of Contents
  * [What is this?](#What-is-this?)
  * [Infrastructure Overview](#Infrastructure-Overview)
  * [Requirements](#Requirements)
  * [Installation Guide](#Installation-Guide)
  * [Confirm Installation](#Confirm-Installation)
  * [What does the installer do?](#What-does-the-installer-do?)
  * [Operations Guide](#Operations-Guide)
  	- [Stop and Start](#Stop-and-Start)
  	- [Scale up and down](#scale-up-and-down)
  	- [Modifying configMap](#Modifying-configMap)
  	- [Version updates](#Version-updates)
  	- [Uninstall](#Uninstall)
  * [Tips and Tricks](#Tips-and-Tricks)


## What is this? <a id="What-is-this?"></a>

sdc-kubernetes is an on-prem version of [Sysdig Monitor](https://sysdig.com/product/monitor/), a SAAS offering by Sysdig Inc for monitoring containerized envrionments. The official on-prem Kubernetes guide can be found [here](https://github.com/draios/sysdigcloud-kubernetes). This repo is the result of a personal, on-going proof-of-concept project on improving certain aspects of Kubernetes deployment.

Here is a list of the highlights:

- **Introduction of Statefulsets**
	Replication Sets and their improved kin, Deployment Sets are good for stateless loads. But if you have states, like we do in our database (datastore) layer, you do need Stateful Sets.
- **Introduction of persistence to datastores**
	The key that makes Stateful Sets magical is the use of Persistent Volume Claims. PODs can now ask for block disks from the cloud provider dynamically. The disks can be encrypted, adjusted for IOPS specific performance and they can also be Snapshoted for backups.
- **Elimination of SPOF's (single points of failure)**
	All datastore components are now highly-available running in Stateful sets with replicas >= 3. Cassandra and Elasticsearch and full active/active cluster rings. Mysql and Redis are currently setup with master/slave replications. 
- **Performance improvements due to addition of "read-only" services**
	With the addition of Mysql and Redis slaves, we now have new endpoints in Kubernetes for read-only access. Backend components can point their read operations to the slaves and thereby minimize the load on the master instances.
- **All configurations consolidated into a single file**
  etc/sdc-config.yaml holds every configurable parameter.
- **Addition of rudimentary install.sh and uninstall.sh scripts.**
- **Support for Multi Availability Zone (multi AZ) deployments**
	As long as the underlying Kubernetes is deployed in Multi-AZ mode, we can run on it.

Some lowlights and TODOs:

- **Remove clear text passwords from configMap**
	Switch to Kubernetes secret. Easy to do. Need backend help. They need to request for a different variable from configMap. P.S. Look in the install.sh under the lab directory to see how secrets are configured for Google CloudSQL.
- **Redis cluster support**
	File a feature request for dev to support clustered redis. Seems like an easy code fix. We can get rid of the master/slave redis setup and go for a full cluster
- **Support Galera Active/Active**
	We're using Percona master/slave replication. We could easily go active/active on mysql.
- **AWS snitch for Cassandra**
	Yes, we can run on a multi-AZ k8s cluster. But our Cassandra is not really aware of it. It uses the 'simple' snitch. We could have Cassandra racks distributed accross zones.
- **Support non-cloud deployments**
	We can still do Statefulsets even if we don't have cloud providers. We can use local disks with PVC's. If we have access to SAN's, we could use products like [portworx](http://portworx.com)
- **Better install/uninstall**
	Error checking, logging. Add stop/start scripts?
- **Hard-codes zones in Storageclasses**
	The only things that makes us multi-AZ is where our StorageClasses request disk from. Do they do it from one zone or many? And which ones? Pay special attention to your storageclasses, persistent volume claims and zones when deploying this package. Modify existing Storageclasses to fit your needs.


## Infrastructure Overview <a id="Infrastructure-Overview"></a>

![sdc-kubernetes](https://user-images.githubusercontent.com/12384605/32736470-653dabb8-c84c-11e7-89bb-71c201ec980f.png?raw=true)

###### Backend components
* api-servers: provide a web and API interface to the main application
* collectors: agents (frontend) connect to this backend via collectors
* workers: process data aggregations and alerts

###### Cache Layer
* redis: intra-service cache

###### DataStores
* mysql: stores user data and environmental data
* elasticsearch: stores event and metadata
* cassandra: stores metrics

Backend components (worker, api and collector) are all stateless and are thus deployed in Deployment sets.
Datastores (redis, mysql, elasticsearch and cassandra) are stateful. They are configured in statefulsets that use Persistent Volume Claims (PVC) from the cloud provider.

## Requirements <a id="Requirements"></a>

- Access to a running Kubernetes cluster on AWS or GKE.
- Sysdig Cloud quay.io pull secret
- Sysdig Cloud license
- kubectl installed on your machine and communicating with the Kubernetes cluster

## Installation Guide <a id="Installation-Guide"></a>

1. Clone this repository to your machine
	`git clone https://github.com/yofti/sdc-kubernetes`
2. Edit the file *etc/sdc-config.yaml*
	* On line 7, find the entry *.dockerconfigjson*. Add your quay.io secret.
	* On line 17, find the entry *sysdigcloud.license*. Add the contents of your license (uri) file. 
	* All configurable parameters for this applications are in this file. Edit what you see fit.
3. `cd aws` or `cd gke` depending on your cloud provider.
4. Run ./install.sh


## Confirm Installation  <a id="Confirm-Installation"></a>

After installation, the list of pods in the sysdigcloud namespace should like this:
	
	$ kubectl get pods -n sysdigcloud	
	sdc-api-2039094698-11rtd         1/1       Running   0          13m
	sdc-cassandra-0                  1/1       Running   0          12m
	sdc-cassandra-1                  1/1       Running   0          11m
	sdc-cassandra-2                  1/1       Running   0          11m
	sdc-collector-1001165270-chrz0   1/1       Running   0          13m
	sdc-elasticsearch-0              1/1       Running   0          14m
	sdc-elasticsearch-1              1/1       Running   0          14m
	sdc-elasticsearch-2              1/1       Running   0          14m
	sdc-mysql-0                      2/2       Running   0          14m
	sdc-mysql-slave-0                2/2       Running   1          14m
	sdc-mysql-slave-1                2/2       Running   0          14m
	sdc-redis-0                      1/1       Running   0          14m
	sdc-redis-slave-0                1/1       Running   0          14m
	sdc-redis-slave-1                1/1       Running   0          14m
	sdc-worker-1937471472-hfp25      1/1       Running   0          13m

Check the services that were created.

	$ kubectl -n sysdigcloud get services
	NAME                CLUSTER-IP   EXTERNAL-IP        PORT(S)                               AGE
	sdc-api             10.3.0.36    ad0d03112c706...   443:32253/TCP                         32m
	sdc-cassandra       None         <none>             9042/TCP,7000/TCP,7001/TCP,7199/TCP   34m
	sdc-collector       10.3.0.203   ad0e5cf87c706...   6443:31063/TCP                        32m
	sdc-elasticsearch   None         <none>             9200/TCP,9300/TCP                     34m
	sdc-mysql           None         <none>             3306/TCP                              34m
	sdc-mysql-slave     None         <none>             3306/TCP                              33m
	sdc-redis           None         <none>             6379/TCP,16379/TCP                    34m
	sdc-redis-slave     None         <none>             6379/TCP,16379/TCP                    34m

Describe the sdc-api service to get the full API endpoint URL.
It will be `ad0d03112c70611e79d6006e5a830746-1802392156.us-west-1.elb.amazonaws.com` in this case. Use this URL to access the SDC Monitor interface. This URL can be given a sensible URL via Route53 or similar.

	$ kubectl -n sysdigcloud describe service sdc-api
	Name:			sdc-api
	Namespace:		sysdigcloud
	Labels:			app=sysdigcloud
					role=api
	Annotations:	<none>
	Selector:		app=sysdigcloud,role=api
	Type:			LoadBalancer
	IP:				10.3.0.36
	LoadBalancer Ingress:	ad0d03112c70611e79d6006e5a830746-1802392156.us-west-1.elb.amazonaws.com
	Port:			secure-api	443/TCP
	NodePort:		secure-api	32253/TCP
	Endpoints:		10.2.79.173:443
	Session Affinity:	None
	Events:
	  FirstSeen	LastSeen	Count	From			SubObjectPath	Type		Reason			Message
	  ---------	--------	-----	----			-------------	--------	------			-------
	  33m		33m		1	service-controller			Normal		CreatingLoadBalancer	Creating load balancer
	  33m		33m		1	service-controller			Normal		CreatedLoadBalancer		Created load balancer


Describe the sdc-collector service to see the full collector endpoint URL. It will be `ad0e5cf87c70611e79d6006e5a830746-257288196.us-west-1.elb.amazonaws.com` in this case. This will be the URL that agents (frontend) use to connect to this backend.

	$ kds sdc-collector
	Name:			sdc-collector
	Namespace:		sysdigcloud
	Labels:			app=sysdigcloud
				role=collector
	Annotations:		<none>
	Selector:		app=sysdigcloud,role=collector
	Type:			LoadBalancer
	IP:			10.3.0.203
	LoadBalancer Ingress:	ad0e5cf87c70611e79d6006e5a830746-257288196.us-west-1.elb.amazonaws.com
	Port:			secure-collector	6443/TCP
	NodePort:		secure-collector	31063/TCP
	Endpoints:		10.2.23.211:6443
	Session Affinity:	None
	Events:
	  FirstSeen	LastSeen	Count	From			SubObjectPath	Type		Reason			Message
	  ---------	--------	-----	----			-------------	--------	------			-------
	  34m		34m		1	service-controller			Normal		CreatingLoadBalancer	Creating load balancer
	  33m		33m		1	service-controller			Normal		CreatedLoadBalancer		Created load balancer



## What does the installer do? <a id="What-does-the-installer-do?"></a>

1. It creates a namespace called *sysdigcloud* where all components are deployed.

	`kubectl create namespace sysdigcloud`

2. It creates Kubernetes secrets and configMaps populated with infromation about usernames, passwords, ssl certs, quay.io pull secret and various application specific parameters.

	`kubectl create -f etc/sdc-config.yaml`

3. Create Kubernetes StorageClasses identifying the types of disks to be provided to our datastores.

	`kubectl create -R -f datastores/storageclasses/`

4. Creates the datastore Statefulsets (redis, mysql, elasticsearch and cassandra). Elasticsearch and Cassandra are automatically setup with --replica=3 generating full clusters. Redis and mysql are configured with master/slave replication. 

	`kubectl create -R -f datastores/`

5. Deploys the backend Deployment sets (worker, collect and api)

	`kubectl create -R -f backend/`

## Operations Guide <a id="Operations-Guide"></a>

#### Stop and Start <a id="Stop-and-Start"></a>

You can stop the whole application by running `uninstall.sh`. It will save the namespace, storageclasses and PVC's. You can then start the application with `install.sh`. Script will complain about pre-existing elements, but the application will still be started. PVC's are preserved which means all data on redis, mysql, elasticsearch and cassandra are persisted. If you want to start with application with clean PVC's, either uninstall the application as described in the "Uninstall section" or delete PVC's manually after shutting down applications. 

You can also stop and start individual components:

###### Shutdown all backend components using their definition yaml files
```
$ pwd
~/sdc-kubernetes/aws

$ kubectl -n sysdigcloud -R -f backend/
service "sdc-api" deleted
deployment "sdc-api" deleted
service "sdc-collector" deleted
deployment "sdc-collector" deleted
deployment "sdc-worker" deleted
```

###### Shutdown Cassandra using it's yaml file
```
$ kubectl -n sysdigcloud delete -f datastore/sdc-cassandra.yaml
service "sdc-cassandra" deleted
statefulset "sdc-cassandra" deleted
```

###### Shutdown Elasticsearch and it's associated service
```
$ kubectl -n sysdigcloud get statefulsets 
NAME                DESIRED   CURRENT   AGE
sdc-elasticsearch   3         3         2d
sdc-mysql           1         1         2d
sdc-mysql-slave     3         3         2d
sdc-redis           1         1         2d
sdc-redis-slave     2         2         2d

$ kubectl -n sysdigcloud delete statefulset sdc-elasticsearch
statefulset "sdc-elasticsearch" deleted

$ kubectl -n sysdigcloud get services
NAME                CLUSTER-IP   EXTERNAL-IP   PORT(S)              AGE
sdc-elasticsearch   None         <none>        9200/TCP,9300/TCP    2d
sdc-mysql           None         <none>        3306/TCP             2d
sdc-mysql-slave     None         <none>        3306/TCP             2d
sdc-redis           None         <none>        6379/TCP,16379/TCP   2d
sdc-redis-slave     None         <none>        6379/TCP,16379/TCP   2d

$ kubectl -n sysdigcloud delete service sdc-elasticsearch
service "sdc-elasticsearch" deleted
```

###### Start Components one by one
```
$ pwd
~/sdc-kubernetes/aws

$ kubectl create -f etc/sdc-config.yaml
$ kubectl create -f datastores/sdc-mysql-master.yaml 
$ kubectl create -f datastores/sdc-mysql-slaves.yaml 
$ kubectl create -f datastores/sdc-redis-master.yaml 
$ kubectl create -f datastores/sdc-redis-slaves.yaml 
$ kubectl create -f datastores/sdc-cassandra.yaml  
$ kubectl create -f datastores/sdc-elasticsearch.yaml 
$ kubectl create -f backend/sdc-api.yaml
$ kubectl create -f backend/sdc-colector.yaml
$ kubectl create -f backend/sdc-worker.yaml

```

#### Scale up and down <a id="Scale-up-and-down"></a>

You can scale up and down any sdc-kubernetes component. 

For worker, collector and api which are deployed as Deployment sets, do:
```
$kubectl -n sysdigcloud scale --replicas=5 deployment sdc-api
$kubectl -n sysdigcloud scale --replicas=5 deployment sdc-collector
$kubectl -n sysdigcloud scale --replicas=5 deployment sdc-worker

$ for i in sdc-api sdc-collector sdc-worker; do kubectl -n sysdigcloud --replicas=1 $i; done
```

For the datastores, redis, mysql, elasticsearch and cassandra, which are deployed as Statefulsets, do:
```
#scale up or down depending on existing number of copies
$kubectl -n sysdigcloud scale --replicas=4 statefulset sdc-cassandra
$kubectl -n sysdigcloud scale --replicas=4 statefulset sdc-elasticsearch
$kubectl -n sysdigcloud scale --replicas=4 statefulset sdc-mysql-slave
$kubectl -n sysdigcloud scale --replicas=4 statefulset sdc-redis-slave
```


#### Modifying configMap <a id="Modifying-configMap"></a>

This deployment creates a bunch of configMaps:
```
yofti-macbook2:aws yoftimakonnen$ kubectl -n sysdigcloud get configmap
NAME                             DATA      AGE
sysdigcloud-config               48        2d
sysdigcloud-mysql-config         7         2d
sysdigcloud-mysql-config-slave   7         2d
sysdigcloud-redis-config         2         2d
sysdigcloud-redis-config-slave   2         2d

```

You can edit a particular configMap:
`$kubectl -n sysdigcloud edit configmap sysdigcloud-config`

The preferred method would be to edit the file `etc/sdc-config.yaml` and replace the whole configMap set
```
$vi etc/sdc-config.yaml
$kubectl -n sysdigcloud replace configmap -f etc/sdc-config.yaml
```

After updating the ConfigMap, the Sysdig Cloud components need to be restarted in order for the changed parameters to take effect. This can be done by simply forcing a rolling update of the deployments. A possible way to do so is:

```
kubectl patch deployment sdc-api -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}" --namespace sysdigcloud
kubectl patch deployment sdc-collector -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}" --namespace sysdigcloud
kubectl patch deployment sdc-worker -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}" --namespace sysdigcloud
```

This will ensure that the application restarts with no downtime (assuming the deployments have more than one replica each).


#### Version updates <a id="Version-updates"></a>

Sysdig Cloud releases are listed [here](https://github.com/draios/sysdigcloud-kubernetes/releases). Each release has a version number (e.g. 702) and specific upgrade notes. If you look in the 3 backend files `backend/sdc-api.yaml`, `backend/sdc-collector.yaml` and `backend/sdc-worker.yaml`, you will see the following identical line in all of them under their container/image defintions:
```
image: quay.io/sysdig/sysdigcloud-backend:658
```
In this case, we are running version 658 of the backend. 

To upgrade to version 702 (the latest), we have two options:

1. Edit the backend files' yaml defintions. Add the right tag for the image `sysdigcloud-backend` like:
```
image: quay.io/sysdig/sysdigcloud-backend:658
```
and restart the app.

2. You can do a rolling update if downtimes are sensitive.
```
kubectl set image deployment/sdc-api api=quay.io/sysdig/sysdigcloud-backend:702 --namespace sysdigcloud
kubectl set image deployment/sdc-collector collector=quay.io/sysdig/sysdigcloud-backend:702 --namespace sysdigcloud
kubectl set image deployment/sdc-worker worker=quay.io/sysdig/sysdigcloud-backend:702 --namespace sysdigcloud
```

#### Uninstall <a id="Uninstall"></a>

To completely remove the sdc-kubernetes application, run the following commands
```
$uninstall.sh
$kubectl delete namespace sysdigcloud
```
This will shutdown all components and by destorying the namespace, it will destroy the PVC's.

NB: This step destroys data. Irretrievably.  


## Tips and Tricks <a id="Tips-and-Tricks"></a>

* Use aliases. 

Too much typing with kubectl

```
$alias
alias k='kubectl'
alias kc='kubectl create'
alias kd='kubectl describe'
alias kdd='kubectl describe deployment'
alias kdds='kubectl describe daemonset'
alias kdl='kubectl delete'
alias kdp='kubectl describe pod'
alias kdrc='kubectl describe rc'
alias kdrs='kubectl describe rs'
alias kds='kubectl describe service'
alias kdss='kubectl describe statefulset'
alias ke='kubectl exec -i -t'
alias kg='kubectl get'
alias kgc='kubectl get configmap'
alias kgd='kubectl get deployment'
alias kgds='kubectl get daemonset'
alias kgn='kubectl get nodes'
alias kgns='kubectl get namespace'
alias kgp='kubectl get pods'
alias kgpv='kubectl get pv'
alias kgpvc='kubectl get pvc'
alias kgrc='kubectl get rc'
alias kgrs='kubectl get rs'
alias kgs='kubectl get svc'
alias kgsc='kubectl get storageclass'
alias kgss='kubectl get statefulset'
alias kl='kubectl logs'
alias klf='kubectl logs -f'
```
* Master your Kubectl configs and contexts

You might have multiple kubernetes clusters that you are managing. Each one has a context. Setting namespace in your context will save you from supplying --namespace flags.

```
$ k config get-clusters
NAME
gke_whole-cloth-182215_us-west1-a_yofti-gcp-k8-cluster
kube-aws-k8s-yoftilabs-com-cluster
gke_sysdig-disney_us-central1-a_sysdig-disney-dev
gke_sysdig-disney_us-west1-a_sysdig-disney
$ k config get-contexts
CURRENT   NAME                                                     CLUSTER                                                  AUTHINFO                                                 NAMESPACE
          gke_whole-cloth-182215_us-west1-a_yofti-gcp-k8-cluster   gke_whole-cloth-182215_us-west1-a_yofti-gcp-k8-cluster   gke_whole-cloth-182215_us-west1-a_yofti-gcp-k8-cluster   sysdigcloud
*         kube-aws-k8s-yoftilabs-com-context                       kube-aws-k8s-yoftilabs-com-cluster                       kube-aws-k8s-yoftilabs-com-admin                         sysdigcloud
          gke_sysdig-disney_us-central1-a_sysdig-disney-dev        gke_sysdig-disney_us-central1-a_sysdig-disney-dev        gke_sysdig-disney_us-central1-a_sysdig-disney-dev        sysdigcloud
          gke_sysdig-disney_us-west1-a_sysdig-disney               gke_sysdig-disney_us-west1-a_sysdig-disney               gke_sysdig-disney_us-west1-a_sysdig-disney               sysdigcloud
$ k config current-context
kube-aws-k8s-yoftilabs-com-context
$ k config set current-context gke_sysdig-disney_us-west1-a_sysdig-disney --namespace sysdigcloud
Property "current-context" set.
$ k config current-context
gke_sysdig-disney_us-west1-a_sysdig-disney
$ k config get-contexts
CURRENT   NAME                                                     CLUSTER                                                  AUTHINFO                                                 NAMESPACE
          kube-aws-k8s-yoftilabs-com-context                       kube-aws-k8s-yoftilabs-com-cluster                       kube-aws-k8s-yoftilabs-com-admin                         sysdigcloud
          gke_sysdig-disney_us-central1-a_sysdig-disney-dev        gke_sysdig-disney_us-central1-a_sysdig-disney-dev        gke_sysdig-disney_us-central1-a_sysdig-disney-dev        sysdigcloud
*         gke_sysdig-disney_us-west1-a_sysdig-disney               gke_sysdig-disney_us-west1-a_sysdig-disney               gke_sysdig-disney_us-west1-a_sysdig-disney               sysdigcloud
          gke_whole-cloth-182215_us-west1-a_yofti-gcp-k8-cluster   gke_whole-cloth-182215_us-west1-a_yofti-gcp-k8-cluster   gke_whole-cloth-182215_us-west1-a_yofti-gcp-k8-cluster   sysdigcloud

```


