# MySQL InnoDB Cluster HA

## Architecture

```text
Application / MySQL client
        |
        v
MySQL Router Service: mysql-ha
        |
        v
MySQL Router Pod
        |
        +-- mysql-ha-0: PRIMARY
        +-- mysql-ha-1: SECONDARY
        +-- mysql-ha-2: SECONDARY
```

The MySQL Operator watches the `InnoDBCluster` custom resource and manages StatefulSets, pods, PVCs, Services, Router deployment, TLS, cluster metadata, and recovery behavior.

## Operator Install

```bash
helm repo add mysql-operator https://mysql.github.io/mysql-operator/
helm repo update
helm install mysql-operator mysql-operator/mysql-operator \
  --namespace mysql-operator \
  --create-namespace
```

The operator is installed in a separate namespace because it is the control plane. The MySQL cluster namespace is the data plane.

## HA Validation

```bash
kubectl get innodbcluster mysql-ha -o wide
kubectl get pods -o wide
kubectl get svc
kubectl get pvc
```

Expected:

```text
STATUS ONLINE
ONLINE 3
INSTANCES 3
ROUTERS 1
```

## Failover Practice

Find the primary:

```bash
kubectl exec -it mysql-ha-0 -c mysql -- \
  mysql -uroot -p'RootPass-MySQL-HA-Lab-123!' \
  -e "
SELECT MEMBER_HOST, MEMBER_ROLE, MEMBER_STATE
FROM performance_schema.replication_group_members;
"
```

Delete the primary pod:

```bash
kubectl delete pod mysql-ha-0
kubectl get pods -w
```

Validate Router still works:

```bash
kubectl run mysql-ha-client --rm -it \
  --image=mysql:8.4 \
  --restart=Never \
  -- mysql -hmysql-ha -uroot -p'RootPass-MySQL-HA-Lab-123!' \
  -e "SELECT @@hostname, @@version, @@read_only;"
```

## Interview Framing

InnoDB Cluster provides MySQL HA using Group Replication and metadata-managed membership. MySQL Router is the client-facing routing layer. Kubernetes pod readiness is not enough; validate member roles, member state, replication queues, applier errors, Router health, and actual client connectivity.

