#!/bin/bash
set -euo pipefail

#generate sysdigcloud support bundle on kubernetes
NAMESPACE=${1}

#verify that the provided namespace exists
kubectl get namespace ${NAMESPACE} > /dev/null

LOG_DIR=$(mktemp -d sysdigcloud-support-bundle-XXXX)

SYSDIGCLOUD_PODS=($(kubectl get pods --namespace=${NAMESPACE} -l app=sysdigcloud --template '{{range .items}}{{.metadata.name}} {{end}}'))

for pod in ${SYSDIGCLOUD_PODS[@]} 
do
	echo "Getting support logs for ${pod}"
	mkdir -p ${LOG_DIR}/${pod}
	kubectl describe pod ${pod} --namespace=${NAMESPACE} > ${LOG_DIR}/${pod}/kubectl-describe.txt
	kubectl logs ${pod} --namespace=${NAMESPACE} > ${LOG_DIR}/${pod}/kubectl-logs.txt
	kubectl --namespace=${NAMESPACE} exec ${pod} -- bash -c 'tar -Ocz /var/log/sysdigcloud/ /var/log/cassandra/ /tmp/redis.log /var/log/mysql/error.log /opt/prod.conf 2>/dev/null || true' > ${LOG_DIR}/${pod}/${pod}-support-files.tgz
done

BUNDLE_NAME=$(date +%s)_sysdig_cloud_support_bundle.tgz
tar czf ${BUNDLE_NAME} ${LOG_DIR}
rm -rf ${LOG_DIR}

echo "Support bundle generated:" ${BUNDLE_NAME}

exit 0
