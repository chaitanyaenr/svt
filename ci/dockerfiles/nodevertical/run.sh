#!/bin/bash

echo "$kubeconfig" > /root/.kube/config
cd /root/svt/ci/scale-tests
echo "Running nodevertical scale test"
./nodeVertical.sh /root/.kube/config
