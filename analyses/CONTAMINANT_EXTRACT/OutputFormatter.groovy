#!/usr/bin/env groovy

def ARGS_LENGTH = 4
//arg 1: path to accession-name map file
//arg 2: path to input file
//arg 3: path to full output file
//arg 4: path to summary output file

println args

def printUsage(){
    println "Incorrect Syntax"
    println "./OutputFormatter.groovy map_file input full_out summ_out"
}

if(args.length != ARGS_LENGTH){
    printUsage()
    System.exit(1)
}

//read in the names file
def nameMap = [:]
new File(args[0]).splitEachLine("\t"){
    nameMap[it[0]] = it[1]
}


def outFull = new File(args[2])
def sampleMap = [:]

outFull.write("Contaminant Species\tAccession Number\tSample\tContig\tAlignment Size\tScore\tE-value\n")

new File(args[1]).splitEachLine("\t"){
    outFull << nameMap[it[0].trim()] << "\t" << it.join("\t") << "\n"; //add organism name to full table

    //get existing organism list for sample, or make empty one if it doesnt exist yet
    def orgList = sampleMap[it[1]] ?: (sampleMap[it[1]] = [])

    //add organism to list
    orgList << nameMap[it[0].trim()]
}


def outsumm = new File(args[3])
outsumm.write("Sample\tOrganism\tNum Matched Contigs\n")
//this is where I will make the summary output

sampleMap.collect { sample, List orgList ->
    orgList.unique(false).collect { [sample, it,  orgList.count(it)] }  //collect counts for each sample-organism pair
}.inject([]) { acc, ele -> //flatten one level down
    acc.addAll(ele)
    acc
}.each { //write each record to output file
    outsumm << it.join("\t") << "\n"
}