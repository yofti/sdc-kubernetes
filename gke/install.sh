#!/bin/bash

# sysdigcloud on k8s install
kubectl create namespace sysdigcloud

#Edit license line
kubectl create -f sysdigcloud/config.yaml --namespace sysdigcloud

#Edit quay pull secret
kubectl create -f sysdigcloud/pull-secret.yaml --namespace sysdigcloud


# Create SSL Certs
openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -subj "/C=US/ST=CA/L=SanFrancisco/O=ICT/CN=sysdig.yoftilabs.com" -keyout server.key -out server.crt

# Upload certs as k8s secrets
kubectl create secret tls sysdigcloud-ssl-secret --cert=server.crt --key=server.key --namespace=sysdigcloud

# Deploy DataStores

kubectl create -f datastores/as_kubernetes_pods/manifests/storageclass-aws.yaml
#kubectl create -f datastores/as_kubernetes_pods/manifests/storageclass-gce.yaml
# Deploy msql 
kubectl create -f datastores/as_kubernetes_pods/manifests/mysql-statefulset.yaml --namespace sysdigcloud

# Deploy Redis
kubectl create -f datastores/as_kubernetes_pods/manifests/redis.yaml --namespace sysdigcloud

# Deploy cassandra
kubectl create -f datastores/as_kubernetes_pods/manifests/cassandra-service.yaml --namespace sysdigcloud
kubectl create -f datastores/as_kubernetes_pods/manifests/cassandra-statefulset.yaml --namespace sysdigcloud

#Deploy ElasticSearch
kubectl create -f datastores/as_kubernetes_pods/manifests/elasticsearch-service.yaml --namespace sysdigcloud
kubectl create -f datastores/as_kubernetes_pods/manifests/elasticsearch-statefulset.yaml --namespace sysdigcloud

# Expose services
kubectl create -f sysdigcloud/api-loadbalancer-service.yaml -f sysdigcloud/collector-loadbalancer-service.yaml --namespace sysdigcloud
kubectl create -f sysdigcloud/sdc-api.yaml -f sysdigcloud/sdc-collector.yaml -f sysdigcloud/sdc-worker.yaml --namespace sysdigcloud
