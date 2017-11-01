# Datastores as Kubernetes pod

Sysdig Cloud datastores can be deployed as Kubernetes pods. For simple cases like testing or demo, the use of a local volume (emptyDir) might be acceptable.
Local voumes are ephemeral and they only exist for the life of the pod. Worse yet, they are tied to the host the pod is running on. Such pods can't migrate between hosts. 

For production, the use of Persistent Volumes (PV) is highly recommended. This usually requires a storage provider.
Storage can come from public cloud providers (AWS, GCE) or local cloud providers (vSphere, OpenStack cinder). 
These volumes will persist even if the pod is destroyed and they facilitate features like Snapshot backups or AMI clones.
PVs usually have to be pre-created before a pod can mount them.
Refer to http://kubernetes.io/docs/user-guide/persistent-volumes/

Persistent Volume Claims (PVC) improve on PV's by making volume usage by pods dynamic. They allow for pods to request and create volumes at run-time.
When running Kubernetes on AWS or GCE, you will **not** need to pre-create volumes before deploying the datastore pods.
The pods will use a PVC's to dynamically request and mount disks from the cloud provider.
A pod's PVC will be automatically converted into a PV (persistent volume).

Kubernetes Statefulsets are used to cluster all datastore pods. Pods in statefulset startup serially waiting for each other.
The pods will be appended whole numbers incrementally starting with 0. Kubernetes Deployments and Replication Sets accomplish the same thing.
Statefulsets add "state" to pods by allowing Persistent Volume Claims. Even though mysql is not configured in a cluster, it is still deployed as a Kubernetes statefulset rather than a deployment.

## StorageClasses

Storageclasses in Kubernetes are used to define the storage provider and the type of disk. 
Storage providers can be AWS, GCE, vSphere, Cinder and even local directories.
The Kubernetes administrator needs to create storageclass definitions before deploying pods that use PVC's.
Storageclass definitions are global and not namespace specific.

Below is a simple yaml definition for creating a storageclass on AWS.
Refer to https://kubernetes.io/docs/concepts/storage/persistent-volumes/#aws for all the details of PVC's.


```
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: aws-gp2
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp2
  zones: us-west-1b
```

Examples for creating StorageClasses on AWS and GCE are provided in the manifests directory.
Edit them paying special attention to the **name:** and **zones:** labels. 
The current installation of sysdigCloud on Kubernetes doesn't support multi-AZ (availability zone) deployments. 
Make sure the zones defined in the StorageClasses match the zones where your nodes run.

```
kubectl create -f storageclass-aws.yaml 
kubectl create -f storageclass-gce.yaml
```

Get available storageclasses on the cluster by doing:

```
$kubectl get storageclass
NAME      TYPE
aws-gp2   kubernetes.io/aws-ebs
gce-pd    kubernetes.io/gce-pd
```

It is quiet possible that the Kubernetes cluster already has StorageClasses defined.
In that case, use the pre-existing StorageClasses by using their names in the datastore yaml files.


## MySQL

To create a single SQL instance, the provided manifest under `manifests/mysql-statefulset.yaml` can be used. 
By default, it will use a Kubernetes Persistent Volume Claim (PVC) to request and create a 5 GB disk from AWS EBS.
Edit the yaml file to configure different types of volumes including emptyDir hostmounts.

NB: Destorying the mysql deployment will not delete the PVs. During subsiquent deployments, the volume ids of pre-existing volumes can be used ensuring data persistence.


Create a single mysql instance for sysdigcloud as follows:

```
kubectl create -f manifests/mysql-deployment.yaml -n sysdigcloud
```

## Redis

Redis doesn't require persistent storage, so it can be simply deployed as:

```
kubectl create -f manifests/redis.yaml -n sysdigcloud
```

## Cassandra

Before deploying the deployment object, the proper Cassandra headless service must be created (the headless service will be used for service discovery when deploying a multi-node Cassandra cluster):

```
kubectl create -f manifests/cassandra-service.yaml -n sysdigcloud
```

To create a Cassandra deployment, the provided manifest under `manifests/cassandra-statefulset.yaml` can be used. 
By default, it will create a Cassandra cluster of size 3. Each Cassandra pod uses a PVC to request and create a 5 GB volume from AWS EBS.
The Replication Factor (RF) is defined in the sysdigcloud ConfigMap. Edit the RF in the ConfigMap from 1 to 3 to get proper HA. 


