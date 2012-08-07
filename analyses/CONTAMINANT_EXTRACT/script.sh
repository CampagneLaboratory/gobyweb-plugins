#!/bin/bash
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
. ${RESOURCES_MINIA_SHELL_SCRIPT}
. ${RESOURCES_TRINITY_SHELL_SCRIPT}
. ${RESOURCES_EXTRACT_NONMATCHED_SHELL_SCRIPT}
. ${JOB_DIR}/plugin-constants.sh


function plugin_alignment_analysis_split {
	local SPLICING_PLAN_RESULT=$2
	echo ;
}

# This function return the number of parts in the slicing plan. It returns zero if the alignments could not be split.
function plugin_alignment_analysis_num_parts {
	return $NUM_SPLITS
}

function plugin_alignment_analysis_process {

	local SPLICING_PLAN_FILENAME=$1
	local CURRENT_PART=$2



    if [ "$PLUGINS_ALIGNMENT_ANALYSIS_CONTAMINANT_EXTRACT_MERGE_GROUPS" == 'false' ]; then
        local PART_BASENAMES=${PLUGIN_BASENAMES[$CURRENT_PART]}
        local SPLIT_TYPE='Sample'
        local SPLIT_NAME=${PLUGIN_BASENAMES[$CURRENT_PART]}

    else
        local PART_BASENAMES=${PLUGIN_GROUP_ALIGNMENTS[$CURRENT_PART]}
        local SPLIT_TYPE='Group'
        local SPLIT_NAME=$CURRENT_PART #todo groupname
        echo ;
    fi


    for SOURCE_BASENAME in $PART_BASENAMES
    do
	    local REDUCED_BASENAME=`basename ${SOURCE_BASENAME}`

	    #copy over unmatched reads
        scp "${SOURCE_BASENAME}-unmatched.compact-reads" "unmatched-part-${REDUCED_BASENAME}.compact-reads" #todo fix name conflicts
        if [ $? -eq 0 ]; then
            echo "found the unmapped reads"
        else

            echo "unmapped reads not found, running extraction now"

            local READS_FILE=${PLUGIN_READS[$CURRENT_PART]}

            extract_unmatched_reads "${READS_FILE}" "${ENTRIES_DIRECTORY}/${REDUCED_BASENAME}" "unmatched-part-${REDUCED_BASENAME}.compact-reads"

        fi
        dieUponError "Could not retrieve unmapped reads for basename ${REDUCED_BASENAME}"

    done

    run-goby 4g concatenate-compact-reads -o "unmatched${CURRENT_PART}.compact-reads" unmatched-part-*.compact-reads



	NUM_UNMATCHED_READS=`goby compact-file-stats unmatched${CURRENT_PART}.compact-reads | grep 'Number of entries' | awk 'BEGIN{FS=" = "} {print $2}' | tr -d ','`
	
	if [ "${PLUGINS_ALIGNMENT_ANALYSIS_CONTAMINANT_EXTRACT_TRIM_ADAPTERS}" == "true" ]; then
		echo "trimming illumina adapters off of reads"
		run-goby 4g trim --adapters "${RESOURCES_ILLUMINA_ADAPTERS_FILE_PATH}" --input "unmatched${CURRENT_PART}.compact-reads" --output "unmatched${CURRENT_PART}-trimmed.compact-reads"
	else
		ln -s "unmatched${CURRENT_PART}.compact-reads" "unmatched${CURRENT_PART}-trimmed.compact-reads"
	fi
	
	dieUponError "Could not trim reads"
	
	#assemble reads into longer contigs
	if [ "${PLUGINS_ALIGNMENT_ANALYSIS_CONTAMINANT_EXTRACT_ASSEMBLER}" == "MINIA" ]; then
		echo "using minia to assemble reads"
		run_minia "unmatched${CURRENT_PART}-trimmed.compact-reads" "assembled${CURRENT_PART}.fasta" ${PLUGINS_ALIGNMENT_ANALYSIS_CONTAMINANT_EXTRACT_KMER_LENGTH}
	else
		echo "using trinity to assemble reads"
		run_trinity "unmatched${CURRENT_PART}-trimmed.compact-reads" "assembled${CURRENT_PART}.fasta"
	fi
	
	dieUponError "Could not assemble reads."
	
	#create counts index of assembled file for E-value computation
	${RESOURCES_LAST_INDEXER} -x assembled "assembled${CURRENT_PART}.fasta"
	dieUponError "Could not index assembled file"

	if [ "${PLUGINS_ALIGNMENT_ANALYSIS_CONTAMINANT_EXTRACT_SEARCH_REFERENCE}" == "VIRAL" ]; then
        #extract viral ref tarball
        tar -zxvf ${SGE_O_WORKDIR}/viralref.tar.gz

        local REF_BASENAME="viralref"

    else
        #extract viral ref tarball
        tar -zxvf ${SGE_O_WORKDIR}/microref.tar.gz

        local REF_BASENAME="microref"
    fi
	
	#run alignment and print results into tsv format
	${RESOURCES_LAST_EXEC_PATH} -f 0 ${REF_BASENAME} "assembled${CURRENT_PART}.fasta" | \
  		${RESOURCES_LAST_EXPECT} ${REF_BASENAME}.prj assembled.prj - | \
  		sed '/^#/ d' | \
  		awk '{print $2, "\t", "'${SPLIT_NAME}'", "\t", $7, "\t", $9, "\t", $1, "\t", $13}' > "${TAG}-results-${CURRENT_PART}.tsv"
  		
  	ls
  	
  	dieUponError "Could not align assembled file"
  	
  	
  	if [ "${PLUGINS_ALIGNMENT_ANALYSIS_CONTAMINANT_EXTRACT_ALIGNER}" == "BWA" ]; then
		echo "using BWA to realign reads to contigs"
		
		#index contigs for realignment with reads
  		${RESOURCES_BWA_WITH_GOBY_EXEC_PATH} index "assembled${CURRENT_PART}.fasta"
 	 	dieUponError "Could not index assembled file with bwa"
 		
  		#align unmapped reads onto contigs
  		${RESOURCES_BWA_WITH_GOBY_EXEC_PATH} aln -t 4 -f "realignment${CURRENT_PART}.sai" "assembled${CURRENT_PART}.fasta" "unmatched${CURRENT_PART}.compact-reads"
  		dieUponError "realignment 'aln' part failed"
  		
  		${RESOURCES_BWA_WITH_GOBY_EXEC_PATH} samse -F goby -f "realignment${CURRENT_PART}" "assembled${CURRENT_PART}.fasta" "realignment${CURRENT_PART}.sai" "unmatched${CURRENT_PART}.compact-reads"
  		dieUponError "realignment 'samse' part failed"
		
	else
		echo "using LAST to realign reads to contigs"
		
		${RESOURCES_LAST_INDEXER} "assembled${CURRENT_PART}" "assembled${CURRENT_PART}.fasta"
		dieUponError "Could not index assembled file with last"
		
		run-goby 4g compact-to-fasta --input "unmatched${CURRENT_PART}.compact-reads" --output "unmatched${CURRENT_PART}.fasta"
		
		${RESOURCES_LAST_EXEC_PATH} "assembled${CURRENT_PART}" "unmatched${CURRENT_PART}.fasta" > "realignment${CURRENT_PART}.maf"
		
		run-goby 4g last-to-compact --only-maf --input "realignment${CURRENT_PART}" --output "realignment${CURRENT_PART}"
	fi
  	
  	
  	run-goby 2g alignment-to-transcript-counts --parallel "realignment${CURRENT_PART}" -o "realignment${CURRENT_PART}"
  	
  	#format output
  	awk 'NR > 1 { print "'${REDUCED_BASENAME}'", "\t", $2, "\t", int($3), "\t", (int($3) * 100) / '${NUM_UNMATCHED_READS}' }' \
  	   < "realignment${CURRENT_PART}-transcript-counts.txt" > "${TAG}-realignment-${CURRENT_PART}.tsv"
  	
  	dieUponError "Formatting output failed"
  	
  	#copy working dir files to a temp folder so i can look at them
  	mkdir -p ${SGE_O_WORKDIR}/tempoutput/part${CURRENT_PART}
  	cp * ${SGE_O_WORKDIR}/tempoutput/part${CURRENT_PART}
  	
  	#copy assembled files back
  	mkdir -p ${SGE_O_WORKDIR}/contigs
  	cp "assembled${CURRENT_PART}.fasta" "${SGE_O_WORKDIR}/contigs/${TAG}-assembled-${REDUCED_BASENAME}.fasta"
  	dieUponError "Could not copy back assembled reads"
}

