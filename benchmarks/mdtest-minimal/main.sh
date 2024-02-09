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
cp ior/src/mdtest ${benchmark_dir}/mdtest
chmod +x ${benchmark_dir}/mdtest
echo "Running benchmark..."
echo "mpirun -ppn $SLURM_CPUS_ON_NODE ${benchmark_dir}/mdtest -n 20840 -i 1 -u -d ${benchmark_dir}"
mpirun -ppn $SLURM_CPUS_ON_NODE ${benchmark_dir}/mdtest -n 20840 -i 1 -u -d ${benchmark_dir}

# Stream output file to PW
cat mdtest.out | ssh ${resource_ssh_usercontainer_options} usercontainer  "cat >> \"${pw_job_dir}/logs.out\""

# Transfer output to platform
rsync -avzq -e "ssh ${resource_ssh_usercontainer_options}" mdtest.out usercontainer:${pw_job_dir}/mdtest.out
