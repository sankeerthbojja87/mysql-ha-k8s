#!/usr/bin/env bash
set -euo pipefail

kubectl config set-context --current --namespace=mysql-standalone >/dev/null
kubectl get pods,pvc,svc

kubectl run mysql-client --rm -i --quiet \
  --image=mysql:8.4 \
  --restart=Never \
  -- mysql -hmysql -uapp_user -p'AppPass-MySQL-Lab-123!' appdb \
  -e "SELECT @@hostname, @@version, CURRENT_USER(), DATABASE(); SELECT * FROM healthcheck;"

kubectl exec -it mysql-0 -- \
  mysql -uroot -p'RootPass-MySQL-Lab-123!' \
  -e "SHOW VARIABLES LIKE 'max_connections'; SHOW VARIABLES LIKE 'slow_query_log'; SHOW VARIABLES LIKE 'long_query_time';"

