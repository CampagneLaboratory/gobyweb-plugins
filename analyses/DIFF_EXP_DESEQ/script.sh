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
