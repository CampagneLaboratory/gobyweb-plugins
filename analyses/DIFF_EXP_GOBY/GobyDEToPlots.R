# This script takes Goby DE TSV file and generates the appropriate scatterplot(s)
# Nyasha Chambwe June 2, 2010 & Kevin C. Dorff July 19, 2010

#--------------------------------------------------------------------------
# This version of the script is designed for running manually.
# Supply the command line options
#   input   -     tsv input file (for gene, exon, other)
#   graphOutput - png output file
#
#  Example command line:
#
#  R -f GobyDEToPlots.R --slave --quiet --no-restore --no-save --no-readline --args input=input.tsv graphOutput=output.png
#  R -f GobyDEToPlots.R --slave --quiet --no-restore --no-save --no-readline --args input=DUFSLYR.stats.tsv graphOutput=output.png
# For discussion about the input and output files, see the documentation
# above the function "processFile".
#--------------------------------------------------------------------------

#--------------------------------------------------------------------------
# FUNCTIONS FOR DIFF EXP PROCESSING AND SUPPORT
#--------------------------------------------------------------------------

library("Cairo")

#
# If the data in the chart is already log2
#
dataAlreadyLog2 <- TRUE

#
# Return the group names found in the file
#
findGroupNames <- function(columns, calcType) {
    groupNames <- c()
    # Look for "average log2_RPKM group" columns
    for (column in columns) {
        parts <- array(unlist(strsplit(column, "[\\(\\)]", perl=TRUE)))
        if (length(parts) == 2 && parts[2] == calcType) {
            parts <- array(unlist(strsplit(parts[1], "[ ]", perl=TRUE)))
            if (length(parts) == 4) {
                if (parts[1] == "average" && parts[2] == "log2_RPKM" && parts[3] == "group") {
                    groupNames[[length(groupNames) + 1]] = parts[4]
                }
            }
        }
    }
    if (length(groupNames) == 0) {
        # "average log2_RPKM group" columns not found. Look for "average RPKM group" columns
        for (column in columns) {
            parts <- array(unlist(strsplit(column, "[\\(\\)]", perl=TRUE)))
            if (length(parts) == 2 && parts[2] == calcType) {
                parts <- array(unlist(strsplit(parts[1], "[ ]", perl=TRUE)))
                if (length(parts) == 4) {
                    if (parts[1] == "average" && parts[2] == "RPKM" && parts[3] == "group") {
                        groupNames[[length(groupNames) + 1]] = parts[4]
                    }
                }
            }
        }
        if (length(groupNames) == 2) {
            dataAlreadyLog2 <<- FALSE
        }
    } else {
        dataAlreadyLog2 <<- TRUE
    }
    groupNames
}

findPlotColumnNums <- function(columns, calcType) {
    colNums <- c()
    currentColNum <- 1
    for (column in columns) {
        parts <- array(unlist(strsplit(column, "[\\(\\)]", perl=TRUE)))
        if (length(parts) == 2 && parts[2] == calcType) {
            parts <- array(unlist(strsplit(parts[1], "[ ]", perl=TRUE)))
            if (length(parts) == 4) {
                if ((dataAlreadyLog2) && parts[1] == "average" && parts[2] == "log2_RPKM" && parts[3] == "group") {
                    colNums[[length(colNums) + 1]] = currentColNum
                } else if ((!dataAlreadyLog2) && parts[1] == "average" && parts[2] == "RPKM" && parts[3] == "group") {
                    colNums[[length(colNums) + 1]] = currentColNum
                }
            }
        }
        currentColNum <- currentColNum + 1
    }
    colNums
}

#
# Simply return the graph output filename, ignoring suffix.
#
generateGraphFilename <- function(graphOutputFile, suffix) {

        graphOutputFile

    }
}

plotTable <- function(dataTable, groupNames, graphOutputFile, elementType) {
    if (nrow(dataTable) == 0) {
        return()
    }

    minx <- min(dataTable$log2x)
    maxx <- max(dataTable$log2x)
    miny <- min(dataTable$log2y)
    maxy <- max(dataTable$log2y)
    if (minx >= 0) {
        minx <- 0
    }
    if (miny >= 0) {
        miny <- 0
    }
    xlim <- c(minx, maxx)
    ylim <- c(miny, maxy)
    cat("xlim=",xlim,"ylim=",ylim,"\n")
    
    graphOutputFile <- generateGraphFilename(graphOutputFile, elementType)
    # MA-Plot for this analysis
    CairoPNG(filename=graphOutputFile, width=700, height=700)
    plot(dataTable$log2x, dataTable$log2y, xlab=paste("log2 RPKM of ",groupNames[1]), ylab=paste("log2 RPKM of ",groupNames[2]), xlim=xlim, ylim=ylim, col="black", pch=19, cex= .25)
    title(main = list(paste("Scatter Plot ", elementType, groupNames[1], "vs", groupNames[2]), cex=1.5, col="black", font=3))
    dev.off()
}

