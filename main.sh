#!/bin/bash

############################################
echo; echo; echo  PROCESSING RESOURCE INPUTS
source /etc/profile.d/parallelworks.sh
source /etc/profile.d/parallelworks-env.sh
source /pw/.miniconda3/etc/profile.d/conda.sh
conda activate

if [ -z "${workflow_utils_branch}" ]; then
    # If empty, clone the main default branch
    git clone https://github.com/parallelworks/workflow-utils.git
else
    # If not empty, clone the specified branch
    git clone -b "$workflow_utils_branch" https://github.com/parallelworks/workflow-utils.git
fi

python workflow-utils/input_form_resource_wrapper.py

if [ $? -ne 0 ]; then
    displayErrorMessage "ERROR - Resource wrapper failed"
fi

if ! [ -f "resources/host/inputs.sh" ]; then
    echo "ERROR - Missing file ./resources/host/inputs.sh - Resource wrapper failed"
    exit 1
fi

source workflow-utils/workflow-libs.sh
source resources/host/inputs.sh

########################################################
echo; echo; echo CREATING JOB SCRIPT ${PWD}/benchmark.sh
# SLURM / PBS header created by input_form_resource_wrapper.py
cat resources/host/batch_header.sh > benchmarks/${benchmark}/batch.sh

# Input variables created by input_form_resource_wrapper.py from inputs.json
cat resources/host/inputs.sh >> benchmarks/${benchmark}/batch.sh

# Streaming
# - Copy to benchmark dir which is transferred to the resource
cp workflow-utils/stream.sh benchmarks/${benchmark}/
echo "bash ${resource_jobdir}/benchmarks/${benchmark}/stream.sh &" >> benchmarks/${benchmark}/batch.sh

# Benchmark utils (common files useful to more than one benchmark)
# - Copy to benchmark dir which is transferred to the resource
cp benchmarks/utils/* benchmarks/${benchmark}/

# Benchmark main script
cat benchmarks/${benchmark}/main.sh >> benchmarks/${benchmark}/batch.sh

# Transfer benchmark directory to the resource's job directory
rsync -avzq -e 'ssh -o StrictHostKeyChecking=no' --rsync-path="mkdir -p ${resource_jobdir}/benchmarks/ && rsync" benchmarks/${benchmark} ${resource_publicIp}:${resource_jobdir}/benchmarks/

############################################################################################################
echo; echo; echo RUNNING JOB SCRIPT ${resource_publicIp}:${resource_jobdir}/benchmarks/${benchmark}/batch.sh
# Submit job and get job id
export sshcmd="ssh -o StrictHostKeyChecking=no ${resource_publicIp}"
if [[ ${jobschedulertype} == "SLURM" ]]; then
    jobid=$($sshcmd ${submit_cmd} ${resource_jobdir}/benchmarks/${benchmark}/batch.sh | tail -1 | awk -F ' ' '{print $4}')
elif [[ ${jobschedulertype} == "PBS" ]]; then
    jobid=$($sshcmd ${submit_cmd} ${resource_jobdir}/benchmarks/${benchmark}/batch.sh)
fi

if [[ "${jobid}" == "" ]];then
    echo "ERROR submitting job - exiting the workflow"
    exit 1
fi

##########################################################
echo; echo; echo PREPARING CANCEL SCRIPT FOR JOB ${jobid}
echo "#!/bin/bash" > cancel.sh
echo "${sshcmd} ${cancel_cmd} ${jobid}" >> cancel.sh
chmod +x cancel.sh

#########################################
echo; echo; echo WAITING FOR JOB ${jobid}
wait_job