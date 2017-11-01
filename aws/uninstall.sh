#!/bin/bash
kubectl delete -f etc/sdc-config.yaml 

kubectl delete -f backend/sdc-api.yaml -f backend/sdc-collector.yaml -f backend/sdc-worker.yaml 
kubectl delete secret sysdigcloud-ssl-secret 

kubectl delete -f datastores/sdc-mysql-master.yaml &
kubectl delete -f datastores/sdc-redis.yaml &
kubectl delete -f datastores/sdc-cassandra.yaml & 
kubectl delete -f datastores/sdc-elasticsearch.yaml &
kubectl delete -f datastores/sdc-mysql-slave.yaml &

#you will delete PVC's if you remove namespace
#kubectl delete namespace sysdigcloud 
