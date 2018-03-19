#!/bin/bash
# uninstall.sh

LOG_FILE=logs/install/uninstall-$(date "+%Y.%m.%d-%H.%M.%S").log
QUAY_FILE="etc/licenses/quay.uri"
LICENSE_FILE="etc/licenses/license.uri"
CONFIG_FILE="etc/sdc-config.yaml"
CLOUD_PROVIDER="AWS"
BACKEND_VERSION="800"
FRONTEND_VERSION="0.78.1"

error_exit()
{
	echo "$1" 1>&2 
	exit 1
}


echo > $LOG_FILE
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" | tee -a $LOG_FILE
echo | tee -a $LOG_FILE
echo "This is the Sysdig Monitor on-prem Kubernetes uninstaller."| tee -a $LOG_FILE 
echo "This installer assumes you have a running kubernetes cluster on AWS or GKE."| tee -a $LOG_FILE 
echo "The executable 'kubectl' needs to be in your \$PATH."| tee -a $LOG_FILE 
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"| tee -a $LOG_FILE 

echo| tee -a $LOG_FILE 
echo| tee -a $LOG_FILE 

echo "Your current kubectl client and server version are as follows:"| tee -a $LOG_FILE 
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"| tee -a $LOG_FILE 
K8S_CLIENT_VERSION=`kubectl version | egrep ^Client | awk -F, '{print $3}'`
K8S_SERVER_VERSION=`kubectl version | egrep ^Server | awk -F, '{print $3}'`
echo "Client: $K8S_CLIENT_VERSION"| tee -a $LOG_FILE
echo "Server: $K8S_SERVER_VERSION"| tee -a $LOG_FILE
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"| tee -a $LOG_FILE 
echo| tee -a $LOG_FILE
echo| tee -a $LOG_FILE

echo "Your current Kubernetes context is:"| tee -a $LOG_FILE
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"| tee -a $LOG_FILE
CURRENT_CONTEXT=`kubectl config get-contexts|egrep '^\*'|awk '{print $2}'`
CURRENT_CLUSTER=`kubectl config get-contexts|egrep '^\*'|awk '{print $3}'`
echo "Current Context: $CURRENT_CONTEXT"| tee -a $LOG_FILE
echo "Current Cluster: $CURRENT_CLUSTER"| tee -a $LOG_FILE
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"| tee -a $LOG_FILE
echo| tee -a $LOG_FILE
echo| tee -a $LOG_FILE

echo "Your current Kubernetes cluster on $CLOUD_PROVIDER is:" | tee -a $LOG_FILE
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" | tee -a $LOG_FILE
kubectl cluster-info
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" | tee -a $LOG_FILE
echo | tee -a $LOG_FILE

echo "Do you wish to uninstall backend version $BACKEND_VERSION of sdc-kubernetes along with agents with version $FRONTEND_VERSION?" | tee -a $LOG_FILE
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

echo
echo
echo "... delete commands successfully submitted to kubernetes ..." | tee -a $LOG_FILE
echo "... monitor application by using \`watch kubectl get pods -n sysdigcloud \`" | tee -a $LOG_FILE
echo
echo 
kubectl get pods -n sysdigcloud| tee -a $LOG_FILE 

echo
echo
echo
echo "Do you wish to delete the namespace \"sysdigcloud\"?"
echo "NB: Removing the namespace will remove all Persistent Volume Claims (PVCs) and their associated Persistent Volumes (PVs)."
select yn in "Yes" "No"; do
    case $yn in
        Yes ) break;;
        No ) exit 1;;
    esac
done
kubectl delete namespace sysdigcloud 






