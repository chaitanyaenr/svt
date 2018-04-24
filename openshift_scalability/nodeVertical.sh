#!/bin/sh

if [ "$#" -ne 2 ]; then
  echo "syntax: $0 <TESTNAME> <TYPE>"
  echo "<TYPE> should be either golang or python"
  exit 1
fi

TESTNAME=$1
TYPE=$2
LABEL="node-role.kubernetes.io/compute=true"
CORE_COMPUTE_LABEL="core_app_node=true"
TEST_LABEL="nodevertical=true"
declare -a core_nodes

long_sleep() {
  local sleep_time=180
  echo "Sleeping for $sleep_time"
  sleep $sleep_time
}

clean() { echo "Cleaning environment"; oc delete project clusterproject0; }

golang_clusterloader() {
  # Export kube config
  export KUBECONFIG=${KUBECONFIG-$HOME/.kube/config}
  MY_CONFIG=config/golang/nodeVertical
  # loading cluster based on yaml config file
  /usr/libexec/atomic-openshift/extended.test --ginkgo.focus="Load cluster" --viper-config=$MY_CONFIG
}

python_clusterloader() {
  MY_CONFIG=config/nodeVertical.yaml
  ./cluster-loader.py --file=$MY_CONFIG
}

# sleeping to gather some steady-state metrics, pre-test
long_sleep

# odes and label the nodes
for compute in $(oc get nodes -l "$CORE_COMPUTE_LABEL" -o json | jq '.items[].metadata.name'); do
        compute=$(echo $compute | sed "s/\"//g")
        core_nodes[${#core_nodes[@]}]=$compute
        oc label node $compute "$TEST_LABEL"
done

# pick two random app nodes and label them
count=0
for app_node in $(oc get nodes -l "$LABEL" -o json | jq '.items[].metadata.name'); do
        app_node=$(echo $app_node | sed "s/\"//g")
        for ((i=0; i<${#core_nodes[*]}; i++));do
                if [[ $count > 2 ]] || [[ $count == 2 ]]; then
                        break
                fi
        if [[ $app_node != ${core_nodes[i]} ]]; then
                        count=$count+1
                        oc label node $app_node $TEST_LABEL
                fi
        done
done
	
# Run the test
if [ "$TYPE" == "golang" ]; then
  golang_clusterloader
elif [ "$TYPE" == "python" ]; then
  python_clusterloader
  # sleeping again to gather steady-state metrics after environment is loaded
  long_sleep
  # clean up environment
  clean
else
  echo "$TYPE is not a valid option, available options: golang, python"
  exit 1
fi

# TODO(himanshu): fix clean function
#./cluster-loader.py --clean

# sleep after test is complete to gather post-test metrics...these should be the same as pre-test
long_sleep
