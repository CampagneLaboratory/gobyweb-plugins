# This script expects the following variables to be defined:

# IS_TRANSCRIPT = whether alignments were done against a cDNA reference.
# GROUPS_DEFINITION = description of the groups, in the format group-1=sample_i,sample_j/group-2=sample_k,..
# COMPARE_DEFINITION
# ANNOTATION_FILE = file describing annotations in the Goby annotation format.
# ANNOTATION_TYPES = gene|exon|other, specifies the kind of annotations to calculate counts for.
# USE_WEIGHTS_DIRECTIVE = optional, command line flags to have Goby annotation-to-counts adjust counts with weigths.

# IMAGE_OUTPUT_PNG = path to an image file output (must be written in PNG format)

function plugin_alignment_analysis_sequential {

        DESEQ_OUTPUT="output=stats.tsv graphOutput=.png"

        if [ "${ANNOTATION_TYPE_GENE}" == "true" ]; then
            OUT_FILENAME=gene-counts.stats.tsv
            DESEQ_GENE_INPUT="geneInput=${OUT_FILENAME}"
            goby alignment-to-annotation-counts \
                --annotation ${ANNOTATION_FILE} \
                --write-annotation-counts false \
                --stats ${OUT_FILENAME} \
                --include-annotation-types gene \
                --groups ${GROUPS_DEFINITION} \
                --compare ${COMPARE_DEFINITION} \
                --eval counts ${USE_WEIGHTS_DIRECTIVE} \
                ${ENTRIES_FILES}
            RETURN_STATUS=$?

        fi
        if [ $RETURN_STATUS -eq 0 ]; then
            if [ "${ANNOTATION_TYPE_EXON}" == "true" ]; then
                OUT_FILENAME=exon-counts-stats.tsv
                DESEQ_EXON_INPUT="exonInput=${OUT_FILENAME}"
                goby alignment-to-annotation-counts \
                    --annotation ${ANNOTATION_FILE} \
                    --write-annotation-counts false \
                    --stats ${OUT_FILENAME} \
                    --include-annotation-types exon \
                    --groups ${GROUPS_DEFINITION} \
                    --compare ${COMPARE_DEFINITION} \
                    --eval counts ${USE_WEIGHTS_DIRECTIVE} \
                    ${ENTRIES_FILES}
                RETURN_STATUS=$?

            fi
        fi
        pwd
        ls -lat
        if [ $RETURN_STATUS -eq 0 ]; then
            R -f ${PLUGINS_ALIGNMENT_ANALYSIS_DIFF_EXP_DESEQ_FILES_R_SCRIPT} --slave --quiet --no-restore --no-save --no-readline --args ${DESEQ_OUTPUT} ${DESEQ_GENE_INPUT} ${DESEQ_EXON_INPUT}
            RETURN_STATUS=$?
        fi
        ls -ltr
}
