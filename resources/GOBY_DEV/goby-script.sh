
function run-goby {
   set -x
   set -T
   memory="$1"
   shift
   mode_name="$1"
   shift

   java -Xmx${memory} -Dlog4j.debug=true -Dlog4j.configuration=file:${TMPDIR}/log4j.properties \
                                             -Dgoby.configuration=file:${TMPDIR}/goby.properties \
                       -jar ${RESOURCES_GOBY_GOBY_JAR} \
                       --mode ${mode_name} $*
}


function goby {
   set -x
   set -T
   mode_name="$1"
   shift

   java ${GRID_JVM_FLAGS} -Dlog4j.debug=true -Dlog4j.configuration=file:${TMPDIR}/log4j.properties \
                                             -Dgoby.configuration=file:${TMPDIR}/goby.properties \
                       -jar ${RESOURCES_GOBY_GOBY_JAR} \
                       --mode ${mode_name} $*
}
