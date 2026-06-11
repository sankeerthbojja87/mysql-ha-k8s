# MySQL HA on Kubernetes

Hands-on MySQL platform engineering lab using kind, Kubernetes, standalone MySQL, MySQL Operator, InnoDB Cluster, MySQL Router, backups, restore, performance triage, upgrades, and sharding concepts.

This repo is production-shaped for interview practice. It is not a production deployment as-is.

## What This Covers

- Standalone MySQL on Kubernetes using StatefulSet, Service, ConfigMap, Secret, PVC, probes, and resource limits
- MySQL operational checks: connectivity, health, persistence, slow query triage, index validation, config changes, and image upgrades
- MySQL InnoDB Cluster using the official MySQL Operator
- MySQL Router validation and HA failover testing
- Logical backup and restore using `mysqldump`
- Manual sharding practice using two independent MySQL shards
- Interview notes for DBRE/SRE/platform engineering discussions

## Lab Prerequisites

- macOS with Colima running
- Docker runtime
- kind
- kubectl
- Helm

Validate:

```bash
colima status
docker ps
kind get clusters
kubectl version --client
helm version
```

## Recommended Cluster

```bash
kind create cluster --name mysql-platform --image kindest/node:v1.31.4
kubectl cluster-info
kubectl get nodes -o wide
```

## Repository Structure

```text
manifests/
  standalone/      Standalone MySQL Kubernetes manifests
  ha/              MySQL Operator InnoDBCluster manifest
  sharding/        Manual two-shard MySQL lab
docs/
  operations-runbook.md
  performance-triage.md
  innodb-cluster-ha.md
  backup-restore.md
  sharding-notes.md
  rolling-update-config-change.md
  scale-out-innodb-cluster.md
scripts/
  validate-standalone.sh
  validate-ha.sh
```

## Quick Start: Standalone MySQL

```bash
kubectl create namespace mysql-standalone
kubectl config set-context --current --namespace=mysql-standalone

kubectl create secret generic mysql-secret \
  --from-literal=root-password='RootPass-MySQL-Lab-123!'

kubectl apply -f manifests/standalone/mysql-config.yaml
kubectl apply -f manifests/standalone/mysql-init.yaml
kubectl apply -f manifests/standalone/mysql-standalone.yaml

kubectl get pods -w
```

Validate:

```bash
./scripts/validate-standalone.sh
```

## Quick Start: MySQL InnoDB Cluster HA

Install the MySQL Operator:

```bash
helm repo add mysql-operator https://mysql.github.io/mysql-operator/
helm repo update
helm install mysql-operator mysql-operator/mysql-operator \
  --namespace mysql-operator \
  --create-namespace
```

Create HA cluster:

```bash
kubectl create namespace mysql-ha
kubectl config set-context --current --namespace=mysql-ha

kubectl create secret generic mysql-ha-secret \
  --from-literal=rootUser=root \
  --from-literal=rootHost='%' \
  --from-literal=rootPassword='RootPass-MySQL-HA-Lab-123!'

kubectl apply -f manifests/ha/mysql-innodb-cluster.yaml
kubectl get pods -w
```

Validate:

```bash
./scripts/validate-ha.sh
```

## Cleanup

```bash
kubectl delete namespace mysql-ha
kubectl delete namespace mysql-standalone
kubectl delete namespace mysql-sharding
```

Full reset:

```bash
kind delete cluster --name mysql-platform
```
