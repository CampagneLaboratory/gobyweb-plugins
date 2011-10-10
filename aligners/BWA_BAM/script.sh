# This script expects the following variables to be defined:

# PAIRED_END_ALIGNMENT = true|false
# COLOR_SPACE = true|false
# READS = reads file
# START_POSITION = start index in the reads file
# END_POSITION = end index in the reads file

# INDEX_DIRECTORY = directory that contains the indexed database
# INDEX_PREFIX = name of the indexed database to search

# BWA_GOBY.EXEC_PATH = path to BWA, obtained from environment.sh
# BWA_GOBY.NUM_THREADS = number of threads to run with, obtained from environment.sh

# ALIGNER_OPTIONS = any BWA options the end-user would like to set

function plugin_align {

    OUTPUT=$1
    BASENAME=$2

    COLOR_SPACE_OPTION=""
    if [ "${COLOR_SPACE}" == "--color-space" ]; then
                COLOR_SPACE_OPTION="-c"
    fi
    # set the number of threads to the number of cores available on the server:
    NUM_THREADS=`grep physical  /proc/cpuinfo |grep id|wc -l`
    PARALLEL_OPTION="-t ${NUM_THREADS}"

    if [ "${PAIRED_END_ALIGNMENT}" == "true" ]; then
                # PAIRED END alignment, native aligner
                SAI_FILE_0=${READS##*/}-0.sai
                SAI_FILE_1=${READS##*/}-1.sai
                nice ${ALIGNER_EXEC_PATH} aln -w 0 ${PARALLEL_OPTION} ${COLOR_SPACE_OPTION} -f ${SAI_FILE_0} -l ${INPUT_READ_LENGTH} ${ALIGNER_OPTIONS} ${INDEX_DIRECTORY}/${INDEX_PREFIX} ${READS}
                RETURN_STATUS=$?
                if [ $RETURN_STATUS -eq 0 ]; then
                    nice ${ALIGNER_EXEC_PATH} aln -w 1 ${PARALLEL_OPTION} ${COLOR_SPACE_OPTION} -f ${SAI_FILE_1} -l ${INPUT_READ_LENGTH} ${ALIGNER_OPTIONS}  ${INDEX_DIRECTORY}/${INDEX_PREFIX} ${READS}
                    RETURN_STATUS=$?
                    if [ $RETURN_STATUS -eq 0 ]; then
                        # aln worked, let's sampe
                        nice ${ALIGNER_EXEC_PATH} sampe ${COLOR_SPACE_OPTION} -f pre-sort-${TAG} ${INDEX_DIRECTORY}/${INDEX_PREFIX} ${SAI_FILE_0} ${SAI_FILE_1} ${READS} ${READS}
                    fi
                fi
    else
                # Single end alignment, native aligner
                SAI_FILE_0=${READS##*/}.sai
                nice ${ALIGNER_EXEC_PATH} aln ${PARALLEL_OPTION}  ${COLOR_SPACE_OPTION} -f ${SAI_FILE_0} -l ${INPUT_READ_LENGTH} ${ALIGNER_OPTIONS} ${INDEX_DIRECTORY}/${INDEX_PREFIX} ${READS}
                RETURN_STATUS=$?
                if [ $RETURN_STATUS -eq 0 ]; then
                    # aln worked, let's samse
                    nice ${ALIGNER_EXEC_PATH} samse ${COLOR_SPACE_OPTION} -f pre-sort-${TAG}  ${INDEX_DIRECTORY}/${INDEX_PREFIX} ${SAI_FILE_0} ${READS}
                fi
    fi
    if [ $? -eq 0 ]; then
        # aln worked, let's convert to BAM and sort on the fly:

        nice ${SAMTOOLS.EXEC_PATH}  view -uS ${OUTPUT}  | ${SAMTOOLS.EXEC_PATH}  sort - ${BASENAME}

        if [ $? -eq 0 ]; then
           # sort worked. We index the BAM file. If this works, the return code will be 0, indicating no problem with plugin_align
           nice ${SAMTOOLS.EXEC_PATH} index ${BASENAME}.bam
        else
          echo "Returning error code 2: sorting failed."
          return 2
        fi
    else
        echo "Returning error code 1: alignment failed."
        return 1

    fi


}
