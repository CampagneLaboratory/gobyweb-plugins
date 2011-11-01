
function run-goby {
   set -x
   set -T
   memory="$1"
   shift
   mode_name="$1"
   shift

   GOBY_JAR=${RESOURCES_GOBY_GOBY_JAR}
   java -Xmx${memory} -Dlog4j.debug=true -Dlog4j.configuration=file:${TMPDIR}/log4j.properties \
                                             -Dgoby.configuration=file:${TMPDIR}/goby.properties \
                       -jar ${GOBY_JAR} \
                       --mode ${mode_name} $*
}
