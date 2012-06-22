/**
 *
 * @author Fabien Campagne
 *         Date: 6 / 20 / 12
 *         Time: 1: 01 PM

 */

import scala.collection.mutable.Set


//println("Executing with arguments: " + args.mkString(","))
val junctionMap = scala.collection.mutable.Map[String, Int]()
val sampleMap = scala.collection.mutable.Map[String, Int]()
val intronMotifs = scala.collection.mutable.Map[String, scala.collection.mutable.Set[String]]()
var header: String = ""
val COUNT_COL_INDEX = 7
for (file <- args) {
  // it: LineIterator = new LineIterator(new FastBufferedReader(file))
  val lines: Iterator[String] = scala.io.Source.fromFile(file).getLines()
  // ignore the header line:
  header = lines.next()
  for (line <- lines) {
    //println(line)
    var countToken: Int = 0
    var key: String = ""
    var value: Int = 0
    var cumulativeJunction: Int = 0
    var cumulativeSample: Int = 0
    val tokens = line.split("\t")

    val sample = tokens(0)
    val intronMotif = tokens(5)
    for (token <- tokens.slice(0, 5)) {
      key += token
      key += "|"
    }
    value = Integer.parseInt(tokens(COUNT_COL_INDEX))

    countToken += 1

    cumulativeJunction = if (junctionMap.contains(key)) (value + junctionMap(key)) else value
    cumulativeSample = if (sampleMap.contains(sample)) (value + sampleMap(sample)) else value
    val motifList:scala.collection.mutable.Set[String]=    if (intronMotifs.contains(key)) {
      intronMotifs(key) ++ scala.collection.mutable.Set(intronMotif)
    } else {
      scala.collection.mutable.Set(intronMotif)
    }
    intronMotifs += (key -> motifList)
    junctionMap += (key ->cumulativeJunction)
    sampleMap += (sample -> cumulativeSample)
  }
}
val headerColumns: List[String] = header.split("[\t]").toList

/*for (sample: String <- sampleMap.keys) {
           println("Sample: "+sample+" "+sampleMap(sample))
}
  */

println((headerColumns.slice(0, 5) ::: List("junctionCount") ::: List("log2normalizedCount")).mkString("\t"))
val LOG2: Double = StrictMath.log(2)
for (key: String <- junctionMap.keys) {

  val keys: Array[String] = key.split("[|]")
  val sample = keys(0)
  val junctionCount: Int = junctionMap(key)
  val sampleCount: Int = sampleMap(sample)
  val motifList: scala.collection.mutable.Set[String] = intronMotifs(key)
  val normalizedCount: Double = StrictMath.log(junctionCount.toDouble / sampleCount.toFloat) / LOG2
  println(keys.mkString("\t") + "\t" +  motifList.mkString(",")+"\t" +junctionCount + "\t" + normalizedCount)

}


