# The SLURM header is added by the workflow using the scheduler directives
# that were specified in the input form
# The input parameters are added by the workflow from the input form
set -e

# Check if automake is installed
if ! rpm -q automake &> /dev/null; then
    # If not installed, install it
    echo "automake is not installed. Installing..."
    sudo yum install -y automake
else
    echo "automake is already installed."
fi

# Install or load MPI
if [[ ${spack_install_intel_mpi} == true ]]; then
    git clone -c feature.manyFiles=true https://github.com/spack/spack.git
    . ${PWD}/spack/share/spack/setup-env.sh
    spack install intel-oneapi-mpi intel-oneapi-compilers
    load_mpi="spack load intel-oneapi-mpi intel-oneapi-compilers"
fi

eval ${load_mpi}

benchmark_dir=${benchmark_root_dir}/pw/jobs/${workflow_name}/${job_number}/
mkdir -p ${benchmark_dir}

# Download and compile IOR test
git clone https://github.com/hpc/ior.git ior
cd ior

./bootstrap
if [[ "${with_lustre}" == "true" ]]; then
    ./configure --with-lustre
else
    ./configure
fi
make clean && make
mpirun ./src/ior
cd ..

# Run IOR test
cp ior/src/ior ${benchmark_dir}/ior_exec
chmod +x ${benchmark_dir}/ior_exec
echo "Running benchmark..."
echo "mpirun -ppn $SLURM_CPUS_ON_NODE ${benchmark_dir}/ior_exec -w -i 1 -o ${benchmark_dir}/out -t 1m -b 16m -s 16 -F -C -e 2>&1 | tee ior.out"
mpirun -ppn $SLURM_CPUS_ON_NODE ${benchmark_dir}/ior_exec -w -i 1 -o ${benchmark_dir}/out -t 1m -b 16m -s 16 -F -C -e 2>&1 | tee ior.out


# Stream output file to PW
cat ior.out | ssh ${resource_ssh_usercontainer_options} usercontainer  "cat >> \"${pw_job_dir}/logs.out\""

# Transfer output to platform
rsync -avzq -e "ssh ${resource_ssh_usercontainer_options}" ior.out usercontainer:${pw_job_dir}/ior.out
