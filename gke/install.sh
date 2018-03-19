#!/bin/bash

LOG_FILE=logs/install/install-$(date "+%Y.%m.%d-%H.%M.%S").log
QUAY_FILE="etc/licenses/quay.uri"
LICENSE_FILE="etc/licenses/license.uri"
CONFIG_FILE="etc/sdc-config.yaml"
CLOUD_PROVIDER="GKE"
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
echo "This is the Sysdig Monitor on-prem Kubernetes installer." 					 | tee -a $LOG_FILE
echo "This installer assumes you have a running kubernetes cluster on AWS or GKE."   | tee -a $LOG_FILE 
echo "The executable 'kubectl' needs to be in your \$PATH."       					 | tee -a $LOG_FILE 
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" | tee -a $LOG_FILE

echo | tee -a $LOG_FILE
echo | tee -a $LOG_FILE

echo "Your current kubectl client and server version are as follows:" | tee -a $LOG_FILE				
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"| tee -a $LOG_FILE 
K8S_CLIENT_VERSION=`kubectl version | egrep ^Client | awk -F, '{print $3}'`
K8S_SERVER_VERSION=`kubectl version | egrep ^Server | awk -F, '{print $3}'`
echo "Client: $K8S_CLIENT_VERSION| tee -a $LOG_FILE"
echo "Server: $K8S_SERVER_VERSION"| tee -a $LOG_FILE
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" | tee -a $LOG_FILE
echo
echo

echo "Your current Kubernetes context is:"| tee -a $LOG_FILE
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"| tee -a $LOG_FILE
CURRENT_CONTEXT=`kubectl config get-contexts|egrep '^\*'|awk '{print $2}'`
CURRENT_CLUSTER=`kubectl config get-contexts|egrep '^\*'|awk '{print $3}'`
echo "Current Context: $CURRENT_CONTEXT"| tee -a $LOG_FILE
echo "Current Cluster: $CURRENT_CLUSTER"| tee -a $LOG_FILE
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo| tee -a $LOG_FILE
echo| tee -a $LOG_FILE

echo "Your current Kubernetes cluster on $CLOUD_PROVIDER is:"| tee -a $LOG_FILE
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"| tee -a $LOG_FILE
kubectl cluster-info| tee -a $LOG_FILE
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"| tee -a $LOG_FILE
echo 

echo "Do you wish to install backend version $BACKEND_VERSION of sdc-kubernetes along with agents with version $FRONTEND_VERSION?"| tee -a $LOG_FILE
select yn in "Yes" "No"; do
    case $yn in
        Yes ) break;;
        No ) exit 1;;
    esac
done

# create namespace if it doesn't exist
kubectl get namespace sysdigcloud >> $LOG_FILE 2>&1
if [ $? -ne 0 ]	; then
	kubectl create namespace sysdigcloud >> $LOG_FILE 2>&1 
	if [ $? -eq 0 ] ; then
		echo "... namespace sysdigcloud created."| tee -a $LOG_FILE
	else
		echo "... failed to create namespace sysdigcloud."| tee -a $LOG_FILE
		exit 1
	fi
else 
	echo "... namespace sysdigcloud already exists."| tee -a $LOG_FILE
fi

# create storageclasses
kubectl create -f datastores/storageclasses/ >> $LOG_FILE 2>&1
#if [ $? -ne 0 ]; then
#	echo "...failed to create storageclasses."
#	exit 1
#fi

# creating ssl certs
openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -subj \
"/C=US/ST=CA/L=SanFrancisco/O=ICT/CN=sysdig.yoftilabs.com" \
-keyout etc/certs/server.key -out etc/certs/server.crt >> $LOG_FILE 2>&1

if [ $? -ne 0 ]; then
	echo "... failed to create ssl certs."| tee -a $LOG_FILE
	exit 1
else
	echo "... ssl certs created."| tee -a $LOG_FILE
fi