function plugin_alignment_analysis_combine {

	local OUTPUT_FILE_FULL="contaminants.tsv"
	local OUTPUT_FILE_SUMM="summary.tsv"
	local OUTPUT_FILE_REALIGN="realigned.tsv"
	shift
	local PART_RESULT_FILES=$*
	
	#copy assembler output files here
	mkdir assembled
	cp ${SGE_O_WORKDIR}/contigs/*-assembled-*.fasta assembled
	
	#tarball them
	tar -zvcf assembled-reads.tar.gz assembled/*
	
	dieUponError "Could not tarball assembled reads"
	
	local TEMPFILE_FULL=`mktemp readsXXXX`
	local TEMPFILE_REALIGN=`mktemp readsXXXX`
	
	PART_FULL_FILES=`echo "$PART_RESULT_FILES" | tr ' ' '\n' | grep '-results-' | tr '\n' ' '`
	PART_REALIGN_FILES=`echo "$PART_RESULT_FILES" | tr ' ' '\n' | grep '-realignment-' | tr '\n' ' '`
	
	cat $PART_FULL_FILES > $TEMPFILE_FULL
	dieUponError "Could not combine full output files"
	
	cat $PART_REALIGN_FILES > $TEMPFILE_REALIGN
	dieUponError "Could not combine realigned output files"
	
	
	ACCESSION_NAME_MAP="${SGE_O_WORKDIR}/viral-names.map"
	
	#create full output and output summary tsv files
	
	${SGE_O_WORKDIR}/OutputFormatter.groovy ${ACCESSION_NAME_MAP} ${TEMPFILE_FULL} ${OUTPUT_FILE_FULL} \
			${OUTPUT_FILE_SUMM} ${PLUGINS_ALIGNMENT_ANALYSIS_CONTAMINANT_EXTRACT_EVALUETHRESHOLD} \
			${PLUGINS_ALIGNMENT_ANALYSIS_CONTAMINANT_EXTRACT_IDENTITYTHRESHOLD}
	
	dieUponError "Failed formatting output"

	local SPLIT_TYPE=''
	if [ "$PLUGINS_ALIGNMENT_ANALYSIS_CONTAMINANT_EXTRACT_MERGE_GROUPS" == 'false' ]; then
        SPLIT_TYPE='Sample'

    else
        SPLIT_TYPE='Group'
    fi
	
	echo -e ${SPLIT_TYPE}'\tContig\tMatching Reads\tPercent of reads' > $OUTPUT_FILE_REALIGN
	
	cat $TEMPFILE_REALIGN >> $OUTPUT_FILE_REALIGN
	
	

}