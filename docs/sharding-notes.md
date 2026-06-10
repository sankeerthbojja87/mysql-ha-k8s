# MySQL Sharding Notes

## Key Difference From MongoDB

MongoDB has native sharding with `mongos`, config servers, shard metadata, chunks, and balancer-driven movement.

Standard MySQL does not provide the same native sharding model. MySQL sharding is usually implemented at the application layer or middleware layer using a shard key such as `tenant_id`, `customer_id`, or `account_id`.

## Manual Sharding Pattern

```text
Application
  |
  +-- customer_id % 2 = 0 -> mysql-shard-0
  +-- customer_id % 2 = 1 -> mysql-shard-1
```

## Deploy Two Shards

```bash
kubectl create namespace mysql-sharding
kubectl config set-context --current --namespace=mysql-sharding

kubectl create secret generic mysql-shard-secret \
  --from-literal=root-password='RootPass-MySQL-Shard-Lab-123!'

kubectl apply -f manifests/sharding/mysql-shards.yaml
kubectl get pods -w
```

Create schema on both shards:

```bash
for shard in mysql-shard-0 mysql-shard-1; do
  kubectl run mysql-client-$shard --rm -i --image=mysql:8.4 --restart=Never -- \
    mysql -h$shard -uroot -p'RootPass-MySQL-Shard-Lab-123!' appdb \
    -e "CREATE TABLE IF NOT EXISTS customers (
      customer_id INT PRIMARY KEY,
      name VARCHAR(100),
      region VARCHAR(50),
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );"
done
```

Insert even customer into shard 0:

```bash
kubectl run mysql-client --rm -it --image=mysql:8.4 --restart=Never -- \
  mysql -hmysql-shard-0 -uroot -p'RootPass-MySQL-Shard-Lab-123!' appdb \
  -e "INSERT INTO customers(customer_id, name, region) VALUES (1002, 'Sankeerth Even', 'US'); SELECT * FROM customers;"
```

Insert odd customer into shard 1:

```bash
kubectl run mysql-client --rm -it --image=mysql:8.4 --restart=Never -- \
  mysql -hmysql-shard-1 -uroot -p'RootPass-MySQL-Shard-Lab-123!' appdb \
  -e "INSERT INTO customers(customer_id, name, region) VALUES (1003, 'Sankeerth Odd', 'US'); SELECT * FROM customers;"
```

## Vitess

For production MySQL sharding, evaluate Vitess. It provides:

- VTGate query routing
- VTTablet sidecar/agent
- topology metadata
- VReplication workflows
- resharding operations
- backup/restore tooling
- Kubernetes-friendly operations

## Interview Framing

Standard MySQL gives replication, read replicas, and HA patterns, but not MongoDB-style native sharding. For MySQL sharding, the most important decisions are shard-key design, routing strategy, resharding process, cross-shard query handling, schema migrations, backups, and monitoring.

