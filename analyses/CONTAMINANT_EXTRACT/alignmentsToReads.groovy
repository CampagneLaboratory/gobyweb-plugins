/**
 * Make an output file which maps alignments to reads.
 * @param gobywebObj the gobyweb object just configured for this plugin
 * @param tempDir temporary directory where to write files that will be transferred to the cluster with the plugin
 * @return exit code, 0 means executed normally
 */
int execute(final Object gobywebObj, final File tempDir, final Map bindings) {
    final File outputFile = new File(tempDir, "alignmentsToReads.tsv")
    final PrintWriter writer = outputFile.newPrintWriter()
    try {
        gobywebObj.grpToAligns.each { String key, Object alignment ->
            final String compactReadsLocation = (alignment.alignJob.sample.compactReads as List)[0].url.split(":")[1]
            final String alignJobBasename = "${alignmentFilename(alignment, "entries") - (".entries")}"
            writer.println "${alignJobBasename}\t${compactReadsLocation}"
        }
    } finally {
        writer.close()
    }
    return 0
}

/**
 * This comes from alignmentService.alignmentFilename().
 * @param alignment the alignment in question
 * @param extension the extension to provide a filename for
 * @return
 */
public String alignmentFilename(Object alignment, String extension) {
    // some versions of GobyWeb stored "tag-basename" in the basename.
    if (alignment.basename.startsWith(alignment.alignJob.tag)) {
        return "${alignment.basename}.${extension}"
    } else {
        // if the basename does not include the tag, make sure we return a filename that includes it:
        return "${alignment.alignJob.tag}-${alignment.basename}.${extension}"
    }
}
