# sdc-kubernetes: Sysdig Cloud Monitor Backend on Kubernetes

## Infrastructure Overview 
![] (files/sdc-k8s-architecture.png)

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

## Requirements

- Access to a running Kubernetes cluster on AWS or GKE.
- Sysdig Cloud quay.io pull secret
- Sysdig Cloud license
- kubectl installed on your machine and communicating with the Kubernetes cluster

## Installation Guide

1. Clone this repository to your machine
	`git clone https://github.com/yofti/sdc-kubernetes`
2. Edit the file *etc/sdc-config.yaml*
	* On line 7, find the entry *.dockerconfigjson*. Add your quay.io secret.
	* On line 17, find the entry *sysdigcloud.license*. Add the contents of your license (uri) file. 
	* All configurable parameters for this applications are in this file. 
3. `cd aws` or `cd gke` depending on your cloud provider.
4. Run ./install.sh


## Operations Guide

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

	$ kgs
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

	$ kds sdc-api
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
	  33m		33m		1	service-controller			Normal		CreatedLoadBalancer	Created load balancer


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
	  33m		33m		1	service-controller			Normal		CreatedLoadBalancer	Created load balancer



## What does the installer do?

1. It creates a namespace called *sysdigcloud* where all components are deployed.

	`kubectl create namespace sysdigcloud`

2. It creates Kubernetes secrets and configMaps populated with infromation about usernames, passwords, ssl certs, quay.io pull secret and various application specific parameters.

	`kubectl create -f etc/sdc-config.yaml`

3. Create Kubernetes StorageClasses identifying the types of disks to be provided to our datastores.

	`kubectl create -R -f datastores/storageclasses/`

4. Creates the datastore Statefulsets (redis, mysql, elasticsearch and cassandra). Elasticsearch and Cassandra are automatically setup with --replica=3 generating full clusters. Redis and mysql are configured with master/slave replication. 

	`kubectl create -R -f datastores/`

5. Deploys the backend Deployment sets (worker, collect and api)

	`kubectl create -R -f backend`
