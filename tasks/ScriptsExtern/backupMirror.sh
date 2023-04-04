#!/usr/bin/env bash

#set -x

# ### rsync - zusätzliche Parameter:
#paramRsync='--dry-run'
#paramRsync=''

if [ $# -gt 1 ]; then   # wenn (mehr als 0) Übergabeparameter vorhanden
	source=$1
	source=${source%/}
	dest=$2
	dest=${dest%/}
else
	echo "Keine 2 Parameter (Quelle, Ziel), Ende."
	exit 1
fi

# Prüfung Quell:
if [ -e "${source}" ]; then             # Prüfung, ob Sicherungsziel existiert
	echo "Quellpfad ist: ${dest}"
else
	echo "Parameter 1: Quellpfad '${source}' existiert nicht, Ende."
	exit 1
fi
# Prüfung Zielpfad:
if [ -e "${dest}" ]; then             # Prüfung, ob Sicherungsziel existiert
	echo "Zielpfad ist: ${dest}"
else
	echo "Parameter 2: Zielpfad '${dest}' existiert nicht, Ende."
	exit 1
fi


# ### ###############################
# ### Sicherung (Mirror)
# Standard
#echo -e "\n========================================"
#echo "Starte backup von '${source}' nach '${dest}' - MIRROR"
#logname="backupMirror_$(date +"%Y-%m-%d_%H%M%S").log"
##rsync --dry-run -aPhEv --delete --force --exclude={'01_VM','lost+found','.Trash*'} "${source}/" "${dest}/" | tee "/tmp/${logname}"
#rsync -aPhEv --delete --force --exclude={'01_VM','lost+found','.Trash*'} "${source}/" "${dest}/" | tee "/tmp/${logname}"
## da Owner, Group, ... erhalten bleiben, kann man auch mit root machen, aber sollte nicht notwendig sein:
##sudo rsync -aPhEv --delete --force --exclude={'01_VM','lost+found','.Trash*'} "${source}/" "${dest}/" | tee "/tmp/${logname}"
#echo '========================================'

# VM (sudo)
#echo -e "\n========================================"
#echo "Starte backup von '${source}/01_VM/' nach '${dest}/01_VM/' - MIRROR"
#logname="backupMirrorVM_$(date +"%Y-%m-%d_%H%M%S").log"
##sudo rsync --dry-run -aPhEv --delete --force "${source}/01_VM/" "${dest}/01_VM/" | tee "/tmp/${logname}"
#sudo rsync -aPhEv --delete --force "${source}/01_VM/" "${dest}/01_VM/" | tee "/tmp/${logname}"
#echo '========================================'

# Gesamt (sudo)
echo -e "\n========================================"
echo "Starte backup von '${source}' nach '${dest}' - MIRROR"
logname="backupMirrorAll_$(date +"%Y-%m-%d_%H%M%S").log"
#sudo rsync --dry-run -aPhEv --delete --force --exclude={'lost+found','.Trash*'} "${source}/" "${dest}/" | tee "/tmp/${logname}"
sudo rsync -aPhEv --delete --force --exclude={'lost+found','.Trash*'} "${source}/" "${dest}/" | tee "/tmp/${logname}"
echo '========================================'
