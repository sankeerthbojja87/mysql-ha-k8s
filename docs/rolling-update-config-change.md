# Rolling Update And Config Propagation

This runbook captures the practiced MySQL InnoDB Cluster config rollout scenario.

## Goal

Change `max_connections` from `150` to `200` across all MySQL InnoDB Cluster members and validate the change end to end.

This scenario demonstrates the difference between:

- desired state in the `InnoDBCluster` custom resource
- generated operator-managed ConfigMap
- mounted MySQL config inside the pod
- actual MySQL runtime value

## 1. Baseline Cluster Health

```bash
kubectl config set-context --current --namespace=mysql-ha

kubectl get innodbcluster mysql-ha -o wide
kubectl get pods -o wide
kubectl get pvc
```

Expected:

```text
STATUS ONLINE
ONLINE 3
INSTANCES 3
ROUTERS 1
```

Check Group Replication members:

```bash
kubectl exec -it mysql-ha-0 -c mysql -- \
  mysql -uroot -p'RootPass-MySQL-HA-Lab-123!' \
  -e "
SELECT MEMBER_HOST, MEMBER_ROLE, MEMBER_STATE
FROM performance_schema.replication_group_members;
"
```

## 2. Patch Desired State

Patch the `InnoDBCluster` custom resource:

```bash
kubectl patch innodbcluster mysql-ha \
  --type=merge \
  -p '{"spec":{"mycnf":"[mysqld]\nmax_connections=200\nslow_query_log=ON\nlong_query_time=1\nlog_output=TABLE\n"}}'
```

Validate the CR spec:

```bash
kubectl get innodbcluster mysql-ha -o yaml | grep -A8 "mycnf:"
```

Expected:

```text
max_connections=200
```

## 3. Validate Runtime State

Check all MySQL members:

```bash
for pod in mysql-ha-0 mysql-ha-1 mysql-ha-2; do
  echo "==== $pod ===="
  kubectl exec -it $pod -c mysql -- \
    mysql -uroot -p'RootPass-MySQL-HA-Lab-123!' \
    -e "SHOW VARIABLES LIKE 'max_connections';"
done
```

In the practiced lab, runtime still showed:

```text
max_connections = 150
```

That means the CR desired state changed, but running MySQL did not.

## 4. Roll StatefulSet

```bash
kubectl rollout restart statefulset/mysql-ha
kubectl rollout status statefulset/mysql-ha
```

The rollout completed:

```text
partitioned roll out complete: 3 new pods have been updated
```

But runtime still showed:

```text
max_connections = 150
```

This proved that pod restart alone was not enough because the mounted config source still had the old value.

## 5. Trace The Config Source

Inspect active config inside the pod:

```bash
kubectl exec -it mysql-ha-0 -c mysql -- \
  sh -c "grep -R \"max_connections\" /etc/my.cnf /etc/mysql /etc/my.cnf.d /var/lib/mysql 2>/dev/null | head -50"
```

Observed:

```text
/etc/my.cnf.d/99-extra.cnf:max_connections=150
```

Find the generated ConfigMap:

```bash
kubectl get configmap
kubectl get configmap mysql-ha-initconf -o yaml | grep -A10 "99-extra.cnf"
```

Observed:

```yaml
99-extra.cnf: |
  # Additional user configurations taken from spec.mycnf in InnoDBCluster.
  # Do not edit directly.
  [mysqld]
  max_connections=150
```

So the config chain looked like this:

```text
InnoDBCluster CR spec = 200
operator-generated ConfigMap = 150
mounted /etc/my.cnf.d/99-extra.cnf = 150
MySQL runtime = 150
```

## 6. Lab-Only ConfigMap Correction

For lab learning, patch the generated ConfigMap directly:

```bash
kubectl patch configmap mysql-ha-initconf \
  --type merge \
  -p '{"data":{"99-extra.cnf":"# Additional user configurations taken from spec.mycnf in InnoDBCluster.\n# Do not edit directly.\n[mysqld]\nmax_connections=200\nslow_query_log=ON\nlong_query_time=1\nlog_output=TABLE\n"}}'
```

Validate:

```bash
kubectl get configmap mysql-ha-initconf -o yaml | grep -A10 "99-extra.cnf"
```

Roll the StatefulSet again:

```bash
kubectl rollout restart statefulset/mysql-ha
kubectl rollout status statefulset/mysql-ha
```

Validate runtime:

```bash
for pod in mysql-ha-0 mysql-ha-1 mysql-ha-2; do
  echo "==== $pod ===="
  kubectl exec -it $pod -c mysql -- \
    mysql -uroot -p'RootPass-MySQL-HA-Lab-123!' \
    -e "SHOW VARIABLES LIKE 'max_connections';"
done
```

Expected:

```text
max_connections = 200
```

## 7. Post-Change Cluster Health

Check Group Replication after the rollout:

```bash
kubectl exec -it mysql-ha-0 -c mysql -- \
  mysql -uroot -p'RootPass-MySQL-HA-Lab-123!' \
  -e "
SELECT MEMBER_HOST, MEMBER_ROLE, MEMBER_STATE
FROM performance_schema.replication_group_members;
"
```

Check Router connectivity:

```bash
kubectl run mysql-ha-client --rm -it \
  --image=mysql:8.4 \
  --restart=Never \
  -- mysql -hmysql-ha -uroot -p'RootPass-MySQL-HA-Lab-123!' \
  -e "SELECT @@hostname, @@version, @@read_only, @@max_connections;"
```

## Production Notes

Directly editing `mysql-ha-initconf` is a lab-only mitigation because the ConfigMap says:

```text
Do not edit directly.
```

In production:

- confirm supported operator workflow for config changes
- validate CR desired state
- validate generated config
- validate runtime values
- restart members in a controlled order
- check Group Replication health after each member
- avoid manual edits to operator-generated resources unless doing an emergency mitigation

For dynamic parameters, a short-term mitigation can be:

```sql
SET GLOBAL max_connections = 200;
```

But `SET GLOBAL` is not durable across restart unless persisted through the correct config path.

## Interview Framing

> I tested a MySQL config rollout on an operator-managed InnoDB Cluster. The custom resource accepted the desired value, but runtime validation showed the old value. I traced the active config from MySQL runtime to `/etc/my.cnf.d/99-extra.cnf`, then back to the operator-generated `mysql-ha-initconf` ConfigMap. After correcting the generated config in the lab and rolling the StatefulSet, all members picked up `max_connections=200`. The key lesson is to validate desired state, generated config, mounted config, and runtime state separately.

