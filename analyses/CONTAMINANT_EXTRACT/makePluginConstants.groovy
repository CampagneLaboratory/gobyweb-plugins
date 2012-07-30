//import edu.cornell.med.icb.nga.datamodel.DiffExp
 /**
 * Make an output file which maps alignments to reads.
 * @param gobywebObj the gobyweb object just configured for this plugin
 * @param tempDir temporary directory where to write files that will be transferred to the cluster with the plugin
 * @return exit code, 0 means executed normally
 */
int execute(final Object gobywebObj, final File tempDir, final Map bindings) {
    //DiffExp casted = (DiffExp) gobywebObj

    //println gobywebObj.grpToAligns.keySet().toListString();

    final File outputFile = new File(tempDir, "plugin-constants.sh")
    final PrintWriter writer = outputFile.newPrintWriter()
    try {
        gobywebObj.allAlignments().eachWithIndex {alignment, index ->
            writer.println "PLUGIN_READS[${index + 1}]=${(alignment.alignJob.sample.compactReads as List)[0].url.split(":")[1]}"
            writer.println "PLUGIN_BASENAMES[${index + 1}]=${alignmentFilename(alignment)}"
            writer.println "PLUGIN_GROUPS[${index + 1}]=${gobywebObj.grpToAligns.find {k, v -> v == alignment}.key}"
        }
        (0..<gobywebObj.numberOfGroups).each {
            writer.println "PLUGIN_GROUP_ALIGNMENTS[${it}]='${gobywebObj.alignmentsListForGroupNumber(it).collect {alignmentFullPath(it, bindings)}.join(" ")}'"
        }
        def numSplits = gobywebObj.attributes["CONTAMINANT_EXTRACT_MERGE_GROUPS"] == 'true' ? gobywebObj.numberOfGroups : gobywebObj.allAlignments().size()
        writer.println "NUM_SPLITS=${numSplits}"
    } finally {
        writer.close()
    }
    return 0
}

public String alignmentFullPath(Object alignment, final Map bindings) {
    String resultPath = "%WEB_SERVER_SSH_PREFIX%:${bindings.pathService.usersExistingWebJobResultsDir(alignment.alignJob)}"
    return "${resultPath}/${alignmentFilename(alignment)}"
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
