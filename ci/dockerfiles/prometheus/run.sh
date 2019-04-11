#!/bin/bash

echo "$kubeconfig" > /root/.kube/config
echo "Running prometheus capture"
/root/svt/openshift_tooling/prometheus_db_dump/prometheus_dump.sh /root
