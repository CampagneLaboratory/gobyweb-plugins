
FULL_READS_INPUT=$1
READS_FASTQ=$2
TEMP_FILENAME1=$3
OUTPUT=$4
JOB_DIR=$5
# Grab the variables and functions we need:
. ${JOB_DIR}/constants.sh
. ${JOB_DIR}/auto-options.sh
set -x

  ${RESOURCES_LAST_EXEC_PATH} -v -p ${RESOURCES_LAST_BISULFITE_REVERSE_MATRIX} -s0 -Q1 -d${PLUGINS_ALIGNER_LAST_BISULFITE_D} \
             -e${PLUGINS_ALIGNER_LAST_BISULFITE_E} ${INDEX_DIRECTORY}/index_r ${READS_FASTQ} -o r-${TEMP_FILENAME1}.maf

  java ${GRID_JVM_FLAGS} -Dlog4j.debug=true -Dlog4j.configuration=file:${JOB_DIR}/goby/log4j.properties \
                       -Dgoby.configuration=file:${TMPDIR}/goby.properties \
                       -jar ${RESOURCES_GOBY_GOBY_JAR} \
                       --mode  last-to-compact  --flip-strand -i r-${TEMP_FILENAME1} -o presort-${OUTPUT} --third-party-input true \
                       --only-maf -q ${FULL_READS_INPUT} -t ${REFERENCE} --quality-filter-parameters threshold=1.0

  java ${GRID_JVM_FLAGS} -Dlog4j.debug=true -Dlog4j.configuration=file:${JOB_DIR}/goby/log4j.properties \
                       -Dgoby.configuration=file:${TMPDIR}/goby.properties \
                       -jar ${RESOURCES_GOBY_GOBY_JAR} \
                       --mode sort presort-${OUTPUT}  -o ${OUTPUT}

