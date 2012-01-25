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


function plugin_alignment_analysis_sequential {
   OUTPUT_FORMAT=${PLUGINS_ALIGNMENT_ANALYSIS_INDEL_COUNTS_GOBY_OUTPUT_FORMAT}
   NUM_TOP_HITS= ${PLUGINS_ALIGNMENT_ANALYSIS_INDEL_COUNTS_GOBY_NUM_TOP_HITS}

   ${QUEUE_WRITER} --tag ${TAG} --status ${JOB_PART_DIFF_EXP_STATUS} --description "Start counting called indels with Goby" --index ${CURRENT_PART} --job-type job-part

   MINIMUM_VARIATION_SUPPORT=${PLUGINS_ALIGNMENT_ANALYSIS_INDEL_COUNTS_GOBY_MINIMUM_VARIATION_SUPPORT}
   THRESHOLD_DISTINCT_READ_INDICES=${PLUGINS_ALIGNMENT_ANALYSIS_INDEL_COUNTS_GOBY_THRESHOLD_DISTINCT_READ_INDICES}
   OUTPUT_FORMAT=${PLUGINS_ALIGNMENT_ANALYSIS_INDEL_COUNTS_GOBY_OUTPUT_FORMAT}

   REALIGNMENT_OPTION=${PLUGINS_ALIGNMENT_ANALYSIS_SEQ_VAR_GOBY_REALIGN_AROUND_INDELS}
   if [ "${REALIGNMENT_OPTION}" == "true" ]; then

           REALIGNMENT_ARGS=" --processor realign_near_indels "
    else
           REALIGNMENT_ARGS="  "
   fi

     # Note that we override the grid jvm flags to request only 4Gb:
     run-goby ${PLUGIN_NEED_PROCESS_JVM} discover-sequence-variants \
           --groups ${GROUPS_DEFINITION} \
           --compare ${COMPARE_DEFINITION} \
           --format ${OUTPUT_FORMAT} \
           --eval filter \
           ${REALIGNMENT_ARGS} \
           --genome ${REFERENCE_DIRECTORY}/random-access-genome \
           --minimum-variation-support ${MINIMUM_VARIATION_SUPPORT} \
           --threshold-distinct-read-indices ${THRESHOLD_DISTINCT_READ_INDICES} \
           --output this-is-ignored.tsv  \
           ${ENTRIES_FILES}

      dieUponError  "Failed to count indels in alignment files, sub-task ${CURRENT_PART} failed."
      RESULT_FILE=stats.tsv
      cp indel-counts.tsv ${RESULT_FILE}
      ${QUEUE_WRITER} --tag ${TAG} --status ${JOB_PART_DIFF_EXP_STATUS} --description "End discover-sequence-variations for part # ${ARRAY_JOB_INDEX}." --index ${CURRENT_PART} --job-type job-part


}
