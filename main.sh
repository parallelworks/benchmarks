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
fi


echo; echo; echo CREATING JOB SCRIPT ${PWD}/benchmark.sh
cat resources/host/batch_header.sh > benchmarks/${benchmark}/batch.sh
cat resources/host/inputs.sh >> benchmarks/${benchmark}/batch.sh
cat benchmarks/${benchmark}/main.sh >> benchmarks/${benchmark}/batch.sh


${sshcmd} mkdir -p ${resource_jobdir}
${sshcmd} mkdir -p ${resource_jobdir}
rsync -avzq -e 'ssh -o StrictHostKeyChecking=no' --rsync-path="mkdir -p ${resource_jobdir} && rsync" benchmarks/ ${resource_publicIp}:${resource_jobdir}/