```
kubectl create -f manifests/cassandra-statefulset.yaml -n sysdigcloud
```

NB: Destorying the Cassandra statefulset will not delete the PVs. During subsiquent deployments, the volume ids of pre-existing volumes can be used in the yaml file to ensure data persistence between deployments.


After the deployment, you should see 3 Cassandra pods automatically labeled with instance numbers.
```
$ kubectl get pods -n sysdigcloud
NAME                                     READY     STATUS    RESTARTS   AGE
sysdigcloud-cassandra-0                  1/1       Running   0          2h
sysdigcloud-cassandra-1                  1/1       Running   0          2h
sysdigcloud-cassandra-2                  1/1       Running   0          2h
sysdigcloud-mysql-2949046126-8dkn2       1/1       Running   0          2h
sysdigcloud-redis-518269532-cc14c        1/1       Running   0          2h
```

The cluster state can be checked as follows:

```
$ kubectl exec -i -t -n sysdigcloud sysdigcloud-cassandra-0 nodetool status
Datacenter: datacenter1
=======================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address    Load       Tokens  Owns (effective)  Host ID                               Rack
UN  10.2.4.5   33.32 MB   256     35.5%             f3a6248c-e063-45b4-a8fb-7c9612b1fdb5  rack1
UN  10.2.34.5  32.12 MB   256     30.7%             765c0d24-a8b9-4917-9c53-318b05281600  rack1
UN  10.2.34.2  36.08 MB   256     33.8%             18ce037c-4042-401d-8814-0829d9015a35  rack1
```

The Cassandra cluster can now be scaled up as shown below:

```
$kubectl get statefulsets -n sysdigcloud
NAME                        DESIRED   CURRENT   AGE
sysdigcloud-cassandra       3         3         4d

$ kubectl scale statefulsets sysdigcloud-cassandra --replicas=4 -n sysdigcloud
statefulset "sysdigcloud-cassandra" scaled
```

Let's check if we have an additional pod and see if the new Cassandra node has joined the cluster successfully:

```
$ kubectl get statefulsets -n sysdigcloud
NAME                        DESIRED   CURRENT   AGE
sysdigcloud-cassandra       4         4         4d

$ kubectl get pods -o wide -n sysdigcloud
NAME                                     READY     STATUS    RESTARTS   AGE       IP           NODE
sysdigcloud-cassandra-0                  1/1       Running   0          3h        10.2.34.5    ip-10-0-0-183.us-west-1.compute.internal
sysdigcloud-cassandra-1                  1/1       Running   1          3h        10.2.34.2    ip-10-0-0-183.us-west-1.compute.internal
sysdigcloud-cassandra-2                  1/1       Running   0          3h        10.2.4.5     ip-10-0-0-235.us-west-1.compute.internal
sysdigcloud-cassandra-3                  1/1       Running   0          1m        10.2.81.7    ip-10-0-0-100.us-west-1.compute.internal

$ kubectl exec -i -t -n sysdigcloud sysdigcloud-cassandra-0 nodetool status
Datacenter: datacenter1
=======================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address    Load       Tokens  Owns (effective)  Host ID                               Rack
UN  10.2.4.5   48.11 MB   256     28.0%             f3a6248c-e063-45b4-a8fb-7c9612b1fdb5  rack1
UN  10.2.81.7  30.27 MB   256     24.3%             589602ac-60fc-4e04-a4bd-d879050d72c0  rack1
UN  10.2.34.5  51.58 MB   256     22.5%             765c0d24-a8b9-4917-9c53-318b05281600  rack1
UN  10.2.34.2  47.62 MB   256     25.2%             18ce037c-4042-401d-8814-0829d9015a35  rack1

```

The cluster can be scaled back from 4 nodes to 3 nodes as follows:

```
$kubectl scale statefulsets sysdigcloud-cassandra --replicas=3 -n sysdigcloud
statefulset "sysdigcloud-cassandra" scaled
```

## Elasticsearch

Before deploying the statefulset object, the proper Elasticsearch headless service must be created (the headless service will be used for service discovery when deploying a multi-node Elasticsearch cluster):

```
kubectl create -f manifests/elasticsearch-service.yaml -n sysdigcloud
```