#create ssl-secret in kubernetes if it doesn't exist already
kubectl get secret sysdigcloud-ssl-secret --namespace sysdigcloud>> $LOG_FILE 2>&1
if [ $? -ne 0 ]	; then
	kubectl create secret tls sysdigcloud-ssl-secret --cert=etc/certs/server.crt --key=etc/certs/server.key --namespace=sysdigcloud >> $LOG_FILE 2>&1
	if [ $? -ne 0 ]; then
		echo "... failed to create ssl secret in kubernetes."| tee -a $LOG_FILE
		exit 1
	else
		echo "... ssl secret created in kubernetes. "| tee -a $LOG_FILE
	fi
else
	echo "... ssl secret sysdigcloud-ssl-secret already exists."| tee -a $LOG_FILE
fi

if [ -e $QUAY_FILE ]; then
	quay_key=`cat $QUAY_FILE`
else
	echo "... failed to find $QUAY_FILE" | tee -a $LOG_FILE
	echo "... make sure you have the sysdig provided quay secret file under sdc-kubernetes/$QUAY_FILE" | tee -a $LOG_FILE
	exit 1
fi

if [ -e $LICENSE_FILE ]; then
	license_key=`cat $LICENSE_FILE`
else
	echo "... failed to find $LICENSE_FILE" | tee -a $LOG_FILE
	echo "... make sure you have the sysdig provided licene file under sdc-kubernetes/$LICENSE_FILE" | tee -a $LOG_FILE
	exit 1
fi

#insert quay and license keys into the Configmap file
#hack to avoid posting license and quay key to github
sed -i .bak "s/.dockerconfigjson: \"\"/.dockerconfigjson: \"${quay_key}\"/" $CONFIG_FILE
sed -i .bak "s/sysdigcloud.license: \"\"/sysdigcloud.license: \"${license_key}\"/" $CONFIG_FILE

kubectl get configmap sysdigcloud-config >> $LOG_FILE 2>&1
if [ $? -ne 0 ]	; then
	kubectl create -f $CONFIG_FILE || error_exit "... unable to create configmap. Exiting." | tee -a $LOG_FILE
	if [ $? -ne 0 ]; then
		echo "... failed to create configmap in kubernetes."| tee -a $LOG_FILE
		exit 1
	else
		echo "... configmaps created in kubernetes. "| tee -a $LOG_FILE
	fi
else
	echo "...  configmap already exists."| tee -a $LOG_FILE

fi

#revert quay and license keys from the Configmap file
#hack to avoid posting license and quay key to github
sed -i .bak "s/.dockerconfigjson: \"${quay_key}\"/.dockerconfigjson: \"\"/" $CONFIG_FILE
sed -i .bak "s/sysdigcloud.license: \"${license_key}\"/sysdigcloud.license: \"\"/" $CONFIG_FILE

rm ${CONFIG_FILE}.bak 

#
#kubectl create -f etc/sdc-rbac.yaml  | tee -a $LOG_FILE
kubectl create -f datastores/sdc-mysql-master.yaml  | tee -a $LOG_FILE
kubectl create -f datastores/sdc-redis-master.yaml | tee -a $LOG_FILE
kubectl create -f datastores/sdc-redis-slaves.yaml | tee -a $LOG_FILE
kubectl create -f datastores/sdc-cassandra.yaml  | tee -a $LOG_FILE
kubectl create -f datastores/sdc-elasticsearch.yaml | tee -a $LOG_FILE
kubectl create -f datastores/sdc-mysql-slaves.yaml | tee -a $LOG_FILE
#
echo "... sleeping 60 before starting backend. " | tee -a $LOG_FILE
sleep 60
kubectl create  -f backend/sdc-api.yaml | tee -a $LOG_FILE
kubectl create  -f backend/sdc-worker.yaml | tee -a $LOG_FILE
kubectl create  -f backend/sdc-collector.yaml | tee -a $LOG_FILE
#
echo
echo "... app successfully submitted to kubernetes ..." | tee -a $LOG_FILE
echo "... monitor application by using \`watch kubectl get pods -n sysdigcloud \`" | tee -a $LOG_FILE
echo "... wait until the sdc-api, sdc-collector and sdc-worker pods are started. " | tee -a $LOG_FILE
echo
echo
echo 
kubectl get pods -n sysdigcloud| tee -a $LOG_FILE 








