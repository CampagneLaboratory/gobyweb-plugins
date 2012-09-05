/**
 * Script that extracts splicing counts from one Goby alignment, and formats the counts in such a way that they can be fed
 * to EdgeR to estimate p-values of differential splicing usage.
 * @author Fabien Campagne
 *         Date: Sept / 5 / 2012
 *         Time: 11: 09 PM
 */

import edu.cornell.med.icb.goby.alignments.Alignments.{RelatedAlignmentEntry, AlignmentEntry}
import edu.cornell.med.icb.goby.alignments.{AlignmentReader, AlignmentReaderImpl}
import edu.cornell.med.icb.identifier.DoubleIndexedIdentifier
import it.unimi.dsi.fastutil.ints.IntArrayList
import it.unimi.dsi.io.{FastBufferedReader, LineIterator}
import it.unimi.dsi.io.{LineIterator, FastBufferedReader}

val sampleFilename: String = args(0)
val reader = new AlignmentReaderImpl(sampleFilename)
reader.readHeader()
var lastRef = 0
var lastRefId = ""
var lastFirstBase = 0
var count = 0
var strand = "1"
/**
output format:
 sample  chromosome      first base of the intron (1-based)      last base of the intron (1-based)       strand  intron motif    junctionCount   log2normalizedCount
 CMASXKD-naira-july-23-2012-WT-J1-2      3       134885280       134886133       1       GT/AG   34      -18.120927819481206

 */


val targetIds = reader.getTargetIdentifiers
val reverseIds = new DoubleIndexedIdentifier(targetIds)
var firstBase = -1
var lastBase = 0
var motif = "??/??"
var previous = false

def printAll(entry: AlignmentEntry, link: RelatedAlignmentEntry) {
  if (previous) {
    print(sampleFilename)
    print("\t")
    print(lastRefId)
    print("\t")
    print(firstBase)
    print("\t")
    print(lastBase)
    print("\t")
    print(strand)
    print("\t")
    print(motif)
    print("\t")
    print(count)
    print("\t")
    print("0.0")
    println()
    count=0
  }
  if (link != null) {
    lastRef = link.getTargetIndex
    lastRefId = reverseIds.getId(link.getTargetIndex).toString
    lastFirstBase = firstBase

    lastBase = link.getPosition + 1
    strand = if (entry.getMatchingReverseStrand) "-1" else "+1"
    previous = true

  }
}

while (reader.hasNext) {
  val entry = reader.next()
  if (entry.hasSplicedForwardAlignmentLink) {
    val link = entry.getSplicedForwardAlignmentLink
    val firstBase = entry.getPosition + entry.getQueryAlignedLength + 1
    if (link.getTargetIndex != lastRef || firstBase != lastFirstBase) {

      printAll(entry, link)

    } else {
      count = count + 1
    }
  }

}

if (lastFirstBase != 0 || lastRef != 0) {
  printAll(null, null)
}

