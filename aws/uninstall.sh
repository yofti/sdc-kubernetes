#!/bin/bash
# uninstall.sh

LOG_FILE=logs/install/uninstall-$(date "+%Y.%m.%d-%H.%M.%S").log
QUAY_FILE="etc/licenses/quay.uri"
LICENSE_FILE="etc/licenses/license.uri"
CONFIG_FILE="etc/sdc-config.yaml"
CLOUD_PROVIDER="aws"
BACKEND_VERSION="776"
FRONTEND_VERSION="0.78.0"

error_exit()
{
	echo "$1" 1>&2 
	exit 1
}


echo > $LOG_FILE
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" 
echo 
echo "This is the Sysdig Monitor on-prem Kubernetes uninstaller." 
echo "This installer assumes you have a running kubernetes cluster on AWS or GKE." 
echo "The executable 'kubectl' needs to be in your \$PATH." 
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" 

echo 
echo 

echo "Your current kubectl client and server version are as follows:" 
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" 
K8S_CLIENT_VERSION=`kubectl version | egrep ^Client | awk -F, '{print $3}'`
K8S_SERVER_VERSION=`kubectl version | egrep ^Server | awk -F, '{print $3}'`
echo "Client: $K8S_CLIENT_VERSION"
echo "Server: $K8S_SERVER_VERSION"
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" 
echo
echo

echo "Your current Kubernetes context is:"
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
CURRENT_CONTEXT=`kubectl config get-contexts|egrep '^\*'|awk '{print $2}'`
CURRENT_CLUSTER=`kubectl config get-contexts|egrep '^\*'|awk '{print $3}'`
echo "Current Context: $CURRENT_CONTEXT"
echo "Current Cluster: $CURRENT_CLUSTER"
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo
echo

echo "Your current Kubernetes cluster on $CLOUD_PROVIDER is:"
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
kubectl cluster-info
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo 

echo "Do you wish to uninstall backend version $BACKEND_VERSION of sdc-kubernetes along with agents with version $FRONTEND_VERSION?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) break;;
        No ) exit 1;;
    esac
done

kubectl delete -f etc/sdc-config.yaml  >> $LOG_FILE 2>&1
kubectl delete -f etc/sdc-rbac.yaml  >> $LOG_FILE 2>&1
kubectl delete secret sysdigcloud-ssl-secret -n sysdigcloud  >> $LOG_FILE 2>&1
kubectl delete secret sysdigcloud-pull-secret -n sysdigcloud >> $LOG_FILE 2>&1

kubectl delete  -f frontend/ >> $LOG_FILE 2>&1 & 
kubectl delete  -f backend/sdc-api.yaml >> $LOG_FILE 2>&1 &
kubectl delete  -f backend/sdc-collector.yaml  >> $LOG_FILE 2>&1 &
kubectl delete  -f backend/sdc-worker.yaml >> $LOG_FILE 2>&1 &

kubectl delete -f datastores/sdc-mysql-master.yaml  >> $LOG_FILE 2>&1 &
kubectl delete -f datastores/sdc-mysql-slaves.yaml  >> $LOG_FILE 2>&1 &
kubectl delete -f datastores/sdc-redis-master.yaml  >> $LOG_FILE 2>&1 &
kubectl delete -f datastores/sdc-redis-slaves.yaml  >> $LOG_FILE 2>&1 &
kubectl delete -f datastores/sdc-cassandra.yaml     >> $LOG_FILE 2>&1 &
kubectl delete -f datastores/sdc-elasticsearch.yaml >> $LOG_FILE 2>&1 & 

echo "Do you wish to delete the namespace \"sysdigcloud\"?"
echo "NB: Removing the namespace will remove all Persistent Volume Claims (PVCs) and their associated Persistent Volumes (PVs)."
select yn in "Yes" "No"; do
    case $yn in
        Yes ) break;;
        No ) exit 1;;
    esac
done
kubectl delete namespace sysdigcloud 