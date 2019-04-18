#!/bin/sh

# usage
# ./pbench-register.sh 
# pbench-user-benchmark -C testname -- ./masterVertical.sh [golang|python] [CI|FULL]
# pbench-move-results

if [ "$#" -ne 2 ]; then
  echo "syntax: $0 <TYPE> <MODE>"
  echo "<TYPE> should be either golang or python"
  echo "<MODE> should be either CI or FULL"
  exit 1
fi

TYPE=$1
MODE=$2

if [[ "$MODE" == "CI" ]]; then
	STARTUP_TIME=10
	SETTLE_TIME=30
elif [[ "$MODE" == "FULL" ]]; then
	STARTUP_TIME=5m
	SETTLE_TIME=15m
else
	echo "$MODE is not a valid option, please check"
fi

# Export kube config
export KUBECONFIG=${KUBECONFIG-$HOME/.kube/config}

golang_clusterloader() {
  # Export kube config
#  export KUBECONFIG=${KUBECONFIG-$HOME/.kube/config}
  MY_CONFIG=config/golang/pyconfigMasterVertScalePause
  # loading cluster based on yaml config file
  VIPERCONFIG=$MY_CONFIG openshift-tests run-test "[Feature:Performance][Serial][Slow] Load cluster should load the cluster [Suite:openshift]"
}

python_clusterloader() {
  MY_CONFIG=config/pyconfigMasterVertScalePause.yaml
  python cluster-loader.py -f $MY_CONFIG
}

echo "Startup delay + entropy collection" 
sleep $STARTUP_TIME

echo "Run tests" 
if [ "$TYPE" == "golang" ]; then
  golang_clusterloader
elif [ "$TYPE" == "python" ]; then
  python_clusterloader
else
  echo "$TYPE is not a valid option, available options: golang, python"
  exit 1
fi

echo "sleeping $SETTLE_TIME for settling after tests"
sleep $SETTLE_TIME
