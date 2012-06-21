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

# OTHER_ALIGNMENT_ANALYSIS_OPTIONS = any options defined by the end-user or assembled with the auto-format mechanism.

. ${RESOURCES_GOBY_SHELL_SCRIPT}
. ${RESOURCES_TRINITY_SHELL_SCRIPT}


function plugin_alignment_analysis_split {
	local SPLICING_PLAN_RESULT=$2
	
	echo "${SOURCE_ALIGNMENT_FULL_PATH_BASENAMES}" | tr " " "\n" | sed '/^$/d' > ${SPLICING_PLAN_RESULT}

	
}

# This function return the number of parts in the slicing plan. It returns zero if the alignments could not be split.
function plugin_alignment_analysis_num_parts {
	local SPLICING_PLAN_FILE=$1

	if [ $? -eq 0 ]; then
		return `wc -l < ${SPLICING_PLAN_FILE}`
	fi
	
	return 0
}

function plugin_alignment_analysis_process {

	local SPLICING_PLAN_FILENAME=$1
	local CURRENT_PART=$2
	
	local SOURCE_BASENAME=`sed -n ${CURRENT_PART}p < ${SPLICING_PLAN_FILENAME}`

	
	rsync -t "${SOURCE_BASENAME}-unmatched.compact-reads" "unmatched${CURRENT_PART}.compact-reads"
	
	dieUponError "Could not retrieve unmapped reads"
	
	#use Trinity to assemble unmatched reads into larger groups
	run_trinity "unmatched${CURRENT_PART}.compact-reads" "assembled${CURRENT_PART}.fasta"
	
	dieUponError "Could not assemble with trinity."
	
	${RESOURCES_LAST_INDEXER} -x assembled "assembled${CURRENT_PART}.fasta"
	
	dieUponError "Could not index assembled file"
	
	local REF_BASENAME="${REFERENCE_DIRECTORY}/lastindex"
	
	REF_BASENAME='/home/zmz2/viral/viralref'
	
	
	#run alignment and print results into tsv format
	${RESOURCES_LAST_EXEC_PATH} -f 0 ${REF_BASENAME} "assembled${CURRENT_PART}.fasta" | \
  		${RESOURCES_LAST_EXPECT} ${REF_BASENAME}.prj assembled.prj - | \
  		sed '/^#/ d' | \
  		awk '{print $2, "\t", $7, "\t", $1, "\t", $13}' > "${TAG}-results-${CURRENT_PART}.tsv"
  		
  	ls
  	
  	dieUponError "Could not align assembled file"
}

function plugin_alignment_analysis_combine {

	local OUTPUT_FILE="contaminants.tsv"
	shift
	local PART_RESULT_FILES=$*
	
	
	local COLUMNS="Contaminant\tRead\tScore\tE-value"
	
	echo -e $COLUMNS > ${OUTPUT_FILE}

	cat ${PART_RESULT_FILES} >> ${OUTPUT_FILE}


	

}