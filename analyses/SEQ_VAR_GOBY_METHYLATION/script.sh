# Copyright (c) 2011  by Cornell University and the Cornell Research
# Foundation, Inc.  All Rights Reserved.
#
# Permission to use, copy, modify and distribute any part of GobyWeb web
# application for next-generation sequencing data alignment and analysis,
# officially docketed at Cornell as D-5061 ("WORK") and its associated
# copyrights for educational, research and non-profit purposes, without
# fee, and without a written agreement is hereby granted, provided that
# the above copyright notice, this paragraph and the following three
# paragraphs appear in all copies.
#
# Those desiring to incorporate WORK into commercial products or use WORK
# and its associated copyrights for commercial purposes should contact the
# Cornell Center for Technology Enterprise and Commercialization at
# 395 Pine Tree Road, Suite 310, Ithaca, NY 14850;
# email:cctecconnect@cornell.edu; Tel: 607-254-4698;
# FAX: 607-254-5454 for a commercial license.
#
# IN NO EVENT SHALL THE CORNELL RESEARCH FOUNDATION, INC. AND CORNELL
# UNIVERSITY BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL,
# OR CONSEQUENTIAL DAMAGES, INCLUDING LOST PROFITS, ARISING OUT OF THE USE OF
# WORK AND ITS ASSOCIATED COPYRIGHTS, EVEN IF THE CORNELL RESEARCH FOUNDATION,
# INC. AND CORNELL UNIVERSITY MAY HAVE BEEN ADVISED OF THE POSSIBILITY OF SUCH
# DAMAGE.
#
# THE WORK PROVIDED HEREIN IS ON AN "AS IS" BASIS, AND THE CORNELL RESEARCH
# FOUNDATION, INC. AND CORNELL UNIVERSITY HAVE NO OBLIGATION TO PROVIDE
# MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.  THE CORNELL
# RESEARCH FOUNDATION, INC. AND CORNELL UNIVERSITY MAKE NO REPRESENTATIONS AND
# EXTEND NO WARRANTIES OF ANY KIND, EITHER IMPLIED OR EXPRESS, INCLUDING, BUT
# NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY OR FITNESS FOR A
# PARTICULAR PURPOSE, OR THAT THE USE OF WORK AND ITS ASSOCIATED COPYRIGHTS
# WILL NOT INFRINGE ANY PATENT, TRADEMARK OR OTHER RIGHTS.

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

. ${RESOURCES_GOBY_SHELL_SCRIPT}

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
   shift
   shift
   MINIMUM_VARIATION_SUPPORT=${PLUGINS_ALIGNMENT_ANALYSIS_SEQ_VAR_GOBY_METHYLATION_MINIMUM_VARIATION_SUPPORT}
   THRESHOLD_DISTINCT_READ_INDICES=${PLUGINS_ALIGNMENT_ANALYSIS_SEQ_VAR_GOBY_METHYLATION_THRESHOLD_DISTINCT_READ_INDICES}
   OUTPUT_FORMAT=${PLUGINS_ALIGNMENT_ANALYSIS_SEQ_VAR_GOBY_METHYLATION_OUTPUT_FORMAT}
   ANNOTATIONS=${PLUGINS_ALIGNMENT_ANALYSIS_SEQ_VAR_GOBY_METHYLATION_ANNOTATIONS}
   if [ ! "${PLUGINS_ALIGNMENT_ANALYSIS_SEQ_VAR_GOBY_METHYLATION_ANNOTATIONS}" == "NONE" ]; then
     ANNOTATION_OPTION=" -x MethylationRegionsOutputFormat:annotations=${PLUGINS_ALIGNMENT_ANALYSIS_SEQ_VAR_GOBY_METHYLATION_ANNOTATIONS} "
   else
     ANNOTATION_OPTION=" "
   fi

   # These variables are defined: SLICING_PLAN_FILENAME
     echo "Processing run_single_alignment_analysis_process for part ${SGE_TASK_ID}"

     WINDOW_LIMITS=`awk -v arrayJobIndex=${ARRAY_JOB_INDEX} '{ if (lineNumber==arrayJobIndex) print " -s "$3" -e "$6; lineNumber++; }' ${SLICING_PLAN_FILENAME}`
     STAT2_FILENAME=${SGE_O_WORKDIR}/results/${TAG}-variations-stats2.tsv

     echo "Discovering sequence variants for window limits: ${WINDOW_LIMITS} and statsFilename: ${STAT2_FILENAME}"

     ${QUEUE_WRITER} --tag ${TAG} --status ${JOB_PART_DIFF_EXP_STATUS} --description "Start discover-sequence-variations for part # ${CURRENT_PART}." --index ${CURRENT_PART} --job-type job-part
     REALIGNMENT_OPTION=${PLUGINS_ALIGNMENT_ANALYSIS_SEQ_VAR_GOBY_METHYLATION_REALIGN_AROUND_INDELS}
     if [ "${REALIGNMENT_OPTION}" == "true" ]; then

            REALIGNMENT_ARGS=" --processor realign_near_indels "
     else
            REALIGNMENT_ARGS="  "
     fi
     CALL_INDELS_OPTION=${PLUGINS_ALIGNMENT_ANALYSIS_SEQ_VAR_GOBY_METHYLATION_CALL_INDELS}
     FORCE_DIPLOID=${PLUGINS_ALIGNMENT_ANALYSIS_SEQ_VAR_GOBY_METHYLATION_FORCE_DIPLOID}
     ESTIMATE_DENSITY=${PLUGINS_ALIGNMENT_ANALYSIS_SEQ_VAR_GOBY_METHYLATION_ESTIMATE_INTRA_GROUP_DIFFERENCE_DENSITY}
     COMBINATOR=${PLUGINS_ALIGNMENT_ANALYSIS_SEQ_VAR_GOBY_METHYLATION_PVALUE_COMBINATOR}
     EXTRA_ARGS=" "

     if [ "${ESTIMATE_DENSITY}" == "true" ]; then
         run_methyl_sites ${TAG}-intra-group-differences-estimate-${ARRAY_JOB_INDEX}.bin -x MethylationRateVCFOutputFormat:estimate-intra-group-differences=${ESTIMATE_DENSITY} -x MethylationRateVCFOutputFormat:estimate-empirical-P=false -x MethylationRateVCFOutputFormat:binning-strategy=fastslog10

         dieUponError  "Estimating density failed for part ${CURRENT_PART}."
         mkdir -p ${SGE_O_WORKDIR}/split-results/
         cp ${TAG}-intra-group-differences-estimate-${ARRAY_JOB_INDEX}.bin ${SGE_O_WORKDIR}/split-results/

         dieUponError  "Could not copy estimated density to result directory for part ${CURRENT_PART}."
         EXTRA_ARGS=" -x MethylationRateVCFOutputFormat:estimate-empirical-P=true -x MethylationRateVCFOutputFormat:estimate-intra-group-differences=false -x MethylationRateVCFOutputFormat:serialized-estimator-filename=${TAG}-intra-group-differences-estimate-${ARRAY_JOB_INDEX}.bin -x MethylationRateVCFOutputFormat:combinator=${COMBINATOR} "
     fi
     run_methyl_sites ${TAG}-dsv-${ARRAY_JOB_INDEX}.vcf

     dieUponError  "Compare sequence variations part, sub-task ${CURRENT_PART} failed."

     ${QUEUE_WRITER} --tag ${TAG} --status ${JOB_PART_DIFF_EXP_STATUS} --description "End discover-sequence-variations for part # ${ARRAY_JOB_INDEX}." --index ${CURRENT_PART} --job-type job-part

     annotate_vcf_file ${TAG}-dsv-${ARRAY_JOB_INDEX}.vcf   ${TAG}-discover-sequence-variants-output-${ARRAY_JOB_INDEX}.vcf.gz


}

