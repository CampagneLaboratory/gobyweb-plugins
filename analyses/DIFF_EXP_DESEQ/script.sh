# This script expects the following variables to be defined:

# IS_TRANSCRIPT = whether alignments were done against a cDNA reference.
# GROUPS_DEFINITION = description of the groups, in the format group-1=sample_i,sample_j/group-2=sample_k,..
# COMPARE_DEFINITION
# ANNOTATION_FILE = file describing annotations in the Goby annotation format.
# ANNOTATION_TYPES = gene|exon|other, specifies the kind of annotations to calculate counts for.
# USE_WEIGHTS_DIRECTIVE = optional, command line flags to have Goby annotation-to-counts adjust counts with weigths.

# IMAGE_OUTPUT_PNG = path to an image file output (must be written in PNG format)

function plugin_alignment_analysis {



        DESEQ_OUTPUT="output=$RESULT_DIR/${TAG}.stats.tsv graphOutput=${IMAGE_OUTPUT_PNG}"
        DESEQ_GENE_INPUT=""
        DESEQ_EXON_INPUT=""
        if [ "${ANNOTATION_TYPE_GENE}" == "true" ]; then
            goby alignment-to-annotation-counts \
                --annotation ${ANNOTATION_FILE} \
                --write-annotation-counts false \
                --stats $RESULT_DIR/${TAG}-gene-counts.stats.tsv \
                --include-annotation-types gene \
                --groups ${GROUPS_DEFINITION} \
                --compare ${COMPARE_DEFINITION} \
                --eval counts ${USE_WEIGHTS_DIRECTIVE} \
                ${ENTRIES_FILES}
            RETURN_STATUS=$?
            DESEQ_GENE_INPUT="geneInput=$RESULT_DIR/${TAG}-gene-counts.stats.tsv"
        fi
        if [ $RETURN_STATUS -eq 0 ]; then
            if [ "${ANNOTATION_TYPE_EXON}" == "true" ]; then
                goby alignment-to-annotation-counts \
                    --annotation ${ANNOTATION_FILE} \
                    --write-annotation-counts false \
                    --stats $RESULT_DIR/${TAG}-exon-counts.stats.tsv \
                    --include-annotation-types exon \
                    --groups ${GROUPS_DEFINITION} \
                    --compare ${COMPARE_DEFINITION} \
                    --eval counts ${USE_WEIGHTS_DIRECTIVE} \
                    ${ENTRIES_FILES}
                RETURN_STATUS=$?
                DESEQ_EXON_INPUT="exonInput=$RESULT_DIR/${TAG}-exon-counts.stats.tsv"
            fi
        fi
        if [ $RETURN_STATUS -eq 0 ]; then
            R -f geneDESeqAnalysis.R --slave --quiet --no-restore --no-save --no-readline --args ${DESEQ_OUTPUT} ${DESEQ_GENE_INPUT} ${DESEQ_EXON_INPUT}
            RETURN_STATUS=$?
        fi
}
