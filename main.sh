#!/bin/bash

echo; echo; echo  PROCESSING RESOURCE INPUTS
source /etc/profile.d/parallelworks.sh
source /etc/profile.d/parallelworks-env.sh
source /pw/.miniconda3/etc/profile.d/conda.sh
conda activate

if [ -f "/swift-pw-bin/utils/input_form_resource_wrapper.py" ]; then
    version=$(cat /swift-pw-bin/utils/input_form_resource_wrapper.py | grep VERSION | cut -d':' -f2)
    if [ -z "$version" ] || [ "$version" -lt 15 ]; then
        python utils/input_form_resource_wrapper.py
    else
        python /swift-pw-bin/utils/input_form_resource_wrapper.py
    fi
else
    python utils/input_form_resource_wrapper.py
fi

if ! [ -f "resources/host/inputs.sh" ]; then
    echo "ERROR - Missing file ./resources/host/inputs.sh - Resource wrapper failed"
    exit 1
fi

source resources/host/inputs.sh

echo; echo; echo CREATING JOB SCRIPT ${PWD}/benchmark.sh
cat resources/host/batch_header.sh > benchmarks/${benchmark}/batch.sh
cat resources/host/inputs.sh >> benchmarks/${benchmark}/batch.sh
cat benchmarks/${benchmark}/main.sh >> benchmarks/${benchmark}/batch.sh

rsync -avzq -e 'ssh -o StrictHostKeyChecking=no' --rsync-path="mkdir -p ${resource_jobdir}/benchmarks/ && rsync" benchmarks/${benchmark} ${resource_publicIp}:${resource_jobdir}/benchmarks/

echo; echo; echo RUNNING JOB SCRIPT ${resource_publicIp}:${resource_jobdir}/benchmarks/${benchmark}/batch.sh
# Submit job and get job id
if [[ ${jobschedulertype} == "SLURM" ]]; then
    jobid=$($sshcmd ${submit_cmd} ${resource_jobdir}/benchmarks/${benchmark}/batch.sh | tail -1 | awk -F ' ' '{print $4}')
elif [[ ${jobschedulertype} == "PBS" ]]; then
    jobid=$($sshcmd ${submit_cmd} ${resource_jobdir}/benchmarks/${benchmark}/batch.sh)
fi

if [[ "${jobid}" == "" ]];then
    echo "ERROR submitting job - exiting the workflow"
    exit 1
fi