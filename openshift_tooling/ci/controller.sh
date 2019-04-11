#!/bin/bash

svt_repo_location=/root
controller_namespace=controller
properties_path=/root/properties
counter_time=5
wait_time=25
kubeconfig_path=$1
scale_test_image=$2

if [[ $# -ne 2 ]]; then
	echo "syntax: $0 <path-to-kubeconfig> <scale-test-inage>"
	exit 1
fi

# Cleanup
function cleanup() {
	oc process -p SCALE_TEST_IMAGE=$scale_test_image -f $svt_repo_location/svt/openshift_templates/ci/controller-job-template.yaml | oc delete -f -
	oc delete cm scale-config -n $controller_namespace
	sleep $wait_time
	oc delete project --wait=true $controller_namespace
}

# Ensure that the host has svt repo cloned
if [[ ! -d $svt_repo_location/svt ]]; then
	 git clone https://github.com/openshift/svt.git
fi

# Check if the controller job and configmap exists
oc get jobs -n $controller_namespace | grep -w "controller" &>/dev/null
if [[ $? == 0 ]]; then
	cleanup
fi 
oc get cm -n $controller_namespace | grep -w "tooling-config" &>/dev/null
if [[ $? == 0 ]]; then
	cleanup
fi

oc project $controller_namespace &>/dev/null
if [[ $? == 0 ]]; then
        echo "Looks like the $controller_namespace already exists, deleting it"
        oc delete project $controller_namespace
fi

# create controller ns, configmap, job to run the scale test
oc create -f $svt_repo_location/svt/openshift_templates/ci/controller-ns.yml
oc create configmap scale-config --from-literal=kubeconfig="$(cat $kubeconfig_path)" -n $controller_namespace
oc process -p SCALE_TEST_IMAGE=$scale_test_image -f $svt_repo_location/svt/openshift_templates/ci/controller-job.yaml | oc create -f -
sleep $wait_time
controller_pod=$(oc get pods -n $controller_namespace | grep "controller" | awk '{print $1}')
counter=0
while [[ $(oc --namespace=default get pods $controller_pod -n $controller_namespace -o json | jq -r ".status.phase") != "Running" ]]; do
	sleep $counter_time
	counter=$((counter+1))
	if [[ $counter -ge 120 ]]; then
		echo "Looks like the $controller_pod is not up after 120 sec, please check"
		exit 1
	fi
done

# logging
logs_counter=0
logs_counter_limit=500
oc logs -f $controller_pod -n $controller_namespace
while true; do
        logs_counter=$((logs_counter+1))
        if [[ $(oc --namespace=default get pods $controller_pod -n $controller_namespace -o json | jq -r ".status.phase") == "Running" ]]; then
                if [[ $logs_counter -le $logs_counter_limit ]]; then
			echo "=================================================================================================================================================================="
			echo "Attempt $logs_counter to reconnect and fetch the controller pod logs"
			echo "=================================================================================================================================================================="
			echo "------------------------------------------------------------------------------------------------------------------------------------------------------------------"
			echo "------------------------------------------------------------------------------------------------------------------------------------------------------------------"
                        oc logs -f $controller_pod -n $controller_namespace
                else
                        echo "Exceeded the retry limit trying to get the controller logs: $logs_counter_limit, exiting."
                        exit 1
                fi
        else
                echo "Job completed"
                break
        fi
done

# check the status of the controller pod
while [[ $(oc --namespace=default get pods $controller_pod -n $controller_namespace -o json | jq -r ".status.phase") != "Succeeded" ]]; do
	if [[ $(oc --namespace=default get pods $controller_pod -n $controller_namespace -o json | jq -r ".status.phase") == "Failed" ]]; then
   		echo "JOB FAILED"
		echo "CLEANING UP"
   		cleanup
   		exit 1
   	else        
    		sleep $wait_time
        fi
done
echo "JOB SUCCEEDED"

# cleanup
echo "CLEANING UP"
cleanup
