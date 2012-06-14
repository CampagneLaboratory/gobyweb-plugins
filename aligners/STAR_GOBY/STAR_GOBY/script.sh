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
# READS = reads file

# INDEX_DIRECTORY = directory that contains the indexed database
# INDEX_PREFIX = name of the indexed database to search

# ${RESOURCES_STAR_EXEC_PATH} = path to gsnap, obtained from the GSNAP_GOBY resource

# ALIGNER_OPTIONS = any STAR options the end-user would like to set

function plugin_align {

     OUTPUT=$1
     BASENAME=$2
     # set the number of threads to the number of cores available on the server:
     NUM_THREADS=`grep physical  /proc/cpuinfo |grep id|wc -l`
     ALIGNER_OPTIONS="${ALIGNER_OPTIONS} -t ${NUM_THREADS}"

     SPLICED_OPTION=""
     if [ "${PLUGINS_ALIGNER_GSNAP_GOBY_SPLICED_ALIGNMENT}" == "spliced" ]; then
        SPLICED_OPTION="-s ${GSNAP_SPLICE_FILE}"
     fi


     goby reformat-compact-reads  --start-position=${START_POSITION} --end-position=${END_POSITION}  ${READS_FILE} -o small-reads.compact-reads
     dieUponError "reformat reads failed, sub-task ${CURRENT_PART} of ${NUMBER_OF_PARTS}, failed"

     if [ "${PAIRED_END_ALIGNMENT}" == "true" ]; then

         # Convert the compact-reads slice to FASTQ for paired-end data:
         goby compact-to-fasta  -i small-reads.compact-reads -o 1.fastq -p 2.fastq --format fastq
         dieUponError "Convert compact-reads to fastq failed, sub-task ${CURRENT_PART} of ${NUMBER_OF_PARTS}, failed"

         nice ${RESOURCES_STAR_EXEC_PATH}  ${ALIGNER_OPTIONS} ${PLUGINS_ALIGNER_STAR_ALL_OTHER_OPTIONS} -A goby --goby-output="${OUTPUT}" -D ${INDEX_DIRECTORY} -d ${INDEX_PREFIX} -o ${PAIRED_END_DIRECTIONS} ${READ_FILE_SMALL}

     else
         # Convert the compact-reads slice to FASTQ for single-end data:
         goby compact-to-fasta  -i small-reads.compact-reads -o small-reads-trimmed.fastq --format fastq
         dieUponError "Convert compact-reads to fastq failed, sub-task ${CURRENT_PART} of ${NUMBER_OF_PARTS}, failed"
     fi

     # TODO: convert BAM output to Goby:




#extra variables:

#RESULT_DIR= directory on shared filesystem, send output files to $RESULT_DIR/split-results
#CURRENT_PART= unique id associated with this part of the job


}

# This function is called after the alignment slices have been combined into one final output.
# It is called with three arguments, the basename of the alignment (present in the directory where this function is
# invoked), the reads filename (full path), the tag useful to create an output.

function plugin_alignment_combine {
    TAG=$1
    READS=$2
    BASENAME=$3

}
