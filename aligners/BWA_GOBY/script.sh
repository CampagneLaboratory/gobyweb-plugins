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

# PAIRED_END_ALIGNMENT = true|false
# COLOR_SPACE = true|false
# READS = reads file
# START_POSITION = start index in the reads file
# END_POSITION = end index in the reads file

# INDEX_DIRECTORY = directory that contains the indexed database
# INDEX_PREFIX = name of the indexed database to search

# BWA_GOBY_EXEC_PATH = path to BWA, obtained from environment.sh
# BWA_GOBY_NUM_THREADS = number of threads to run with, obtained from environment.sh

# ALIGNER_OPTIONS = any BWA options the end-user would like to set

function plugin_align {

    OUTPUT=$1
    BASENAME=$2

    COLOR_SPACE_OPTION=""
    if [ "${COLOR_SPACE}" == "true" ]; then
        COLOR_SPACE_OPTION="-c"
    fi

    if [ "${PAIRED_END_ALIGNMENT}" == "true" ]; then
        # PAIRED END alignment, native aligner
        SAI_FILE_0=${READS##*/}-0.sai
        SAI_FILE_1=${READS##*/}-1.sai
        nice ${BWA_GOBY_EXEC_PATH} aln -w 0 -t ${BWA_GOBY_NUM_THREADS} ${COLOR_SPACE_OPTION} -f ${SAI_FILE_0} -l ${INPUT_READ_LENGTH} ${ALIGNER_OPTIONS} -x ${START_POSITION} -y ${END_POSITION} ${INDEX_DIRECTORY}/${INDEX_PREFIX} ${READS_FILE}
        RETURN_STATUS=$?
        if [ $RETURN_STATUS -eq 0 ]; then
            nice ${BWA_GOBY_EXEC_PATH} aln -w 1 -t ${BWA_GOBY_NUM_THREADS} ${COLOR_SPACE_OPTION} -f ${SAI_FILE_1} -l ${INPUT_READ_LENGTH} ${ALIGNER_OPTIONS} -x ${START_POSITION} -y ${END_POSITION} ${INDEX_DIRECTORY}/${INDEX_PREFIX} ${READS_FILE}
            RETURN_STATUS=$?
            if [ $RETURN_STATUS -eq 0 ]; then
                # aln worked, let's sampe
                nice ${BWA_GOBY_EXEC_PATH} sampe ${COLOR_SPACE_OPTION} -F goby -f ${OUTPUT} -x ${START_POSITION} -y ${END_POSITION} ${INDEX_DIRECTORY}/${INDEX_PREFIX} ${SAI_FILE_0} ${SAI_FILE_1} ${READS_FILE} ${READS_FILE}
                RETURN_STATUS=$?
            fi
        fi
    else
        # Single end alignment, native aligner
        SAI_FILE_0=${READS##*/}.sai
        nice ${BWA_GOBY_EXEC_PATH} aln ${COLOR_SPACE_OPTION} -t ${BWA_GOBY_NUM_THREADS} -f ${SAI_FILE_0} -l ${INPUT_READ_LENGTH} ${ALIGNER_OPTIONS} -x ${START_POSITION} -y ${END_POSITION} ${INDEX_DIRECTORY}/${INDEX_PREFIX} ${READS_FILE}
        RETURN_STATUS=$?
        if [ $RETURN_STATUS -eq 0 ]; then
            # aln worked, let's samse
            nice ${BWA_GOBY_EXEC_PATH} samse ${COLOR_SPACE_OPTION} -F goby -f ${OUTPUT} -x ${START_POSITION} -y ${END_POSITION} ${INDEX_DIRECTORY}/${INDEX_PREFIX} ${SAI_FILE_0} ${READS_FILE}
            RETURN_STATUS=$?
        fi
    fi
}
