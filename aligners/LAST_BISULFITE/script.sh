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
      ${QUEUE_WRITER} --tag ${TAG} --status ${JOB_PART_ALIGN_STATUS} --description "Align, sub-task ${CURRENT_PART} of ${NUMBER_OF_PARTS}, starting" --index ${CURRENT_PART} --job-type job-part

      # Make sure the scripts we use are executable:
      chmod +x ${PLUGINS_ALIGNER_LAST_BISULFITE_FILES_ALIGN_FORWARD}  ${PLUGINS_ALIGNER_LAST_BISULFITE_FILES_ALIGN_REVERSE} ${RESOURCES_PLAST_SCRIPT} ${RESOURCES_GOBY_SHELL_SCRIPT}
      set -x
      ${RESOURCES_PLAST_SCRIPT} ${JOB_DIR} ${PLUGINS_ALIGNER_LAST_BISULFITE_FILES_ALIGN_FORWARD} ${READS_FILE} align_f

      ${RESOURCES_PLAST_SCRIPT} ${JOB_DIR} ${PLUGINS_ALIGNER_LAST_BISULFITE_FILES_ALIGN_REVERSE} ${READS_FILE} align_r

      goby merge-compact-alignments  align_f align_r -o presort-${OUTPUT}
      dieUponError "Merging forward and reverse strand results failed, sub-task ${CURRENT_PART} of ${NUMBER_OF_PARTS}, failed"

      # sorting this chunk will use a lot of memory. We do this here because we can control the memory allocated to the JVM:
      run-goby 20g sort presort-${OUTPUT} -o ${OUTPUT}
      dieUponError "pre-sorting chunk failed, sub-task ${CURRENT_PART} of ${NUMBER_OF_PARTS}, failed"

}
