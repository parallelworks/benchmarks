# The SLURM header is added by the workflow using the scheduler directives
# that were specified in the input form
# The input parameters are added by the workflow from the input form
set -e


benchmark_root_dir=$HOME

benchmark_dir=${benchmark_root_dir}/pw/jobs/${workflow_name}/${job_number}/
with_lustre=false
spack_install_intel_mpi=false
load_mpi="spack load intel-oneapi-mpi intel-oneapi-compilers"

# Check if automake is installed
if ! rpm -q automake &> /dev/null; then
    # If not installed, install it
    echo "automake is not installed. Installing..."
    sudo yum install -y automake
else
    echo "automake is already installed."
fi

if [[ ${spack_install_intel_mpi} == true ]]; then
    git clone -c feature.manyFiles=true https://github.com/spack/spack.git
    . $HOME/spack/share/spack/setup-env.sh
    spack install intel-oneapi-mpi intel-oneapi-compilers
    load_mpi="spack load intel-oneapi-mpi intel-oneapi-compilers"
fi

eval ${load_mpi}



mkdir -p ${benchmark_dir}
# git clone https://github.com/hpc/ior.git ior
cd ior

./bootstrap
if [[ "${with_lustre}" == "false" ]]; then
    ./configure --with-lustre
else
    ./configure
fi
make clean && make
mpirun ./src/ior
cd ..

cp ior/src/ior ${benchmark_dir}/ior

mpirun -ppn $SLURM_CPUS_ON_NODE ${benchmark_dir}/ior -w -i 3 -o ${benchmark_dir}/out -t 64m -b 64m -s 16 -F -C -e  | tee >(cat > ior.out)