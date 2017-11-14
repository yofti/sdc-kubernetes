#!/bin/bash

kubectl delete -f etc/sdc-config.yaml 
kubectl delete secret sysdigcloud-ssl-secret -n sysdigcloud

kubectl delete -R -f backend/
kubectl delete -R -f frontend/

kubectl delete -f datastores/sdc-mysql-master.yaml &
kubectl delete -f datastores/sdc-mysql-slaves.yaml &
kubectl delete -f datastores/sdc-redis-master.yaml &
kubectl delete -f datastores/sdc-redis-slaves.yaml &
kubectl delete -f datastores/sdc-cassandra.yaml & 
kubectl delete -f datastores/sdc-elasticsearch.yaml &

#NB: deleting namespace will delete PVCs
#kubectl delete namespace sysdigcloud 
