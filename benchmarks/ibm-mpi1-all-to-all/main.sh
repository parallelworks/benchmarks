# The SLURM header is added by the workflow using the scheduler directives
# that were specified in the input form
# The input parameters are added by the workflow from the input form
set -e

# Install or load MPI
if [[ ${spack_install_intel_mpi} == true ]]; then
    git clone -c feature.manyFiles=true https://github.com/spack/spack.git
    . ${PWD}/spack/share/spack/setup-env.sh
    spack install intel-oneapi-mpi intel-oneapi-compilers
    load_mpi="spack load intel-oneapi-mpi intel-oneapi-compilers"
fi

eval ${load_mpi}

echo "Running benchmark..."
mkdir results
echo "mpirun -ppn $SLURM_CPUS_ON_NODE IMB-MPI1 alltoall 2>&1 | tee results/all-to-all.out"
mpirun -ppn $SLURM_CPUS_ON_NODE IMB-MPI1 alltoall | tee results/all-to-all.out

# Stream output file to PW
cat results/all-to-all.out | ssh ${resource_ssh_usercontainer_options} usercontainer  "cat >> \"${pw_job_dir}/logs.out\""

# Plot and clean results
pip3 install pandas matplotlib plotly
python3 benchmarks/${benchmark}/plot-imb-mpi-benchmark.py results/all-to-all.out 

# Create HTML to display results
rm -f results/result.html
echo '<body style="background:white;">' > results/result.html.tmp
find "results" -type f -name "*.html" | while read -r file; do
    echo "<iframe style=\"width:40%;height:100%;border:0px;display:inline-block;position:relative\" src=\"/me/3001/api/v1/display/${pw_job_dir}/${file}\"></iframe>" >> results/result.html.tmp
done
echo '</body>' >> results/result.html.tmp
mv results/result.html.tmp results/result.html

# Transfer output to platform
rsync -avzq -e "ssh ${resource_ssh_usercontainer_options}" results usercontainer:${pw_job_dir}
