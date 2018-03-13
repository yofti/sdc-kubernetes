#!/bin/bash
# This is expected to run as root for setting the ulimits

set -e
args=("$@")
if [ ! -z "${ELASTICSEARCH_SERVICE}" ]; then
	#running in kubernetes
	ip=$(hostname -i)
	args+=("-Enode.name=$ip")
	args+=("-Enetwork.host=$ip")

	args+=("-Ediscovery.zen.ping.unicast.hosts=$ELASTICSEARCH_SERVICE")

	if [ ! -z "$ELASTICSEARCH_MINIMUM_MASTER_NODES" ]; then
		args+=("-Ediscovery.zen.minimum_master_nodes=$ELASTICSEARCH_MINIMUM_MASTER_NODES")
	fi

	if [ ! -z "$ELASTICSEARCH_CLUSTER_NAME" ]; then
		args+=("-Ecluster.name=$ELASTICSEARCH_CLUSTER_NAME")
	fi
fi

chown -R elasticsearch:elasticsearch /usr/share/elasticsearch
su -s /bin/bash elasticsearch -c 'elasticsearch '"$(echo ${args[@]})"''

# running command to start elasticsearch
# passing all inputs of this entry point script to the es-docker startup script
# NOTE: this entry point script is run as root; but executes the es-docker
# startup script as the elasticsearch user, passing all the root environment-variables 
# to the elasticsearch user 
#su elasticsearch bin/es-docker "$@"