function run_methyl_sites {
    output="$1"
    shift
    # Note that we override the grid jvm flags to request only 4Gb:
     run-goby ${PLUGIN_NEED_PROCESS_JVM} discover-sequence-variants \
           ${WINDOW_LIMITS} \
           --groups ${GROUPS_DEFINITION} \
           --compare ${COMPARE_DEFINITION} \
           --format ${OUTPUT_FORMAT} \
           --eval filter \
           ${REALIGNMENT_ARGS} \
           --genome ${REFERENCE_DIRECTORY}/random-access-genome \
           --minimum-variation-support ${MINIMUM_VARIATION_SUPPORT} \
           --threshold-distinct-read-indices ${THRESHOLD_DISTINCT_READ_INDICES} \
           --output ${output}  \
           --call-indels ${CALL_INDELS_OPTION} \
           --diploid ${FORCE_DIPLOID} \
           ${EXTRA_ARGS} \
           ${ENTRIES_FILES} $*
}
function plugin_alignment_analysis_combine {

   RESULT_FILE=stats.vcf.gz
   shift
   PART_RESULT_FILES=$*

   OUTPUT_FORMAT=${PLUGINS_ALIGNMENT_ANALYSIS_SEQ_VAR_GOBY_METHYLATION_OUTPUT_FORMAT}
   NUM_TOP_HITS=${PLUGINS_ALIGNMENT_ANALYSIS_SEQ_VAR_GOBY_METHYLATION_NUM_TOP_HITS}
   COLUMNS=" "
   for groupName in {1..${NUM_GROUPS}}
   do
      echo -n "${groupName} "
   done
    #GROUP1_PAIR=A/B
    #GROUP2_NAME=A/C
    #NUM_COMPARISON_PAIRS=2

    for ((i=1; i <= NUM_COMPARISON_PAIRS ; i++))
    do
     GROUP_PAIR=`eval echo "$""GROUP"$i"_COMPARISON_PAIR"`

     # More than one group, some P-values may need adjusting:

     COLUMNS="${COLUMNS} --column FisherP[${GROUP_PAIR}]"
    done

   echo "Adjusting P-value columns: $COLUMNS"
   if [ "${OUTPUT_FORMAT}" == "GENOTYPES" -o ${NUM_GROUPS} == 1 ]; then

        # Do not attempt FDR adjustment when there is no p-value, just concat the split files and sort:

        ${VCFTOOLS_BIN}/vcf-concat ${PART_RESULT_FILES} | \
        ${VCFTOOLS_BIN}/vcf-sort | \
        ${BGZIP_EXEC_PATH} -c > ${RESULT_FILE}

   else
       Q_VALUE_THRESHOLD=${PLUGINS_ALIGNMENT_ANALYSIS_SEQ_VAR_GOBY_METHYLATION_Q_VALUE_THRESHOLD}

        run-goby ${PLUGIN_NEED_COMBINE_JVM} fdr \
          --vcf \
          --q-threshold ${Q_VALUE_THRESHOLD} \
          --top-hits ${NUM_TOP_HITS} \
          ${PART_RESULT_FILES}  \
          ${COLUMNS} \
          --output ${TMPDIR}/${TAG}-pre.vcf.gz

        gunzip -c -d ${TMPDIR}/${TAG}-pre.vcf.gz | ${VCFTOOLS_BIN}/vcf-sort | ${BGZIP_EXEC_PATH} -c > ${RESULT_FILE}
   fi

   ${TABIX_EXEC_PATH} -f -p vcf ${RESULT_FILE}

}