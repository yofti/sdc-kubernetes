# Datastores as external services

It is possible to use one or more external datastore services that are not managed by Kubernetes. Simply edit the configuration ConfigMap and set the proper options for:

```
mysql.endpoint: <DNS/IP>
cassandra.endpoint: <DNS/IP>
redis.endpoint: <DNS/IP>
elasticsearch.url: <DNS/IP>
```

#### MySQL notes:
MySQL service requires a pre-existing schema named `draios` and character-set and collation configured to UTF-8
