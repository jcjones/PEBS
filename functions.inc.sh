
function note {
	if [ $havecolor ] ; then
		echo "[$($color cyan)?$($color off)] $*" | tee -a $logFile
	else
		echo "[?] $*" | tee -a $logFile
	fi
}

function progress {
	if [ $havecolor ] ; then
		echo "[$($color blue)*$($color off)] $*" | tee -a $logFile
	else
		echo "[*] $*" | tee -a $logFile
	fi
}

function warning {
	if [ $havecolor ] ; then
		echo "[$($color red)!$($color off)] $($color red)$*$($color off)" | tee -a $logFile
	else
		echo "[!] $*" | tee -a $logFile
	fi
}

function createDirIfNotExist {
	if [ ! -d "$*" ] ; then 
		mkdir "$*"
	fi
}

# high level helper
function findProgram {
	if [ -x "./$*" ] ; then
		echo "./$*"
		return
	else
		echo $(which $*)
		return
	fi
}

function runScript {
	progress "Executing $* (as root)"
	source $*
}

function cleanupAfterScript {
	note "Removing temp files for $scriptName"
	rm -f $scriptTempDirectory/*
	if [ $havecolor ] ; then	
		echo "$($color white)================================================$($color off)"
	else
		echo "================================================"
	fi
}

function doMakeTar {
	progress "Creating tar backup to $1"
	tar -cf $* 2>&1 | grep -v "Removing leading" | tee -a $logFile
}

function doMakeTarball {
	progress "Gzipping tar backups to $1"
	tar -zcf $* 2>&1 | grep -v "Removing leading" | tee -a $logFile
}

function doMakeFinalTarball {
	progress "Making final tarball for this backup set..."
	doMakeTarball $scriptFinalTarball $*
}

function printBanner {
cat << EOF
    ______ _______ ______ _______ 
   |   __ \    ___|   __ \     __|
   |    __/    ___|   __ <__     |
   |___|  |_______|______/_______|
 Pug's Extensible Backup System (Version $Version)
 This software is released under the GNU GPL Version 2 or later.
EOF
}

function printCommandList {
cat << EOF

Pug's Extensible Backup System (Version $Version)
Usage: $0 [OPTION] 
Performs backup functions based on scripts in 
   $scriptDir

  -p     do not actually transmit backup image to remote server
  -h     display this help and exit
  -v     output version information and exit

Report bugs to <pug@pugsplace.net>.
EOF
}

function parseCommandLineOptions {
	tempOpts=$(getopt "hpv" "$@")
	if [ $? -ne 0 ]; then
		printCommandList
		exit 1
	fi
	set -- $tempOpts

	while [ ! -z "$1" ]
	do
	  case "$1" in
	    -h) printCommandList; exit;;
	    -p) remoteBackupEnabled=0;;
	    -v) echo "$0 version $Version"; exit;;
	     *) break;;
	  esac
	
	  shift
	done
}

#Colorizing Setup
color=$(findProgram color)
havecolor=0
if [ -x "color" ] ; then
	havecolor=1
fi

