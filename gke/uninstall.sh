#!/bin/bash
kubectl delete -f etc/sdc-config.yaml 

kubectl delete -R -f backend/
kubectl delete secret sysdigcloud-ssl-secret 

kubectl delete -f datastores/sdc-mysql-master.yaml &
kubectl delete -f datastores/sdc-redis-master.yaml &
kubectl delete -f datastores/sdc-redis-slaves.yaml &
kubectl delete -f datastores/sdc-cassandra.yaml & 
kubectl delete -f datastores/sdc-elasticsearch.yaml &
kubectl delete -f datastores/sdc-mysql-slaves.yaml &

NB: deleting namespace deletes PVC's
#kubectl delete namespace sysdigcloud 
