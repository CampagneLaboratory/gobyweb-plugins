#!/bin/sh
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

# ${RESOURCES_ILLUMINA_ADAPTERS_FILE_PATH} = path to adapters.txt, obtained from the ILLUMINA_ADAPTERS resource

# ALIGNER_OPTIONS = any GSNAP options the end-user would like to set

function plugin_align {

    OUTPUT=$1
    BASENAME=$2
    
    # set the number of threads to the number of cores available on the server divided by 4:
    ALIGNER_OPTIONS="${ALIGNER_OPTIONS} -p $((`grep physical /proc/cpuinfo | grep id | wc -l` / 4))"

	#set other aligner options
	ALIGNER_OPTIONS="${ALIGNER_OPTIONS} --fastq --bowtie2 --path_to_bowtie $(dirname ${RESOURCES_BOWTIE2_EXEC_PATH})"
	if [ "${LIB_PROTOCOL_PRESERVE_STRAND}" == "false" ]; then
		ALIGNER_OPTIONS="${ALIGNER_OPTIONS} --non_directional"
	fi
	
	#bismark is for methylation analysis so non-bisulfite doesnt make sense
    if [ "${BISULFITE_SAMPLE}" == "false" ]; then
        false
        dieUponError "only bisulfite samples are supported, alignment failed"
    fi

	#take out the slice of the reads file we are currently working with
	SPLIT_READS='split-reads.compact-reads'
	
	goby reformat-compact-reads  --start-position=${START_POSITION} --end-position=${END_POSITION}  ${READS_FILE} -o ${SPLIT_READS}
    dieUponError "reformat reads failed, sub-task ${CURRENT_PART} of ${NUMBER_OF_PARTS}, failed"


	#trim adapters off of reads
	TRIMMED_READS='trimmed-reads.compact-reads'

    goby trim  --input ${SPLIT_READS} --output ${TRIMMED_READS} --complement \
    		--adapters  ${RESOURCES_ILLUMINA_ADAPTERS_FILE_PATH}  --min-left-length 4
    dieUponError "trim reads failed, sub-task ${CURRENT_PART} of ${NUMBER_OF_PARTS}, failed"
    
    
    
    #convert to fastq and set input options
    FASTQ_READS='trimmed-reads-sanger.fastq'
	INPUT_OPTIONS="${INDEX_DIRECTORY}"
    if [ "${PAIRED_END_ALIGNMENT}" == "true" ]; then
        # Bismark expects fastq format files with sequence line in one row - guarantee with --fasta-line-length parameter
    	goby compact-to-fasta --output-format fastq --quality-encoding Sanger --fasta-line-length 1000 --input ${TRIMMED_READS} --output ${FASTQ_READS}-1 --pair-output ${FASTQ_READS}-2
    	
    	INPUT_OPTIONS="${INPUT_OPTIONS} -1 ${FASTQ_READS}-1 -2 ${FASTQ_READS}-2"
    	
    else
        goby compact-to-fasta --output-format fastq --quality-encoding Sanger --fasta-line-length 1000 --input ${TRIMMED_READS} --output ${FASTQ_READS}
    	
    	INPUT_OPTIONS="${INPUT_OPTIONS} ${FASTQ_READS}"
        
    fi
    
    dieUponError "converting to fastq format failed"    
    
    #run alignment
    ${RESOURCES_BISMARK_EXEC_PATH} ${ALIGNER_OPTIONS} ${INPUT_OPTIONS}
    dieUponError "alignment of reads with bismark failed"
    
    ls -ltr
    
    ${RESOURCES_SAMTOOLS_EXEC_PATH} view -Sbu "${FASTQ_READS}_bt2_bismark.sam" |
    	${RESOURCES_SAMTOOLS_EXEC_PATH} sort -o - output |
    	${RESOURCES_SAMTOOLS_EXEC_PATH} calmd - ${INDEX_DIRECTORY}/*.fa > 'md-alignment.sam'
    dieUponError "adding MD tag to output failed"
    
    ls -ltr
    head 'md-alignment.sam'
    
    #convert to compact alignment format
	goby sam-to-compact --preserve-all-tags --quality-encoding Sanger --input 'md-alignment.sam' --output ${OUTPUT}
	dieUponError "converting to compact alignment format failed"
	
	ls -ltr
	
	#copy summary report back
	mkdir -p ${SGE_O_WORKDIR}/split-results/mapping-reports
	cp "${FASTQ_READS}_bt2_Bismark_mapping_report.txt" "${SGE_O_WORKDIR}/split-results/${TAG}-mapping-report-${CURRENT_PART}.txt"
    dieUponError "copying back mapping report failed"
    
}

# This function is called after the alignment slices have been combined into one final output.
# It is called with three arguments, the basename of the alignment (present in the directory where this function is
# invoked), the reads filename (full path), the tag useful to create an output.

function plugin_alignment_combine {
    TAG=$1
    READS=$2
    BASENAME=$3

	#tarball mapping-records and copy them back
	mkdir mapping-reports
	cp ${SGE_O_WORKDIR}/split-results/mapping-reports/* mapping-reports/
	tar -zvcf mapping-reports.tar.gz mapping-reports
	
	cp mapping-reports.tar.gz ${RESULT_DIR}/${TAG}-${BASENAME}-mapping-reports.tar.gz

}
