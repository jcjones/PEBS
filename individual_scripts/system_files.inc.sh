#!/bin/bash
# The final tar.gz goes in $scriptFinalTarball and you can use $scriptTempDirectory for temp files

doMakeTar $scriptTempDirectory/system-etc-$date.tar \
	/etc

doMakeFinalTarball $scriptTempDirectory/system-etc-$date.tar


