#!/usr/bin/env bash
set -euo pipefail

kubectl config set-context --current --namespace=mysql-ha >/dev/null
kubectl get innodbcluster mysql-ha -o wide
kubectl get pods,svc,pvc

kubectl run mysql-ha-client --rm -i --quiet \
  --image=mysql:8.4 \
  --restart=Never \
  -- mysql -hmysql-ha -uroot -p'RootPass-MySQL-HA-Lab-123!' \
  -e "SELECT @@hostname, @@version, @@read_only;"

kubectl exec -it mysql-ha-0 -c mysql -- \
  mysqlsh root:'RootPass-MySQL-HA-Lab-123!'@localhost --js \
  -e "print(JSON.stringify(dba.getCluster().status({extended: 1}), null, 2))"

