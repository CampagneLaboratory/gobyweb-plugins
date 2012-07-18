#!/usr/bin/env groovy

//input args are filenames to combine

class FileData{
    Reader input

    String line
    String[] parts
}

def fileList = args.collect {
    def out = new FileData()
    out.input = new File(it).newReader()
    out.input.readLine()
    out
}

def read = {
    fileList.each {
        it.line = it.line ?: it.input.readLine()
        it.parts = it.line?.split("\t")
    }
    fileList
}

def window

while ((window = read()).any {it.line != null}){
    def minPosition = window.findAll {it.line != null}.min {
        it.parts[1].toInteger()
    }.parts[1].toInteger()

    def chromosome = ""

    def row = window.collect {
        if(it.line != null && it.parts[1].toInteger() == minPosition){
            it.line = null
            chromosome = it.parts[0]
            it.parts[2..4].join("\t")
        }
        else{
            ['', '', ''].join("\t")
        }
    }

    println "${chromosome}\t${minPosition}\t${row.join("\t")}"

}