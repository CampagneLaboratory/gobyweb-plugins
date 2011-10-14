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

function plugin_alignment_analysis_sequential {
     NORMALIZATION_METHOD="${PLUGINS_ALIGNMENT_ANALYSIS_DIFF_EXP_GOBY_NORMALIZATION_METHOD}"

     if [ "${IS_TRANSCRIPT}" == "true" ]; then
            OUT_FILENAME=stats.tsv

            goby alignment-to-transcript-counts \
                --stats ${OUT_FILENAME} \
                --groups ${GROUPS_DEFINITION} \
                --compare ${COMPARE_DEFINITION} ${USE_WEIGHTS_DIRECTIVE} \
                ${ENTRIES_FILES}
            RETURN_STATUS=$?
     else

            OUT_FILENAME=stats.tsv

            goby alignment-to-annotation-counts \
                --annotation ${ANNOTATION_FILE} \
                --write-annotation-counts false \
                --stats ${OUT_FILENAME} \
                --include-annotation-types ${ANNOTATION_TYPES} \
                --groups ${GROUPS_DEFINITION} \
                --compare ${COMPARE_DEFINITION} ${USE_WEIGHTS_DIRECTIVE} \
                --normalization-methods ${NORMALIZATION_METHOD} \
                ${ENTRIES_FILES}
            RETURN_STATUS=$?

      fi

      if [ $RETURN_STATUS -eq 0 ]; then
            IMAGE_OUTPUT_PNG=
            R -f ${PLUGINS_ALIGNMENT_ANALYSIS_DIFF_EXP_GOBY_FILES_R_SCRIPT} --slave --quiet --no-restore --no-save --no-readline --args input=${OUT_FILENAME} graphOutput=.png
      fi
}
