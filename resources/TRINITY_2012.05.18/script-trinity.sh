

function setup_trinity {

	if [ ! -e Trinity.pl ]
	then
		tar -x -f ${RESOURCE_TRINITY_TRINITY_TAR}
	fi
	
}

#args list
#1: Path to input compact-reads file
#2: Output file
#3: Other options for trinity

function run_trinity {

	local INPUT=$1
	local OUTPUT=$2
	local OTHER_OPTIONS=$3

	#trinity doesnt support compact-reads, convert to fastq
	local TEMPFILE='mktemp readsXXXX'
	goby compact-to-fasta --output-format fastq --input ${INPUT} --output ${TEMPFILE}
	
	#run trinity on converted file
	local TEMPDIR='mktemp -d trinity_outXXXX'
	./Trinity.pl --seqType fq -kmer_method inchworm --single ${TEMPFILE} --CPU 4 --output ${TEMPDIR} ${OTHER_OPTIONS}
	
	#copy trinity output file to specified location
	cp ${TEMPDIR}/Trinity.fasta ${OUTPUT}
	
}


setup_trinity



