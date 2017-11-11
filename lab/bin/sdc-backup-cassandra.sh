#!/bin/bash


#This script runs on a pod named sdc-backup-server in the DEV GKE cluster.
#It backs up a production cassandra cluster running in a PROD GKE cluster by taking snapshots of keyspaces in $KEYSPACES.
#It copies the snapshots from the PROD cassandra pods into locally mounted disks.
#The locally mounted target disks are the PVC's of development's cassandra pods.
#/mnt/sdc-cassandra-{0,1,2}/data/ will be the target destination for PROD's sdc-cassandra-0:/var/lib/cassandra/data
#
#This script uses kubectl cp to transfer files between two different Kubernetes clusters.
#As long as there is IP connectivity to the Kubernetes end-point, this method should work.
#
#There is no logging for now. So run this program as "./sdc-backup-cassandra.sh | tee backup.log"
#Analyze the backup.log for any missed files. It will report every snapshot and file copied.

KEYSPACES=('system' 'draios')
CASSANDRA_NODES=('sdc-cassandra-0' 'sdc-cassandra-1' 'sdc-cassandra-2')
SOURCE_BASE=/var/lib/cassandra/data
#DEST_BASE=/mnt/$server/data (This is where destination disks are mounted locally)

#Prepare target disks.
#Remove datafiles from keyspace directories but save the directories.
#Remove commitlogs

for server in ${CASSANDRA_NODES[@]}; do
	echo "removing contents of /mnt/$server/commitlog from local drives ..."
	rm -rf /mnt/$server/commitlog/*
	for keyspace in ${KEYSPACES[@]}; do
		echo "removing contents of /mnt/$server/data/${keyspace}/ from local drives ..."
		rm -rf /mnt/$server/data/${keyspace}/*
	done
done


#For each cassandra node and each keyspace
# - clear pre-existing snapshots for keyspace
# - generate a folder_list for keyspace
# - for each folder (i.e column) in folder_list
# 		- take a snapshot; grab name of snapshot dir
#		- kubectl cp snapshots from prod to local machine


for server in ${CASSANDRA_NODES[@]}; do
	for keyspace in ${KEYSPACES[@]}; do
		echo "Clearing snapshots on PROD Server $server for keyspace ${keyspace} ..."
		kubectl exec ${server} -n sysdigcloud -- nodetool clearsnapshot ${keyspace}
		declare -a FOLDER_LIST=`kubectl exec ${server} -n sysdigcloud -- ls -1 ${SOURCE_BASE}/${keyspace}`
		echo "Taking snapshot of the ${keyspace} keyspace on PROD Server $server ..."
		snapdir=`kubectl exec $server -n sysdigcloud -- nodetool snapshot ${keyspace}|grep directory|awk '{print $3}'`
		echo "We got snapdir of $snapdir from our snapshot of $server on keyspace ${keyspace}"
		for folder in ${FOLDER_LIST[@]}; do
			echo "Copying from ${server}:${SOURCE_BASE}/${keyspace}/${folder}/snapshots/${snapdir}/ to /mnt/${server}/data/${keyspace}/${folder}/ ..."
			kubectl cp -n sysdigcloud ${server}:${SOURCE_BASE}/${keyspace}/${folder}/snapshots/${snapdir}/  /mnt/${server}/data/${keyspace}/${folder}/
		done
	done
done

#Take a backup of the draios schema
#echo "taking a backup of non-system keyspace schema's and saving them to a local file ..."
#kubectl exec sdc-cassandra-0 -n sysdigcloud -- cqlsh -e "describe schema" > draios.schema
