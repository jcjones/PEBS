#!/bin/bash
#  PEBS - Pug's Extensible Backup System
#     Copyright (C) 2006 James C. Jones
#
#  Backup infastructure written by James 'Pug' Jones <pug@pugsplace.net>
#  on 13 January 2006. These scripts are licensed under the GNU GPL version
#  2 or later. See the included LICENSE file.
#
#  These scripts use GPG, OpenSSH, BASH and Moshe Jacobson's "color" shell
#  utility. "color" can be obtained at http://www.runslinux.net/projects.html
#

if [ ! -r functions.inc.sh ] ; then
    echo "Could not load functions.inc.sh - check that it's in the current directory."
    exit 1
fi

if [ ! -r configuration.inc.sh ] ; then
    echo "Could not find configuration.inc.sh - have you made such a configuration file? Modify the sample version."
    exit 1
fi

source functions.inc.sh

source configuration.inc.sh

#
#  The following is program code, don't fiddle. :)
#

#Don't mess with these.
remoteBackupEnabled=1
Version=0.32

#Take care of command line options
parseCommandLineOptions $*

#Make sure we're root
if [ $(id -u) -ne 0 ] ; then
	warning "You must run PEBS as root for now. Sorry."
	exit 1
fi

#Initialization
printBanner
createDirIfNotExist $tempDirectory
createDirIfNotExist $tempDirectory/Results

#Erase old results, if not already cleaned up
rm -f $tempDirectory/Results/*

echo ""  >> $logFile
echo "Backup run begins at $(date) by user $(whoami)"  >> $logFile

#Execute subscripts
for i in $scriptDir/*.inc.sh ; do
	scriptName=$(basename $i | cut --delim=. -f 1)

	scriptOwner=$(stat -c %U "$scriptDir/$scriptName.inc.sh")

	scriptFinalTarball="$tempDirectory/Results/$date_$scriptName.tar.gz"
	scriptTempDirectory="$tempDirectory/$scriptName"

	createDirIfNotExist $scriptTempDirectory
	chown $scriptOwner $scriptTempDirectory

	runScript "$scriptDir/$scriptName.inc.sh"
	if [ ! -e "$scriptFinalTarball" ] ; then
		warning "No tarball produced by $scriptName."
	fi

	cleanupAfterScript
done

# Find list of created .tar.gz files
listToTar=""

for i in $tempDirectory/Results/*.gz ; do
	if [ -r "$i" ] ; then
		listToTar="$listToTar $i"
	fi
done

# Perform the tar, encrypt and send
if [ "$listToTar" != "" ]; then
	progress "Making final backup tar for this run."
	doMakeTar $tempDirectory/$finalTar $listToTar

	size=$(du --si $tempDirectory/$finalTar | cut -f 1)

	# Delete old encrypted copy 
	rm -f $tempDirectory/$finalTar.gpg

	# Encrypt
	note "Encrypting using $encryptEmail's public key..."
	gpg --use-agent -r "$encryptEmail" --encrypt-file $tempDirectory/$finalTar | tee -a $logFile

	if [ $remoteBackupEnabled -gt 0 ] ; then
		note "Transmitting to $remoteHostName. Total size: $size"
		scp -B $tempDirectory/$finalTar.gpg $remoteHostName:~/
	else
		warning "Not transmitting backup to remote location due to command line option."
	fi

	# MD5Summing
	note "Verifying hashes..."
	localHash=$(md5sum $tempDirectory/$finalTar.gpg | cut -d " " -f 1)
	remoteHash=$(ssh $remoteHostName md5sum $finalTar.gpg | cut -d " " -f 1)
	note "Local Hash: $localHash - Remote Hash: $remoteHash"

	if [ "$localHash" != "$remoteHash" ] ; then
		warning "HASHES NOT EQUAL, TRANSFER FAILED!"
		logger -p user.error System backup FAILED to $remoteHostName
	else
		progress "Hashes are identical. Good transfer."
		logger -p user.info System backup completed successfully to $remoteHostName
	fi

	progress "All Done!"
fi
