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

function eval {
EVAL=raw-counts
}

function setupWeights {

   if [ "${PLUGINS_ALIGNMENT_ANALYSIS_DIFF_EXP_EDGE_R_WEIGHT_ADJUSTMENT}" == "NONE" ]; then

       USE_WEIGHTS_DIRECTIVE=" "

   elif [ "${PLUGINS_ALIGNMENT_ANALYSIS_DIFF_EXP_EDGE_R_WEIGHT_ADJUSTMENT}" == "GC_CONTENT" ]; then

       USE_WEIGHTS_DIRECTIVE="--use-weights gc --adjust-gc-bias ${PLUGINS_ALIGNMENT_ANALYSIS_DIFF_EXP_EDGE_R_BIAS_ADJUSTMENT_FORMULA} "

   elif [ "${PLUGINS_ALIGNMENT_ANALYSIS_DIFF_EXP_EDGE_R_WEIGHT_ADJUSTMENT}" == "HEPTAMERS" ]; then

       USE_WEIGHTS_DIRECTIVE="--use-weights heptamers "
   else
     dieUponError "weight adjustment  not supported: ${PLUGINS_ALIGNMENT_ANALYSIS_DIFF_EXP_EDGE_R_WEIGHT_ADJUSTMENT}"
   fi

}

function setupAnnotationTypes {
   ANNOTATION_TYPES=""
   if [ "${PLUGINS_ALIGNMENT_ANALYSIS_DIFF_EXP_EDGE_R_ESTIMATE_COUNTS_GENE}" == "true" ]; then

       ANNOTATION_TYPES="${ANNOTATION_TYPES}gene"
   fi
   if [ "${PLUGINS_ALIGNMENT_ANALYSIS_DIFF_EXP_EDGE_R_ESTIMATE_COUNTS_EXON}" == "true" ]; then
       if [ "${ANNOTATION_TYPES}" != "" ]; then
          ANNOTATION_TYPES="${ANNOTATION_TYPES},"
       fi
       ANNOTATION_TYPES="${ANNOTATION_TYPES}exon"
   fi
   if [ "${PLUGINS_ALIGNMENT_ANALYSIS_DIFF_EXP_EDGE_R_ESTIMATE_COUNTS_OTHER}" == "true" ]; then
       if [ "${ANNOTATION_TYPES}" != "" ]; then
          ANNOTATION_TYPES="${ANNOTATION_TYPES},"
       fi
       ANNOTATION_TYPES="${ANNOTATION_TYPES}other"
   fi

   if [ "${ANNOTATION_TYPES}" == "" ]; then
     dieUponError "At least one annotation type must be selected to run a differential analysis."
   fi

}

function setupAnnotationSource {

  ANNOTATION_SOURCE=""
  if [ "${PLUGINS_ALIGNMENT_ANALYSIS_DIFF_EXP_EDGE_R_ANNOTATION_SOURCE}" == "GENE_EXON_OTHER" ]; then
    # gene exon annotation file.
    ANNOTATION_SOURCE="${REFERENCE_DIRECTORY}/exon-annotations.tsv"
  else
    # CNV annotation file.
    ANNOTATION_SOURCE="${REFERENCE_DIRECTORY}/cnv-annotations.tsv"
  fi
}

. ${PLUGINS_ALIGNMENT_ANALYSIS_DIFF_EXP_EDGE_R_FILES_PARALLEL_SCRIPT}
. ${RESOURCES_R_SHELL_SCRIPT}

function plugin_alignment_analysis_combine {
   set -x
   set -T
   RESULT_FILE=$1
   shift
   PART_RESULT_FILES=$*

   NUM_TOP_HITS=${PLUGINS_ALIGNMENT_ANALYSIS_DIFF_EXP_EDGE_R_NUM_TOP_HITS}
   Q_VALUE_THRESHOLD=${PLUGINS_ALIGNMENT_ANALYSIS_DIFF_EXP_EDGE_R_Q_VALUE_THRESHOLD}
   NORMALIZATION_FACTORS_METHOD=${PLUGINS_ALIGNMENT_ANALYSIS_DIFF_EXP_EDGE_R_NORMALIZATION_FACTORS_METHOD}
   DISPERSION_METHOD=${PLUGINS_ALIGNMENT_ANALYSIS_DIFF_EXP_EDGE_R_DISPERSION_METHOD}



   # following function from DIFF_EXP_GOBY/parallel.sh
   run_fdr

   if [ $? -eq 0 ]; then
      GENE_OUT_FILENAME=gene-counts.stats.tsv
      EXON_OUT_FILENAME=exon-counts-stats.tsv

      # Extract gene part of file:
      head -1 ${OUT_FILENAME} >${GENE_OUT_FILENAME}
      grep GENE ${OUT_FILENAME} |cat >>${GENE_OUT_FILENAME}
      wc -l ${GENE_OUT_FILENAME}

      HAS_GENES=`cat ${GENE_OUT_FILENAME} | wc -l`


      # Extract exon part of file:
      head -1 ${OUT_FILENAME} >${EXON_OUT_FILENAME}
      grep EXON ${OUT_FILENAME} 1>>${EXON_OUT_FILENAME}
      ls -lat
      HAS_EXONS=`cat ${EXON_OUT_FILENAME} | wc -l `

    cp ${SGE_O_WORKDIR}/sampleToGroups.tsv .
    SAMPLE_GROUP_MAPPING="sampleGroupMapping=sampleToGroups.tsv"

      # Run EdgeR on gene and exon input:

      if [ "$HAS_GENES" != "1" ]; then

        EDGE_R_OUTPUT="output=gene-stats.tsv mdsPlotOutput=mds.png smearPlotOutput=smear.png"
        run-R -f ${RESOURCES_EDGE_R_SCRIPT_R_SCRIPT} --slave --quiet --no-restore --no-save --no-readline --args input=${GENE_OUT_FILENAME} ${EDGE_R_OUTPUT} ${SAMPLE_GROUP_MAPPING} elementType=GENE normalizationMethod=${NORMALIZATION_FACTORS_METHOD} dispersionMethod=${DISPERSION_METHOD}


      fi
      if [ "$HAS_EXONS" != "1" ]; then

        EDGE_R_OUTPUT="output=exon-stats.tsv mdsPlotOutput=mds.png smearPlotOutput=smear.png"
        run-R -f ${RESOURCES_EDGE_R_SCRIPT_R_SCRIPT} --slave --quiet --no-restore --no-save --no-readline --args input=${EXON_OUT_FILENAME} ${EDGE_R_OUTPUT} ${SAMPLE_GROUP_MAPPING} elementType=EXON normalizationMethod=${NORMALIZATION_FACTORS_METHOD} dispersionMethod=${DISPERSION_METHOD}


      fi
      if [ "${HAS_GENES}" != "1" ] && [ "${HAS_EXONS}" != "1" ]; then

        run-goby ${PLUGIN_NEED_COMBINE_JVM} fdr \
          --q-threshold 1.0 \
          gene-stats.tsv exon-stats.tsv  \
          ${COLUMNS} \
          --output stats.tsv

      elif [ "${HAS_GENES}" != "1" ]; then
        mv gene-stats.tsv stats.tsv
      elif [ "${HAS_EXONS}" != "1" ]; then
        mv exon-stats.tsv stats.tsv
      fi
   fi
}