doubleAndLog2 <- function(val) {
    log2(as.double(val))
}

#
#
processFile <- function(inputFile, graphOutputFile) {
    # Read the tab delimited input file
    dataTable <- read.delim(inputFile, check.names=FALSE, as.is=TRUE)

    # replace row names with gene identifiers
    rownames(dataTable) <- dataTable$"element-id"
    dataTable <- dataTable[, -1]  # Slice out the element-id column

    colNames <- colnames(dataTable)
    colNames[1] = "elementType"
    colnames(dataTable) <- colNames

    # this vector assigns samples to a particular group
    workCalcType <- ""
    for (calcType in c("AC", "CAC", "BUQ")) {
        groupNames <- findGroupNames(colNames, calcType)
        if (length(groupNames) == 2) {
            workCalcType <- calcType
            break
        }
    }

    if (length(groupNames) != 2) {
        cat("Couldn't find 2 'average log2_RPKM group' or 'average RPKM group' columns\n")
        return()
    }

    plotColNums <- findPlotColumnNums(colNames, workCalcType)
    if (length(plotColNums) != 2) {
        cat("Couldn't find 2 'average log2_RPKM group' or 'average RPKM group' columns numbers\n")
        return()
    }

    # Rename the column that conains the data we want to plot
    if (dataAlreadyLog2) {
        colNames[plotColNums[1]] = "log2x"
        colNames[plotColNums[2]] = "log2y"
    } else {
        colNames[plotColNums[1]] = "x"
        colNames[plotColNums[2]] = "y"
    }
    colnames(dataTable) <- colNames
    # Keep only the columns that have the interesting data
    keepCols <- c("elementType", "x", "y", "log2x", "log2y")
    dataTable <- dataTable[ , (colnames(dataTable) %in% keepCols)]

    # If the data isn't already log2, conver the data to log2
    if (!dataAlreadyLog2) {
        dataTable$log2x <- sapply(dataTable$x, doubleAndLog2)
        dataTable$log2y <- sapply(dataTable$y, doubleAndLog2)
    } else {
        dataTable$log2x <- sapply(dataTable$log2x, as.double)
        dataTable$log2y <- sapply(dataTable$log2y, as.double)
    }

    # Filter out NA and Inf and-Inf from log2x, log2y
    dataTable <- subset(dataTable, (!(log2x == "NA" | log2y == "NA" | log2x == -Inf | log2y == -Inf | log2x == Inf | log2y == Inf)))

    # Split data by elementType
    geneDataTable <- subset(dataTable, elementType == "GENE")
    exonDataTable <- subset(dataTable, elementType == "EXON")
    otherDataTable <- subset(dataTable, elementType == "OTHER")
    transDataTable <- subset(dataTable, elementType == "TRANSCRIPT")
    dataTable <- NULL

    # Plot the data
    cat("Creating plots with dataAlreadyLog2=",dataAlreadyLog2,"workCalcType=",workCalcType,"\n")
    plotTable(geneDataTable, groupNames, graphOutputFile, "GENE")
    plotTable(exonDataTable, groupNames, graphOutputFile, "EXON")
    plotTable(otherDataTable, groupNames, graphOutputFile, "OTHER")
    plotTable(transDataTable, groupNames, graphOutputFile, "TRANSCRIPT")
}

#--------------------------------------------------------------------------
# COMMAND LINE PARSING
#--------------------------------------------------------------------------

input <- ""
graphOutput <- ""

notused <- capture.output(commandArgs())
for (e in commandArgs()) {
    ta = strsplit(e,"=",fixed=TRUE)
    if(! is.na(ta[[1]][2])) {
        temp = ta[[1]][2]
        assign(ta[[1]][1],temp)
    } else {
        assign(ta[[1]][1],TRUE)
  }
}

if (input == "" || graphOutput == "") {
    stop("This script requires input and graphOutput to be specified")
}

#--------------------------------------------------------------------------
# Process given the specifed command line
#--------------------------------------------------------------------------

processFile(input, graphOutput)
cat("Done\n")
