
# This function runs a Goby mode from the GOBY resource configured in this plugin.
# It initializes java memory and logging parameters and can be called with any number of parameters.
# For instance goby fasta-to-compact will run the fasta-to-compact mode with no arguments.

function run-goby {
   set -x
   set -T
   memory="$1"
   shift
   mode_name="$1"
   shift

   GOBY_JAR=${RESOURCES_GOBY_GOBY_JAR}
   java -Xmx${memory} -Dlog4j.debug=true -Dlog4j.configuration=file:${TMPDIR}/log4j.properties \
                                             -Dgoby.configuration=file:${TMPDIR}/goby.properties \
                       -jar ${GOBY_JAR} \
                       --mode ${mode_name} $*
}


function plugin_alignment_analysis_split {
  NUMBER_OF_PARTS=$1
  SPLICING_PLAN_RESULT=$2
  shift
  shift
  run-goby 4g suggest-position-slices \
          --number-of-slices ${NUMBER_OF_PARTS} \
          --output ${SPLICING_PLAN_RESULT} \
          --annotations ${ANNOTATION_FILE} \
          $*
}

# This function return the number of parts in the slicing plan. It returns zero if the alignments could not be split.
function plugin_alignment_analysis_num_parts {
   SPLICING_PLAN_FILE=$1

   if [ $? -eq 0 ]; then

        return `grep -v targetIdStart ${SPLICING_PLAN_FILE} | wc -l `
   fi

   return 0
}

function plugin_alignment_analysis_process {
   SLICING_PLAN_FILENAME=$1
   ARRAY_JOB_INDEX=$2
   shift
   shift
   MINIMUM_VARIATION_SUPPORT=${PLUGINS_ALIGNMENT_ANALYSIS_SEQ_VAR_GOBY_MINIMUM_VARIATION_SUPPORT}
   THRESHOLD_DISTINCT_READ_INDICES=${PLUGINS_ALIGNMENT_ANALYSIS_SEQ_VAR_GOBY_THRESHOLD_DISTINCT_READ_INDICES}
   OUTPUT_FORMAT=${PLUGINS_ALIGNMENT_ANALYSIS_SEQ_VAR_GOBY_OUTPUT_FORMAT}

   NORMALIZATION_METHOD="${PLUGINS_ALIGNMENT_ANALYSIS_DIFF_EXP_GOBY_NORMALIZATION_METHOD}"
   if [ -z "${NORMALIZATION_METHOD}" ]; then
       NORMALIZATION_METHOD="aligned-count"
   fi

   # fectch the type statistics to evaluate from the main script:
   eval

   WINDOW_LIMITS=`awk -v arrayJobIndex=${ARRAY_JOB_INDEX} '{ if (lineNumber==arrayJobIndex) print " --start-position "$3" --end-position "$6; lineNumber++; }' ${SLICING_PLAN_FILENAME}`
   if [ "${ARRAY_JOB_INDEX}" == "1" ]; then
       INFO_OPTION=" --info-output ${TAG}-info-1.tsv "
   fi

   OUT_FILENAME=${TAG}-stats-${ARRAY_JOB_INDEX}.tsv

   run-goby 3g alignment-to-annotation-counts \
          --annotation ${ANNOTATION_FILE} \
          --write-annotation-counts false \
          --eval ${EVAL} \
          --stats ${OUT_FILENAME} \
          --include-annotation-types ${ANNOTATION_TYPES} \
          --groups ${GROUPS_DEFINITION} \
          --compare ${COMPARE_DEFINITION} ${USE_WEIGHTS_DIRECTIVE} \
          --normalization-methods ${NORMALIZATION_METHOD} \
          ${WINDOW_LIMITS} \
          ${INFO_OPTION}   \
          ${ENTRIES_FILES}

}


