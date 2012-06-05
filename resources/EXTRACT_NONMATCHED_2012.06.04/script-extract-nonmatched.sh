
#args list
#1: Path to the reads file
#2: Path to the alignment (basename)
#3: Output file


function extract_unmatched_reads {

local READS_FILE=$1
local ALIGNMENT=$2
local OUTPUT_FILE=$3

#export unmatched reads
#create filter file
goby alignment-to-read-set "${ALIGNMENT}" --non-matching-reads --non-ambiguous-reads -s unmatched
dieUponError "creating filter failed, sub-task ${CURRENT_PART} of ${NUMBER_OF_PARTS}, failed"

#filter out unmatched reads
goby reformat-compact-reads "${READS_FILE}" -f "${ALIGNMENT}-unmatched.filter" -o "${OUTPUT_FILE}"
dieUponError "reformat reads failed, sub-task ${CURRENT_PART} of ${NUMBER_OF_PARTS}, failed"
}

#args list
#1: Output file
#2...: Input files

function combine_unmatched_reads {
#concat files together

goby concatenate-compact-reads --quick-concat --output $1 ${@:2}
dieUponError "concat reads failed, sub-task ${CURRENT_PART} of ${NUMBER_OF_PARTS}, failed"

}
