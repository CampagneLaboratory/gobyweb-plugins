# This script expects the following variables to be defined:

# IS_TRANSCRIPT = whether alignments were done against a cDNA reference.
# GROUPS_DEFINITION = description of the groups, in the format group-1=sample_i,sample_j/group-2=sample_k,..
# COMPARE_DEFINITION
# ANNOTATION_FILE = file describing annotations in the Goby annotation format.
# ANNOTATION_TYPES = gene|exon|other, specifies the kind of annotations to calculate counts for.
# USE_WEIGHTS_DIRECTIVE = optional, command line flags to have Goby annotation-to-counts adjust counts with weigths.

# All output files must be created in the directory where the analysis script is run.
# the script generates one TSV file with the statistics, as well as images for the scatter plots:
# GENE.png
# EXON.png
# OTHER.png
# TRANSCRIPT.png

function eval {
EVAL=raw-counts
}
. ${PLUGINS_ALIGNMENT_ANALYSIS_DIFF_EXP_GOBY_FILES_PARALLEL_SCRIPT}



function plugin_alignment_analysis_combine {
   set -x
   set -T
   RESULT_FILE=$1
   shift
   PART_RESULT_FILES=$*

   NUM_TOP_HITS=${PLUGINS_ALIGNMENT_ANALYSIS_DIFF_EXP_GOBY_NUM_TOP_HITS}
   Q_VALUE_THRESHOLD=${PLUGINS_ALIGNMENT_ANALYSIS_DIFF_EXP_GOBY_Q_VALUE_THRESHOLD}

   run_fdr

   # Estimate stats on complete file
   NORMALIZATION_METHOD="${PLUGINS_ALIGNMENT_ANALYSIS_DIFF_EXP_GOBY_NORMALIZATION_METHOD}"
   if [ -z "${NORMALIZATION_METHOD}" ]; then
        NORMALIZATION_METHOD="aligned-count"
   fi

   #cp ${OUT_FILENAME} /home/gobyweb/GOBYWEB_SGE_JOBS-campagne/campagne/PGCWIBL
   #cp info.xml /home/gobyweb/GOBYWEB_SGE_JOBS-campagne/campagne/PGCWIBL

   run-goby 16g stats --info info.xml \
          ${OUT_FILENAME} \
          --parallel \
          --groups ${GROUPS_DEFINITION} \
          --compare ${COMPARE_DEFINITION} ${USE_WEIGHTS_DIRECTIVE} \
          --normalization-methods ${NORMALIZATION_METHOD} \
          -o stats.tsv

   dieUponError "statistics evaluation failed."

   if [ $RETURN_STATUS -eq 0 ]; then
            IMAGE_OUTPUT_PNG=
            R -f ${PLUGINS_ALIGNMENT_ANALYSIS_DIFF_EXP_GOBY_FILES_R_SCRIPT} --slave --quiet --no-restore --no-save --no-readline --args input=stats.tsv graphOutput=.png
   fi

}
