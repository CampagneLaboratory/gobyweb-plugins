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

function plugin_alignment_analysis_sequential {

     if [ "${IS_TRANSCRIPT}" == "true" ]; then
            goby alignment-to-transcript-counts \
                --stats $RESULT_DIR/${TAG}.stats.tsv \
                --groups ${GROUPS_DEFINITION} \
                --compare ${COMPARE_DEFINITION} ${USE_WEIGHTS_DIRECTIVE} \
                ${ENTRIES_FILES}
            RETURN_STATUS=$?
        else
            goby alignment-to-annotation-counts \
                --annotation ${ANNOTATION_FILE} \
                --write-annotation-counts false \
                --stats ${STATS_OUTPUT} \
                --include-annotation-types ${ANNOTATION_TYPES} \
                --groups ${GROUPS_DEFINITION} \
                --compare ${COMPARE_DEFINITION} ${USE_WEIGHTS_DIRECTIVE} \
                ${ENTRIES_FILES}
            RETURN_STATUS=$?
        fi
        if [ $RETURN_STATUS -eq 0 ]; then

            R -f ${PLUGINS_ALIGNMENT_ANALYSIS_DIFF_EXP_GOBY_FILES_R_SCRIPT} --slave --quiet --no-restore --no-save --no-readline --args input=${STATS_OUTPUT} graphOutput=${IMAGE_OUTPUT_PNG}
        fi
}
