# This script expects the following variables to be defined:

# PAIRED_END_ALIGNMENT = true|false
# READS = reads file

# INDEX_DIRECTORY = directory that contains the indexed database
# INDEX_PREFIX = name of the indexed database to search

# GSNAP_BAM.EXEC_PATH = path to gsnap, obtained from environment.sh

# ALIGNER_OPTIONS = any GSNAP options the end-user would like to set


function plugin_align {

       OUTPUT=$1
       BASENAME=$2

       BISULFITE_OPTION=""
       if [ "${BISULFITE_SAMPLE}" == "true" ]; then
             # 2011-03-11 and newer, for older use -C
             BISULFITE_OPTION="--mode cmet "
       fi

       # set the number of threads to the number of cores available on the server:
       NUM_THREADS=`grep physical  /proc/cpuinfo |grep id|wc -l`
       PARALLEL_OPTION="-t ${NUM_THREADS}"

       if [ "${PAIRED_END_ALIGNMENT}" == "true" ]; then

                   # PAIRED END alignment, with GSNAP to sam [this path not tested]

                   nice ${ALIGNER_EXEC_PATH}  ${BISULFITE_OPTION} ${PARALLEL_OPTION} -B 4 ${ALIGNER_OPTIONS}-A sam -j 64 -D ${INDEX_DIRECTORY} -d ${INDEX_PREFIX} -o ${PAIRED_END_DIRECTIONS} ${READS_FILE} > ${BASENAME}.sam

       else
                   # Single end alignment, GSNAP sam output

                   nice ${ALIGNER_EXEC_PATH} ${BISULFITE_OPTION} ${PARALLEL_OPTION} ${ALIGNER_OPTIONS} -B 4 -A sam -j 64 -D ${INDEX_DIRECTORY} -d ${INDEX_PREFIX}  ${READS}  > ${OUTPUT}.sam
       fi
       if [  $? -eq 0 ]; then
           # aln worked, let's convert to BAM and sort on the fly:

           nice ${SAMTOOLS.EXEC_PATH}  view -uS ${OUTPUT}.sam  | ${SAMTOOLS.EXEC_PATH}  sort - ${BASENAME}

           if [ $? -eq 0 ]; then

              nice ${SAMTOOLS.EXEC_PATH} index ${BASENAME}.bam

            else
              return 2
           fi
       else
          return 1
       fi
}
