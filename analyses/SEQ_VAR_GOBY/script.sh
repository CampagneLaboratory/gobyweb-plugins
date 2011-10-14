# This script expects the following variables to be defined:

# IS_TRANSCRIPT = whether alignments were done against a cDNA reference.
# GROUPS_DEFINITION = description of the groups, in the format group-1=sample_i,sample_j/group-2=sample_k,..
# COMPARE_DEFINITION
# ANNOTATION_FILE = file describing annotations in the Goby annotation format.
# ANNOTATION_TYPES = gene|exon|other, specifies the kind of annotations to calculate counts for.
# USE_WEIGHTS_DIRECTIVE = optional, command line flags to have Goby annotation-to-counts adjust counts with weigths.

# All output files must be created in the directory where the analysis script is run.
# STATS_OUTPUT = name of the statistics file produced by the analysis. Format can be tsv, or VCF. If the file is VCF,
# the filename points to the vcf.gz file, and a secondary index file vcf.gz.tbi must also be produced by the analysis.
# IMAGE_OUTPUT_PNG = name of an optional image file output (must be written in PNG format)

# OTHER_ALIGNMENT_ANALYSIS_OPTIONS = any options defined by the end-user or assembled with the auto-format mechanism.

function plugin_alignment_analysis_split {

  NUMBER_OF_PARTS=$1
  SPLICING_PLAN_RESULT=$2
  shift
  shift
  goby suggest-position-slices \
          --number-of-slices ${NUMBER_OF_PARTS} \
          --output ${SPLICING_PLAN_RESULT} \
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
   MINIMUM_VARIATION_SUPPORT=${PLUGINS_ALIGNMENT_ANALYSIS_CONFIG_SEQ_VAR_GOBY_MINIMUM_VARIATION_SUPPORT}
   THRESHOLD_DISTINCT_READ_INDICES=${PLUGINS_ALIGNMENT_ANALYSIS_CONFIG_SEQ_VAR_GOBY_THRESHOLD_DISTINCT_READ_INDICES}

   # These variables are defined: SLICING_PLAN_FILENAME
     echo "Processing run_single_alignment_analysis_process for part ${SGE_TASK_ID}"
     cat ${SLICING_PLAN_FILENAME}|wc -l >number-of-parts.txt

     WINDOW_LIMITS=`awk -v arrayJobIndex=${ARRAY_JOB_INDEX} '{ if (lineNumber==arrayJobIndex) print " -s "$3" -e "$6; lineNumber++; }' ${SLICING_PLAN_FILENAME}`
     STAT2_FILENAME=${SGE_O_WORKDIR}/results/${TAG}-variations-stats2.tsv
     MINIMUM_VARIATION_SUPPORT=1
     THRESHOLD_DISTINCT_READ_INDICES=1
     echo "Discovering sequence variants for window limits: ${WINDOW_LIMITS} and statsFilename: ${STAT2_FILENAME}"

     ${QUEUE_WRITER} --tag ${TAG} --status ${JOB_PART_DIFF_EXP_STATUS} --description "Start discover-sequence-variations for part # ${CURRENT_PART}." --index ${CURRENT_PART} --job-type job-part

     if [ "${REALIGNMENT_OPTION}" == "true" ]; then

            REALIGNMENT_ARGS=" --processor realign_near_indels "
     else
            REALIGNMENT_ARGS="  "
     fi

     # Note that we override the grid jvm flags to request only 4Gb:
     goby_with_memory -Xmx4g discover-sequence-variants \
           ${WINDOW_LIMITS} \
           --groups ${GROUPS_DEFINITION} \
           --compare ${COMPARE_DEFINITION} \
           --format ${OUTPUT_FORMAT} \
           --eval filter \
           ${REALIGNMENT_ARGS} \
           --genome ${REFERENCE_DIRECTORY}/random-access-genome \
           --minimum-variation-support ${MINIMUM_VARIATION_SUPPORT} \
           --threshold-distinct-read-indices ${THRESHOLD_DISTINCT_READ_INDICES} \
           --output ${TAG}-dsv-${ARRAY_JOB_INDEX}.vcf  \
           ${ENTRIES_FILES}

      dieUponError  "Compare sequence variations part, sub-task ${CURRENT_PART} failed."

      ${QUEUE_WRITER} --tag ${TAG} --status ${JOB_PART_DIFF_EXP_STATUS} --description "End discover-sequence-variations for part # ${ARRAY_JOB_INDEX}." --index ${CURRENT_PART} --job-type job-part

      annotate_vcf_file ${TAG}-dsv-${ARRAY_JOB_INDEX}.vcf   ${TAG}-discover-sequence-variants-output-${ARRAY_JOB_INDEX}.vcf.gz


}

function plugin_alignment_analysis_combine {

   RESULT_FILE=$1
   shift
   PART_RESULT_FILES=$*

   OUTPUT_FORMAT=${PLUGINS_ALIGNMENT_ANALYSIS_CONFIG_SEQ_VAR_GOBY.OUTPUT_FORMAT}
   NUM_TOP_HITS=${PLUGINS_ALIGNMENT_ANALYSIS_CONFIG_SEQ_VAR_GOBY.NUM_TOP_HITS}

   if [ "${OUTPUT_FORMAT}" == "allele_frequencies" ]; then

        COLUMNS="--column P"

       elif [ "${OUTPUT_FORMAT}" == "compare_groups" ]; then

         COLUMNS="--column FisherP[${COMPARE_DEFINITION}]"

       elif [ "${OUTPUT_FORMAT}" == "methylation" ]; then

         COLUMNS="--column FisherP[${COMPARE_DEFINITION}]"

       else
          COLUMNS=" "
     fi

   echo "Adjusting P-value columns: $COLUMNS"
   if [ "${OUTPUT_FORMAT}" == "genotypes" ]; then

        # Do not attempt FDR adjustment when there is no p-value, just concat the split files and sort:

        ${VCFTOOLS_BIN}/vcf-concat ${PART_RESULT_FILES} | \
        ${VCFTOOLS_BIN}/vcf-sort | \
        ${BGZIP_EXEC_PATH} -c > ${RESULT_FILE}

   else
        goby fdr \
          --vcf \
          --q-threshold ${Q_VALUE_THRESHOLD} \
          --top-hits ${NUM_TOP_HITS} \
          ${PART_RESULT_FILES}  \
          ${COLUMNS} \
          --output ${TMPDIR}/${TAG}-pre.vcf.gz

        gunzip -c -d ${TMPDIR}/${TAG}-pre.vcf.gz | ${VCFTOOLS_BIN}/vcf-sort | ${BGZIP_EXEC_PATH} -c > ${RESULT_FILE}
   fi

   ${TABIX.EXEC_PATH} -f -p vcf ${RESULT_FILE}

}