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

# ALIGNER_OPTIONS = any Last options the end-user would like to set

# Please note that Goby must be configured with appropriate path to Last aligner executable.

function plugin_align {

      OUTPUT=$1
      BASENAME=$2

      COLOR_SPACE_OPTION=""
      if [ "${COLOR_SPACE}" == "true" ]; then
          COLOR_SPACE_OPTION=" --color-space "
      fi

      # Extract the reads if a split is needed
      if [ ! -z ${SGE_TASK_ID} ] && [ "${SGE_TASK_ID}" != "undefined" ] && [ "${SGE_TASK_ID}" != "unknown" ]; then
          ${QUEUE_WRITER} --tag ${TAG} --status ${JOB_PART_SPLIT_STATUS} --description "Split, sub-task ${CURRENT_PART} of ${NUMBER_OF_PARTS}, starting" --index ${CURRENT_PART} --job-type job-part
          # The reads file to process
          READS_FILE=${READS##*/}


          goby reformat-compact-reads --output ${READS_FILE} \
              --start-position ${START_POSITION} --end-position ${END_POSITION} ${READS}

          dieUponError "split reads failed, sub-task ${CURRENT_PART} of ${NUMBER_OF_PARTS}, failed"

      fi

       # Override the path to last to use the resource
       dirname=`dirname ${RESOURCES_LAST_EXEC_PATH}`
       echo "executables.path.last = ${dirname}" >>${TMPDIR}/goby.properties

       ALIGNER_OPTIONS_COMPLETE="matchQuality="${PLUGINS_LASTAG_GOBY_MATCH_QUALITY}","\
"maxGapsAllowed="${PLUGINS_LASTAG_GOBY_MAX_GAPS_ALLOWED}","\
"gapOpeningCost="${PLUGINS_LASTAG_GOBY_GAP_EXISTENCE_COST}","\
"gapExtensionCost="${PLUGINS_LASTAG_GOBY_GAP_EXTENSION_COST}","\
${ALIGNER_OPTIONS}

       # This Goby wrapper detects automatically if the reads file is paired end:
       goby align --reference ${REFERENCE} --aligner last ${COLOR_SPACE} --search \
           --ambiguity-threshold ${AMBIGUITY_THRESHOLD} --quality-filter-parameters "${QUALITY_FILTER_PARAMETERS}" \
           --database-name ${INDEX_PREFIX} --database-directory ${INDEX_DIRECTORY} \
           ${ALIGNER_OPTIONS} --reads ${READS_FILE} --basename ${OUTPUT} --options ${ALIGNER_OPTIONS_COMPLETE}

}
