#!/bin/bash
set -euo pipefail

workflow_path='/hpc/hers_en/edejong2/software/repos/epi2me_wf-alignment/'
softwaretool_path='/hpc/hers_en/edejong2/software/tools/'

# Set input and output dirs
input_fastq=`realpath $1`
output=`realpath $2`
email=$3
optional_params=( "${@:4}" )

mkdir -p $output && cd $output
mkdir -p execution

if ! { [ -f 'workflow.running' ] || [ -f 'workflow.done' ] || [ -f 'workflow.failed' ]; }; then
    touch workflow.running


output_execution="${output}/execution"
file="${output_execution}/trace.txt"
# Check if trace.txt exists
if [ -e "${file}" ]; then
    current_suffix=0
    # Get a list of all trace files WITH a suffix
    trace_file_list=$(ls "${output_execution}"/trace*.txt 2> /dev/null)
    # Check if any trace files with a suffix exist
    if [ "$?" -eq 0 ]; then
        # Check for each trace file with a suffix if the suffix is the highest and save that one as the current suffix
        for trace_file in ${trace_file_list}; do
            basename_trace_file=$(basename "${trace_file}")
            if echo "${basename_trace_file}" | grep -qE '[0-9]+'; then
                suffix=$(echo "${basename_trace_file}" | grep -oE '[0-9]+')
            else
                suffix=0
            fi

            if [ "${suffix}" -gt "${current_suffix}" ]; then
                current_suffix=${suffix}
            fi
        done
    fi
    # Increment the suffix
    new_suffix=$((current_suffix + 1))
    # Create the new file name with the incremented suffix
    new_file="${file%.*}_$new_suffix.${file##*.}"
    # Rename the file
    mv "${file}" "${new_file}"
fi

sbatch <<EOT
#!/bin/bash
#SBATCH -c 2
#SBATCH --time=12:00:00
#SBATCH --mem=10G
#SBATCH --job-name epi2me_wf-alignment
#SBATCH --gres=tmpspace:40G
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=$email
#SBATCH --error=execution/slurm_epi2me_wf-alignment.%j.err
#SBATCH --output=execution/slurm_epi2me_wf-alignment.%j.out

export NXF_JAVA_HOME='$softwaretool_path/java/jdk'

${softwaretool_path}/nextflow/nextflow run \
${workflow_path}/main.nf \
-c $workflow_path/umcu_hpc.config \
--fastq $input_fastq \
--out_dir $output \
-resume \
-ansi-log false \
-profile slurm \
${optional_params[@]:-""}

# --references '/hpc/diaggen/data/databases/ref_genomes/GRCh38_gencode_v22_CTAT_lib_Mar012021/GRCh38_gencode_v22_CTAT_lib_Mar012021.plug-n-play/ctat_genome_lib_build_dir/' \

if [ \$? -eq 0 ]; then
    echo "Nextflow done."

#    echo "Zip work directory"
#    find work -type f | egrep "\.(command|exitcode)" | zip -@ -q work.zip

#    echo "Remove work directory"
#    rm -r work

#    echo "Creating md5sum"
#    find -type f -not -iname 'md5sum.txt' -exec md5sum {} \; > md5sum.txt

    echo "epi2me_wf-alignment workflow completed successfully."
    rm workflow.running
    touch workflow.done

    echo "Change permissions"
    chmod 775 -R $output

    exit 0
else
    echo "Nextflow failed"
    rm workflow.running
    touch workflow.failed

    echo "Change permissions"
    chmod 775 -R $output

    exit 1
fi
EOT
else
echo "Workflow job not submitted, please check $output for 'workflow.status' files."
fi
