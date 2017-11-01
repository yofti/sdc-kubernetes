#!/bin/bash


kubectl delete -f sysdigcloud/config.yaml --namespace sysdigcloud
kubectl delete -f sysdigcloud/pull-secret.yaml --namespace sysdigcloud
kubectl delete secret tls sysdigcloud-ssl-secret --cert=server.crt --key=server.key --namespace=sysdigcloud
kubectl delete -f datastores/as_kubernetes_pods/manifests/mysql-statefulset.yaml --namespace sysdigcloud
kubectl delete -f datastores/as_kubernetes_pods/manifests/redis.yaml --namespace sysdigcloud
kubectl delete -f datastores/as_kubernetes_pods/manifests/cassandra-service.yaml --namespace sysdigcloud
kubectl delete -f datastores/as_kubernetes_pods/manifests/cassandra-statefulset.yaml --namespace sysdigcloud
kubectl delete -f datastores/as_kubernetes_pods/manifests/elasticsearch-service.yaml --namespace sysdigcloud
kubectl delete -f datastores/as_kubernetes_pods/manifests/elasticsearch-statefulset.yaml --namespace sysdigcloud
kubectl delete -f sysdigcloud/api-loadbalancer-service.yaml -f sysdigcloud/collector-loadbalancer-service.yaml --namespace sysdigcloud
kubectl delete -f sysdigcloud/sdc-api.yaml -f sysdigcloud/sdc-collector.yaml -f sysdigcloud/sdc-worker.yaml --namespace sysdigcloud
kubectl delete namespace sysdigcloud
