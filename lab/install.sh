#!/bin/bash

kubectl create namespace sysdigcloud 
kubectl create secret generic cloudsql-instance-credentials \
    --from-file=credentials.json=etc/sysdig-disney-5a8e9c8c16ad.json -n sysdigcloud

kubectl create secret generic cloudsql-db-credentials \
     --from-literal=username=proxyuser --from-literal=password=jcHcDOFMbvFt70ef -n sysdigcloud

kubectl create -f etc/sdc-config.yaml 

openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -subj "/C=US/ST=CA/L=SanFrancisco/O=ICT/CN=sysdig.yoftilabs.com" -keyout etc/certs/server.key -out etc/certs/server.crt
kubectl create secret tls sysdigcloud-ssl-secret --cert=etc/certs/server.crt --key=etc/certs/server.key --namespace=sysdigcloud


kubectl create -f datastores/sdc-mysql-proxy.yaml &
kubectl create -f datastores/sdc-redis-master.yaml &
kubectl create -f datastores/sdc-redis-slaves.yaml &
kubectl create -f datastores/sdc-cassandra.yaml & 
kubectl create -f datastores/sdc-elasticsearch.yaml &

echo "sleep 60 before starting backend apps"
sleep 60
kubectl create -R -f backend/

echo
echo "app started ..."
echo






