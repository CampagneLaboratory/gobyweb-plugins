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


# READS = reads file
# START_POSITION = start index in the reads file
# END_POSITION = end index in the reads file

# INDEX_DIRECTORY = directory that contains the indexed database
# INDEX_PREFIX = name of the indexed database to search
# REFERENCE = Top level id file for reference genome.
# ALIGNER_OPTIONS = any Last options the end-user would like to set

. ${RESOURCES_GOBY_SHELL_SCRIPT}

function plugin_align {

      OUTPUT=$1
      BASENAME=$2

      if [ "${PAIRED_END_ALIGNMENT}" == "true" ]; then
           dieUponError "Plugin LAST_BISULFITE does not support paired-end read files, sub-task ${CURRENT_PART} of ${NUMBER_OF_PARTS}, failed"
      fi

      # Extract the reads if a split is needed
      if [ ! -z ${SGE_TASK_ID} ] && [ "${SGE_TASK_ID}" != "undefined" ] && [ "${SGE_TASK_ID}" != "unknown" ]; then
          ${QUEUE_WRITER} --tag ${TAG} --status ${JOB_PART_SPLIT_STATUS} --description "Split, sub-task ${CURRENT_PART} of ${NUMBER_OF_PARTS}, starting" --index ${CURRENT_PART} --job-type job-part
          # The reads file to process
          READS_FILE=${READS##*/}

          goby reformat-compact-reads ${READS} --output ${READS_FILE} \
              --start-position ${START_POSITION} --end-position ${END_POSITION}

          dieUponError "split reads failed, sub-task ${CURRENT_PART} of ${NUMBER_OF_PARTS}, failed"

      fi
      goby compact-to-fasta -i ${READS_FILE} --output reads.fastq -t fastq
      dieUponError "compact-reads to fastq conversion failed, sub-task ${CURRENT_PART} of ${NUMBER_OF_PARTS}, failed"

      ${RESOURCES_LAST_EXEC_PATH} -p ${RESOURCES_LAST_BISULFITE_FORWARD_MATRIX} -s1 -Q1 -d${PLUGINS_ALIGNER_LAST_BISULFITE_D} -e${PLUGINS_ALIGNER_LAST_BISULFITE_E} ${INDEX_DIRECTORY}/index_f reads.fastq > temp_f
      dieUponError "Alignment to forward strand failed, sub-task ${CURRENT_PART} of ${NUMBER_OF_PARTS}, failed"
      ${RESOURCES_LAST_EXEC_PATH} -p ${RESOURCES_LAST_BISULFITE_REVERSE_MATRIX} -s1 -Q1 -d${PLUGINS_ALIGNER_LAST_BISULFITE_D} -e${PLUGINS_ALIGNER_LAST_BISULFITE_E} ${INDEX_DIRECTORY}/index_r reads.fastq > temp_r
      dieUponError "Alignment to reverse strand failed, sub-task ${CURRENT_PART} of ${NUMBER_OF_PARTS}, failed"
      ${RESOURCES_MERGE_BATCHES_EXEC} temp_f temp_r | ${RESOURCES_LAST_MAP_PROBS_EXEC} -s${PLUGINS_ALIGNER_LAST_BISULFITE_S} > alignments.maf
      dieUponError "Combining forward and reverse strand alignments failed, sub-task ${CURRENT_PART} of ${NUMBER_OF_PARTS}, failed"

      goby last-to-compact -i alignments.maf -o ${OUTPUT} --third-party-input true --only-maf -q ${READS_FILE} -t ${REFERENCE} --quality-filter-parameters threshold=1.0
      dieUponError "Conversion of MAF file to Goby alignment failed, sub-task ${CURRENT_PART} of ${NUMBER_OF_PARTS}, failed"

}
