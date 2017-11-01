#!/bin/bash

kubectl create namespace sysdigcloud 
kubectl create -f etc/sdc-config.yaml 

openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -subj "/C=US/ST=CA/L=SanFrancisco/O=ICT/CN=sysdig.yoftilabs.com" -keyout certs/server.key -out certs/server.crt
kubectl create secret tls sysdigcloud-ssl-secret --cert=certs/server.crt --key=certs/server.key --namespace=sysdigcloud

kubectl create -f datastores/sdc-mysql-master.yaml &
kubectl create -f datastores/sdc-redis-master.yaml &
kubectl create -f datastores/sdc-cassandra.yaml & 
kubectl create -f datastores/sdc-elasticsearch.yaml &
echo "sleeping 30 before starting mysql-slaves"
sleep 30
echo "starting mysql-slaves"
kubectl create -f datastores/sdc-mysql-slaves.yaml &


#kubectl create -f backend/sdc-api.yaml -f backend/sdc-collector.yaml -f backend/sdc-worker.yaml 

echo
echo "app started ..."
echo






