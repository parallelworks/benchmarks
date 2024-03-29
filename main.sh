#!/bin/bash
source utils/workflow-libs.sh

############################################
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

########################################################
echo; echo; echo CREATING JOB SCRIPT ${PWD}/benchmark.sh
# SLURM / PBS header created by input_form_resource_wrapper.py
cat resources/host/batch_header.sh > benchmarks/${benchmark}/batch.sh

# Input variables created by input_form_resource_wrapper.py from inputs.json
cat resources/host/inputs.sh >> benchmarks/${benchmark}/batch.sh

# Streaming
# - Copy to benchmark dir which is transferred to the resource
cp utils/stream.sh benchmarks/${benchmark}/
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