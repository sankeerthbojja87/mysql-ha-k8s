# MySQL Kubernetes Operations Runbook

## Cluster Context

```bash
kubectl config get-contexts
kubectl config current-context
kubectl get nodes -o wide
kubectl get ns
```

## Standalone Health

```bash
kubectl config set-context --current --namespace=mysql-standalone
kubectl get pods,pvc,svc
kubectl describe pod mysql-0
kubectl logs mysql-0 --tail=100
```

## InnoDB Cluster Health

```bash
kubectl config set-context --current --namespace=mysql-ha
kubectl get innodbcluster mysql-ha -o wide
kubectl describe innodbcluster mysql-ha
kubectl get pods,pvc,svc
```

Check MySQL Shell cluster status:

```bash
kubectl exec -it mysql-ha-0 -c mysql -- \
  mysqlsh root:'RootPass-MySQL-HA-Lab-123!'@localhost --js \
  -e "print(JSON.stringify(dba.getCluster().status({extended: 1}), null, 2))"
```

## Group Replication Checks

```bash
kubectl exec -it mysql-ha-0 -c mysql -- \
  mysql -uroot -p'RootPass-MySQL-HA-Lab-123!' \
  -e "
SELECT MEMBER_HOST, MEMBER_PORT, MEMBER_ROLE, MEMBER_STATE, MEMBER_VERSION
FROM performance_schema.replication_group_members;
"
```

Replication queue and conflict checks:

```bash
kubectl exec -it mysql-ha-0 -c mysql -- \
  mysql -uroot -p'RootPass-MySQL-HA-Lab-123!' \
  -e "
SELECT
  CHANNEL_NAME,
  MEMBER_ID,
  COUNT_TRANSACTIONS_IN_QUEUE,
  COUNT_TRANSACTIONS_REMOTE_IN_APPLIER_QUEUE,
  COUNT_TRANSACTIONS_CHECKED,
  COUNT_CONFLICTS_DETECTED
FROM performance_schema.replication_group_member_stats;
"
```

Applier errors:

```bash
kubectl exec -it mysql-ha-0 -c mysql -- \
  mysql -uroot -p'RootPass-MySQL-HA-Lab-123!' \
  -e "
SELECT CHANNEL_NAME, SERVICE_STATE, LAST_ERROR_NUMBER, LAST_ERROR_MESSAGE
FROM performance_schema.replication_applier_status;
"
```

## Router Troubleshooting

```bash
kubectl get deployment mysql-ha-router
kubectl describe deployment mysql-ha-router
kubectl logs -l component=mysqlrouter --tail=100
kubectl get endpoints mysql-ha -o wide
kubectl get endpointslices -l kubernetes.io/service-name=mysql-ha -o wide
```

Restart Router:

```bash
kubectl rollout restart deployment/mysql-ha-router
kubectl rollout status deployment/mysql-ha-router
```

Scale Router through the operator CR:

```bash
kubectl patch innodbcluster mysql-ha --type=merge -p '{"spec":{"router":{"instances":0}}}'
kubectl patch innodbcluster mysql-ha --type=merge -p '{"spec":{"router":{"instances":1}}}'
```

## Rolling Config Update

See [rolling-update-config-change.md](rolling-update-config-change.md) for the full practiced scenario.

Quick flow:

```bash
kubectl patch innodbcluster mysql-ha \
  --type=merge \
  -p '{"spec":{"mycnf":"[mysqld]\nmax_connections=200\nslow_query_log=ON\nlong_query_time=1\nlog_output=TABLE\n"}}'

kubectl get innodbcluster mysql-ha -o yaml | grep -A8 "mycnf:"

for pod in mysql-ha-0 mysql-ha-1 mysql-ha-2; do
  echo "==== $pod ===="
  kubectl exec -it $pod -c mysql -- \
    mysql -uroot -p'RootPass-MySQL-HA-Lab-123!' \
    -e "SHOW VARIABLES LIKE 'max_connections';"
done
```

If runtime does not match desired state, trace the config source:

```bash
kubectl exec -it mysql-ha-0 -c mysql -- \
  sh -c "grep -R \"max_connections\" /etc/my.cnf /etc/mysql /etc/my.cnf.d /var/lib/mysql 2>/dev/null | head -50"

kubectl get configmap mysql-ha-initconf -o yaml | grep -A10 "99-extra.cnf"
```

For lab-only correction of the generated ConfigMap:

```bash
kubectl patch configmap mysql-ha-initconf \
  --type merge \
  -p '{"data":{"99-extra.cnf":"# Additional user configurations taken from spec.mycnf in InnoDBCluster.\n# Do not edit directly.\n[mysqld]\nmax_connections=200\nslow_query_log=ON\nlong_query_time=1\nlog_output=TABLE\n"}}'

kubectl rollout restart statefulset/mysql-ha
kubectl rollout status statefulset/mysql-ha
```

## Scale Out InnoDB Cluster

See [scale-out-innodb-cluster.md](scale-out-innodb-cluster.md) for the full 3-node to 5-node scale-out practice.

Quick flow:

```bash
kubectl get innodbcluster mysql-ha -o wide
kubectl get pods -o wide
kubectl get pvc

kubectl patch innodbcluster mysql-ha \
  --type=merge \
  -p '{"spec":{"instances":5}}'

kubectl get pods -w
```

Validate:

```bash
kubectl get innodbcluster mysql-ha -o wide
kubectl get pvc

kubectl exec -it mysql-ha-0 -c mysql -- \
  mysql -uroot -p'RootPass-MySQL-HA-Lab-123!' \
  -e "
SELECT MEMBER_HOST, MEMBER_ROLE, MEMBER_STATE, MEMBER_VERSION
FROM performance_schema.replication_group_members;
"
```

## Finalizer Cleanup Pattern

Use only when a namespace is stuck in `Terminating`.

```bash
kubectl describe namespace mysql-ha
kubectl get innodbcluster,pods,pvc -n mysql-ha
kubectl patch innodbcluster mysql-ha -n mysql-ha --type=merge -p '{"metadata":{"finalizers":[]}}'
kubectl patch pod mysql-ha-0 -n mysql-ha --type=merge -p '{"metadata":{"finalizers":[]}}'
kubectl patch pod mysql-ha-1 -n mysql-ha --type=merge -p '{"metadata":{"finalizers":[]}}'
kubectl patch pod mysql-ha-2 -n mysql-ha --type=merge -p '{"metadata":{"finalizers":[]}}'
kubectl delete pod mysql-ha-0 mysql-ha-1 mysql-ha-2 -n mysql-ha --grace-period=0 --force
kubectl delete pvc --all -n mysql-ha --grace-period=0 --force
```
