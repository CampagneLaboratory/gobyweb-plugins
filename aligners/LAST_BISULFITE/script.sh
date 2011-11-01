# This script expects the following variables to be defined:


# READS = reads file
# START_POSITION = start index in the reads file
# END_POSITION = end index in the reads file

# INDEX_DIRECTORY = directory that contains the indexed database
# INDEX_PREFIX = name of the indexed database to search
# REFERENCE = Top level id file for reference genome.
# ALIGNER_OPTIONS = any Last options the end-user would like to set

. ${RESOURCES_GOBY_SHELL_SCRIPT}

function plugin_align {

      OUTPUT=$1
      BASENAME=$2

      if [ "${PAIRED_END_ALIGNMENT}" == "true" ]; then
           dieUponError "Plugin LAST_BISULFITE does not support paired-end read files, sub-task ${CURRENT_PART} of ${NUMBER_OF_PARTS}, failed"
      fi

      # Extract the reads if a split is needed
      if [ ! -z ${SGE_TASK_ID} ] && [ "${SGE_TASK_ID}" != "undefined" ] && [ "${SGE_TASK_ID}" != "unknown" ]; then
          ${QUEUE_WRITER} --tag ${TAG} --status ${JOB_PART_SPLIT_STATUS} --description "Split, sub-task ${CURRENT_PART} of ${NUMBER_OF_PARTS}, starting" --index ${CURRENT_PART} --job-type job-part
          # The reads file to process
          READS_FILE=${READS##*/}

          goby reformat-compact-reads ${READS} --output ${READS_FILE} \
              --start-position ${START_POSITION} --end-position ${END_POSITION}

          dieUponError "split reads failed, sub-task ${CURRENT_PART} of ${NUMBER_OF_PARTS}, failed"

      fi
      goby compact-to-fasta -i ${READS_FILE} --output reads.fastq -t fastq
      dieUponError "compact-reads to fastq conversion failed, sub-task ${CURRENT_PART} of ${NUMBER_OF_PARTS}, failed"

      ${RESOURCES_LAST_EXEC_PATH} -p ${RESOURCES_LAST_BISULFITE_FORWARD_MATRIX} -s1 -Q1 -d${PLUGINS_ALIGNER_LAST_BISULFITE_D} -e${PLUGINS_ALIGNER_LAST_BISULFITE_E} ${INDEX_DIRECTORY}/index_f reads.fastq > temp_f
      dieUponError "Alignment to forward strand failed, sub-task ${CURRENT_PART} of ${NUMBER_OF_PARTS}, failed"
      ${RESOURCES_LAST_EXEC_PATH} -p ${RESOURCES_LAST_BISULFITE_REVERSE_MATRIX} -s1 -Q1 -d${PLUGINS_ALIGNER_LAST_BISULFITE_D} -e${PLUGINS_ALIGNER_LAST_BISULFITE_E} ${INDEX_DIRECTORY}/index_r reads.fastq > temp_f
      dieUponError "Alignment to reverse strand failed, sub-task ${CURRENT_PART} of ${NUMBER_OF_PARTS}, failed"
      ${RESOURCES_LAST_MAP_PROBS_EXEC} temp_f temp_r | ${RESOURCES_LAST_MAP_PROBS_EXEC} -s${PLUGINS_ALIGNER_LAST_BISULFITE_S} > alignments.maf
      dieUponError "Combining forward and reverse strand alignments failed, sub-task ${CURRENT_PART} of ${NUMBER_OF_PARTS}, failed"

      goby last-to-compact -i alignments.maf -o ${OUTPUT} --third-party-input true --only-maf -q ${READS_FILE} -t ${REFERENCE} --quality-filter-parameters threshold=1.0
      dieUponError "Conversion of MAF file to Goby alignment failed, sub-task ${CURRENT_PART} of ${NUMBER_OF_PARTS}, failed"

}
