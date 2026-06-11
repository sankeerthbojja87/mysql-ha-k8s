# Scale Out MySQL InnoDB Cluster

This runbook captures the practiced scale-out operation from a 3-node MySQL InnoDB Cluster to a 5-node cluster.

## Goal

Scale the operator-managed InnoDB Cluster:

```text
Before:
  mysql-ha-0
  mysql-ha-1
  mysql-ha-2

After:
  mysql-ha-0
  mysql-ha-1
  mysql-ha-2
  mysql-ha-3
  mysql-ha-4
```

Expected database role layout:

```text
1 PRIMARY
4 SECONDARY
all ONLINE
```

## 1. Baseline

Set namespace:

```bash
kubectl config set-context --current --namespace=mysql-ha
```

Check operator view:

```bash
kubectl get innodbcluster mysql-ha -o wide
```

Expected before scaling:

```text
STATUS   ONLINE   INSTANCES   ROUTERS
ONLINE   3        3           1
```

Check pods and storage:

```bash
kubectl get pods -o wide
kubectl get pvc
```

Check current Group Replication members:

```bash
kubectl exec -it mysql-ha-0 -c mysql -- \
  mysql -uroot -p'RootPass-MySQL-HA-Lab-123!' \
  -e "
SELECT MEMBER_HOST, MEMBER_ROLE, MEMBER_STATE
FROM performance_schema.replication_group_members;
"
```

Expected:

```text
1 PRIMARY
2 SECONDARY
all ONLINE
```

## 2. Scale From 3 To 5

Patch the `InnoDBCluster` custom resource:

```bash
kubectl patch innodbcluster mysql-ha \
  --type=merge \
  -p '{"spec":{"instances":5}}'
```

This changes desired state from:

```text
spec.instances: 3
```

to:

```text
spec.instances: 5
```

The MySQL Operator reconciles that desired state by creating:

```text
mysql-ha-3
mysql-ha-4
datadir-mysql-ha-3
datadir-mysql-ha-4
```

## 3. Watch The Scale-Out

```bash
kubectl get pods -w
```

Wait for:

```text
mysql-ha-3   2/2 Running
mysql-ha-4   2/2 Running
```

Press `Ctrl+C` after both new pods are ready.

## 4. Validate Operator Status

```bash
kubectl get innodbcluster mysql-ha -o wide
```

Expected after scaling:

```text
STATUS   ONLINE   INSTANCES   ROUTERS
ONLINE   5        5           1
```

## 5. Validate PVCs

```bash
kubectl get pvc
```

Expected PVCs:

```text
datadir-mysql-ha-0
datadir-mysql-ha-1
datadir-mysql-ha-2
datadir-mysql-ha-3
datadir-mysql-ha-4
```

Each MySQL member gets its own persistent volume claim.

## 6. Validate Group Replication

```bash
kubectl exec -it mysql-ha-0 -c mysql -- \
  mysql -uroot -p'RootPass-MySQL-HA-Lab-123!' \
  -e "
SELECT MEMBER_HOST, MEMBER_ROLE, MEMBER_STATE, MEMBER_VERSION
FROM performance_schema.replication_group_members;
"
```

Expected:

```text
1 PRIMARY
4 SECONDARY
all ONLINE
```

If `mysql-ha-0` is not reachable or no longer primary, this query can still be run from any healthy member:

```bash
kubectl exec -it mysql-ha-1 -c mysql -- \
  mysql -uroot -p'RootPass-MySQL-HA-Lab-123!' \
  -e "
SELECT MEMBER_HOST, MEMBER_ROLE, MEMBER_STATE, MEMBER_VERSION
FROM performance_schema.replication_group_members;
"
```

## 7. Validate Replication Queue And Conflicts

```bash
kubectl exec -it mysql-ha-0 -c mysql -- \
  mysql -uroot -p'RootPass-MySQL-HA-Lab-123!' \
  -e "
SELECT
  MEMBER_ID,
  COUNT_TRANSACTIONS_IN_QUEUE,
  COUNT_TRANSACTIONS_REMOTE_IN_APPLIER_QUEUE,
  COUNT_CONFLICTS_DETECTED
FROM performance_schema.replication_group_member_stats;
"
```

Healthy expectation:

```text
COUNT_TRANSACTIONS_IN_QUEUE near 0
COUNT_TRANSACTIONS_REMOTE_IN_APPLIER_QUEUE near 0
COUNT_CONFLICTS_DETECTED 0
```

## 8. Validate Router Connectivity

```bash
kubectl run mysql-ha-client --rm -it \
  --image=mysql:8.4 \
  --restart=Never \
  -- mysql -hmysql-ha -uroot -p'RootPass-MySQL-HA-Lab-123!' \
  -e "SELECT @@hostname, @@version, @@read_only, @@max_connections;"
```

Expected:

```text
@@read_only = 0
```

This means Router sent the client to a writable primary.

## 9. Scale Back Down To 3

After practice, scale back:

```bash
kubectl patch innodbcluster mysql-ha \
  --type=merge \
  -p '{"spec":{"instances":3}}'
```

Watch:

```bash
kubectl get pods -w
```

Validate:

```bash
kubectl get innodbcluster mysql-ha -o wide
kubectl get pods
kubectl get pvc
```

Depending on operator behavior, PVCs for removed members may remain for data safety. That is common and intentional.

## Production Notes

- Scale out through the operator custom resource, not by manually creating pods.
- Validate new members join Group Replication as `ONLINE`.
- Confirm PVCs are created and bound.
- Check transaction queues and applier health.
- Verify Router connectivity after scaling.
- Review capacity, quorum, failure tolerance, and operational cost before adding members.
- In production, ensure backups and monitoring cover new members automatically.

## Interview Framing

> I scaled an operator-managed MySQL InnoDB Cluster from 3 to 5 instances by patching `spec.instances` on the `InnoDBCluster` custom resource. The operator created two new MySQL members and PVCs. I validated the custom resource showed 5 online instances, confirmed Group Replication had one primary and four online secondaries, checked replication queues/conflicts, and verified application connectivity through MySQL Router.

