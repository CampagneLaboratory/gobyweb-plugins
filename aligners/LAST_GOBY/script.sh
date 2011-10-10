# This script expects the following variables to be defined:

# PAIRED_END_ALIGNMENT = true|false
# COLOR_SPACE = true|false
# READS = reads file
# START_POSITION = start index in the reads file
# END_POSITION = end index in the reads file

# INDEX_DIRECTORY = directory that contains the indexed database
# INDEX_PREFIX = name of the indexed database to search

# ALIGNER_OPTIONS = any Last options the end-user would like to set

# Please note that Goby must be configured with appropriate path to Last aligner executable.

function plugin_align {

      OUTPUT=$1
      BASENAME=$2

      COLOR_SPACE_OPTION=""
      if [ "${COLOR_SPACE}" == "true" ]; then
          COLOR_SPACE_OPTION=" --color-space "
      fi

      # Extract the reads if a split is needed
      if [ ! -z ${SGE_TASK_ID} ] && [ "${SGE_TASK_ID}" != "undefined" ] && [ "${SGE_TASK_ID}" != "unknown" ]; then
          ${QUEUE_WRITER} --tag ${TAG} --status ${JOB_PART_SPLIT_STATUS} --description "Split, sub-task ${CURRENT_PART} of ${NUMBER_OF_PARTS}, starting" --index ${CURRENT_PART} --job-type job-part
          # The reads file to process
          READS_FILE=${READS##*/}


          goby reformat-compact-reads --output ${READS_FILE} \
              --start-position ${START_POSITION} --end-position ${END_POSITION} ${READS}

          dieUponError "split reads failed, sub-task ${CURRENT_PART} of ${NUMBER_OF_PARTS}, failed"

      fi

      # This Goby wrapper detects automatically if the reads file is paired end:

       goby align --reference ${REFERENCE} --aligner last ${COLOR_SPACE} --search \
           --ambiguity-threshold ${AMBIGUITY_THRESHOLD} --quality-filter-parameters "${QUALITY_FILTER_PARAMETERS}" \
           --database-name ${INDEX_PREFIX} --database-directory ${INDEX_DIRECTORY} \
           ${ALIGNER_OPTIONS} --reads ${READS_FILE} --basename ${BASENAME}

}