To create an Elasticsearch deployment, the provided manifest under `manifests/elasticsearch-statefulset.yaml` can be used. 
By default, it will create an ElasticSearch cluster of size 3. Each ElasticSearch pod uses a PVC to request and create a 5 GB volume from AWS EBS.


```
kubectl create -f manifests/elasticsearch-statefulset.yaml -n sysdigcloud
```

NB: Destorying the ElasticSearch statefulset will not delete the PVs. During subsiquent deployments, the volume ids of pre-existing volumes can be used in the yaml file to ensure data persistence between deployments.

After the deployment, you should see 3 ElasticSearch pods automatically labeled with instance numbers.

```
$ kubectl get pods -n sysdigcloud
NAME                                     READY     STATUS    RESTARTS   AGE       IP           NODE
sysdigcloud-elasticsearch-0              1/1       Running   0          23m       10.2.18.7    ip-10-0-0-50.us-west-1.compute.internal
sysdigcloud-elasticsearch-1              1/1       Running   0          22m       10.2.81.8    ip-10-0-0-100.us-west-1.compute.internal
sysdigcloud-elasticsearch-2              1/1       Running   0          22m       10.2.4.6     ip-10-0-0-235.us-west-1.compute.internal
```

The cluster state can be checked as follows:

```
$kubectl exec -i -t -n sysdigcloud sysdigcloud-elasticsearch-0 -- curl -sS http://10.2.18.7:9200/_cluster/health?pretty=true
{
  "cluster_name" : "sysdigcloud",
  "status" : "green",
  "timed_out" : false,
  "number_of_nodes" : 3,
  "number_of_data_nodes" : 3,
  "active_primary_shards" : 28,
  "active_shards" : 56,
  "relocating_shards" : 0,
  "initializing_shards" : 0,
  "unassigned_shards" : 0,
  "delayed_unassigned_shards" : 0,
  "number_of_pending_tasks" : 0,
  "number_of_in_flight_fetch" : 0,
  "task_max_waiting_in_queue_millis" : 0,
  "active_shards_percent_as_number" : 100.0
}

```

The ElasticSearch cluster can now be scaled up as follows:

```
$ kubectl get statefulset
NAME                        DESIRED   CURRENT   AGE
sysdigcloud-elasticsearch   3         3         41m

$ kubectl scale statefulsets sysdigcloud-elasticsearch --replicas=4 -n sysdigcloud
statefulset "sysdigcloud-elasticsearch" scaled

$ kubectl get statefulsets -n sysdigcloud
NAME                        DESIRED   CURRENT   AGE
sysdigcloud-elasticsearch   4         4         45m
```


Let's check if we have an additional pod and see if the new ElasticSearch node has joined the cluster successfully:

$ kubectl get pods -o wide -n sysdigcloud
sysdigcloud-elasticsearch-0              1/1       Running   0          46m       10.2.18.7    ip-10-0-0-50.us-west-1.compute.internal
sysdigcloud-elasticsearch-1              1/1       Running   0          46m       10.2.81.8    ip-10-0-0-100.us-west-1.compute.internal
sysdigcloud-elasticsearch-2              1/1       Running   0          45m       10.2.4.6     ip-10-0-0-235.us-west-1.compute.internal
sysdigcloud-elasticsearch-3              1/1       Running   0          2m        10.2.18.8    ip-10-0-0-50.us-west-1.compute.internal

$kubectl exec -i -t -n sysdigcloud sysdigcloud-elasticsearch-0 -- curl -sS http://10.2.18.7:9200/_cluster/health?pretty=true
{
  "cluster_name" : "sysdigcloud",
  "status" : "green",
  "timed_out" : false,
  "number_of_nodes" : 4,
  "number_of_data_nodes" : 4,
  "active_primary_shards" : 28,
  "active_shards" : 56,
  "relocating_shards" : 0,
  "initializing_shards" : 0,
  "unassigned_shards" : 0,
  "delayed_unassigned_shards" : 0,
  "number_of_pending_tasks" : 0,
  "number_of_in_flight_fetch" : 0,
  "task_max_waiting_in_queue_millis" : 0,
  "active_shards_percent_as_number" : 100.0
}

```

The cluster can be scaled back from 4 nodes to 3 nodes as follows:

```
$kubectl scale statefulsets sysdigcloud-elasticsearch --replicas=3 -n sysdigcloud
statefulset "sysdigcloud-elasticsearch" scaled
```

