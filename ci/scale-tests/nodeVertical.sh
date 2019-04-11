#!/bin/sh

if [ "$#" -ne 1 ]; then
  echo "syntax: $0 <kubeconfig_path>"
  exit 1
fi

KUBECONFIG_PATH=$1
LABEL="node-role.kubernetes.io/worker"
TEST_LABEL="nodevertical=true"
NODE_COUNT=0
pod_count=0
LABEL_COUNT=2

long_sleep() {
  local sleep_time=180
  echo "Sleeping for $sleep_time"
  sleep $sleep_time
}

if [[ -z $KUBECONFIG_PATH ]]; then
	KUBECONFIG_PATH=/root/.kube/config
fi

golang_clusterloader() {
  # Export kube config
  export KUBECONFIG=$KUBECONFIG_PATH
  MY_CONFIG=config/nodeVertical-labeled-nodes
  sed -i "/- num: 500/c \ \ \ \ \ \ \ \ \- num: $total_pod_count" /root/svt/ci/scale-tests/config/nodeVertical-labeled-nodes.yaml
  # loading cluster based on yaml config file
  VIPERCONFIG=$MY_CONFIG openshift-tests run-test "[Feature:Performance][Serial][Slow] Load cluster should load the cluster [Suite:openshift]"
}

# sleeping to gather some steady-state metrics, pre-test
long_sleep

# label the worker nodes
# pick two random app nodes and label them
for app_node in $(oc get nodes -l "$LABEL" -o json | jq '.items[].metadata.name'); do
	app_node=$(echo $app_node | sed "s/\"//g")
	if [[ $NODE_COUNT -ge $LABEL_COUNT  ]]; then
                break
        fi
	if ! ($(oc get nodes -l "$TEST_LABEL" | grep -q -w $app_node)); then
		oc label node $app_node "$TEST_LABEL"
		NODE_COUNT=$(( NODE_COUNT+1 ))
	fi
done

# Get the pod count on the labeled nodes
for node in $(oc get nodes -l="$TEST_LABEL" | awk 'NR > 1 {print $1}'); do
	pods_running=$(oc describe node $node | grep -w "Non-terminated \Pods:" | awk  '{print $3}' | sed "s/(//g")
	pod_count=$(( pod_count+pods_running ))
done
total_pod_count=$(( 500-pod_count ))

# Run the test
golang_clusterloader

# sleeping again for the cluster to settle
long_sleep
