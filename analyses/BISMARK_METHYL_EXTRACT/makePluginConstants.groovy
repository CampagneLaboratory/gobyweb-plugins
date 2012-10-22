
/**
 * Make an output file which maps alignments to reads.
 * @param gobywebObj the gobyweb object just configured for this plugin
 * @param tempDir temporary directory where to write files that will be transferred to the cluster with the plugin
 * @return exit code, 0 means executed normally
 */
int execute(final Object gobywebObj, final File tempDir, final Map bindings) {
    final File outputFile = new File(tempDir, "plugin-constants.sh")

    outputFile.withPrintWriter {
        findSplits(gobywebObj, it)
        findPaired(gobywebObj, it)
    }

    return 0
}

void findSplits(Object gobywebObj, PrintWriter out){
    out.println "PLUGIN_NUM_SPLITS=${gobywebObj.allAlignments().size()}"

    gobywebObj.allAlignments().eachWithIndex {alignment, i ->
        out.println "PLUGIN_BASENAME[${i + 1}]=${alignmentFilename(alignment)}"
    }
}

void findPaired(Object gobywebObj, PrintWriter out){
    gobywebObj.allAlignments().eachWithIndex {alignment, i ->
        out.println "PLUGIN_PAIRED[${i + 1}]=${alignment.alignJob.sample.pairedSample}"
    }
}

/**
 * This comes from alignmentService.alignmentFilename().
 * @param alignment the alignment in question
 * @param extension the extension to provide a filename for
 * @return
 */
public String alignmentFilename(Object alignment) {
    // some versions of GobyWeb stored "tag-basename" in the basename.
    if (alignment.basename.startsWith(alignment.alignJob.tag)) {
        return "${alignment.basename}"
    } else {
        // if the basename does not include the tag, make sure we return a filename that includes it:
        return "${alignment.alignJob.tag}-${alignment.basename}"
    }
}