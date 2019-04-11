#!/bin/bash

echo "$kubeconfig" > /root/.kube/config
cd /root/svt/openshift_scalability
echo "Setting up the config"
sed -i "/- num/c  \  - num: $PROJECTS" /root/svt/ci/scale-tests/config/pyconfigMasterVertScale.yaml
echo "Running mastervertical scale test"
./masterVertical.sh python CI
