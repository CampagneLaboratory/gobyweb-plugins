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
EVAL=counts
}

. ${PLUGINS_ALIGNMENT_ANALYSIS_DIFF_EXP_DESEQ_FILES_PARALLEL_SCRIPT}

function plugin_alignment_analysis_combine {
   set -x
   set -T
   RESULT_FILE=$1
   shift
   PART_RESULT_FILES=$*

   NUM_TOP_HITS=${PLUGINS_ALIGNMENT_ANALYSIS_DIFF_EXP_GOBY_NUM_TOP_HITS}
   Q_VALUE_THRESHOLD=${PLUGINS_ALIGNMENT_ANALYSIS_DIFF_EXP_GOBY_Q_VALUE_THRESHOLD}

   # following function from DIFF_EXP_GOBY/parallel.sh
   run_fdr

   if [ $? -eq 0 ]; then
      GENE_OUT_FILENAME=gene-counts.stats.tsv
      DESEQ_GENE_INPUT="geneInput=${GENE_OUT_FILENAME}"

      EXON_OUT_FILENAME=exon-counts-stats.tsv
      DESEQ_EXON_INPUT="exonInput=${EXON_OUT_FILENAME}"

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

      # Run DESeq on gene and exon input:

      if [ "$HAS_GENES" != "1" ]; then

        DESEQ_OUTPUT="output=gene-stats.tsv graphOutput=.png"
        R -f ${PLUGINS_ALIGNMENT_ANALYSIS_DIFF_EXP_DESEQ_FILES_R_SCRIPT} --slave --quiet --no-restore --no-save --no-readline --args ${DESEQ_OUTPUT} ${DESEQ_GENE_INPUT}

      fi
      if [ "$HAS_EXONS" != "1" ]; then

        DESEQ_OUTPUT="output=exon-stats.tsv graphOutput=.png"
        R -f ${PLUGINS_ALIGNMENT_ANALYSIS_DIFF_EXP_DESEQ_FILES_R_SCRIPT} --slave --quiet --no-restore --no-save --no-readline --args ${DESEQ_OUTPUT} ${DESEQ_EXON_INPUT}
      fi
      if [ "${HAS_GENES}" != "1" ] && [ "${HAS_EXONS}" != "1" ]; then

        run-goby 16g fdr \
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
