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
   REMOVE_SHARED_SEGMENTS=${PLUGINS_ALIGNMENT_ANALYSIS_SEQ_VAR_GOBY_REMOVE_SHARED_SEGMENTS}
   ALL_OTHER_OPTIONS=${PLUGINS_ALIGNMENT_ANALYSIS_SEQ_VAR_GOBY_ALL_OTHER_OPTIONS}

   NORMALIZATION_METHOD="${PLUGINS_ALIGNMENT_ANALYSIS_DIFF_EXP_GOBY_NORMALIZATION_METHOD}"
   if [ -z "${NORMALIZATION_METHOD}" ]; then
       NORMALIZATION_METHOD="aligned-count"
   fi

   # fetch the type statistics to evaluate from the main script:
   eval

   WINDOW_LIMITS=`awk -v arrayJobIndex=${ARRAY_JOB_INDEX} '{ if (lineNumber==arrayJobIndex) print " --start-position "$3" --end-position "$6; lineNumber++; }' ${SLICING_PLAN_FILENAME}`
   if [ "${ARRAY_JOB_INDEX}" == "1" ]; then
       INFO_OPTION=" --info-output ${TAG}-info-1.tsv "
   fi

   OUT_FILENAME=${TAG}-stats-${ARRAY_JOB_INDEX}.tsv

   # fetch the weight and annotation type arguments from the main script:
   setupWeights

   setupAnnotationTypes

   setupAnnottionSource

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
          ${ALL_OTHER_OPTIONS} \
          ${ENTRIES_FILES}

}

function run_fdr() {

   # The following sections extracts the info.xml file stored among split-results
   # and adjust the PART_RESULT_FILES variables to exclude the fake tsv info file.
   INFO_FILE=`ls -1 ${PART_RESULT_FILES} |grep info`
   cp ${INFO_FILE} ./info.xml

   # Run FDR to combine parts:

   PART_RESULT_FILES=`echo ${PART_RESULT_FILES} | sed -e 's!'${INFO_FILE}'!!'`

   OUT_FILENAME=combined-stats.tsv
   run-goby 16g fdr \
          --column-selection-filter t-test  \
          --column-selection-filter fisher-exact-R  \
          --q-threshold 1 \
          ${PART_RESULT_FILES}  \
          --output ${OUT_FILENAME}
}

