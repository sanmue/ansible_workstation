#!/usr/bin/env bash

#set -x

# ### rsync - zusätzliche Parameter:
paramRsync='--dry-run'
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

# ### Gesamt, ohne VM
echo -e "\n ======================================== "
echo "Starte backup von '${source}' nach '${dest}' - MIRROR ohne '01_VM'"
logname="backupMirror_noVM_$(date +"%Y-%m-%d_%H%M%S").log"
# exclude '01_VM' im ersten Lauf wg. sudo   
# ### dry-run:
#sudo rsync ${paramRsync} -aPhEv --delete --force --exclude={'01_VM','lost+found','.Trash*'} "${source}/" "${dest}/" | tee "/tmp/${logname}"   
rsync -aPhEv --delete --force --exclude={'01_VM','lost+found','.Trash*'} "${source}/" "${dest}/" | tee "/tmp/${logname}"

# ### VM
echo "Starte backup von '${source}/01_VM/' nach '${dest}/01_VM/'"
logname="backupMirrorVM_$(date +"%Y-%m-%d_%H%M%S").log"
sudo rsync -aPhEv --delete --force "${source}/01_VM/" "${dest}/01_VM/" | tee "/tmp/${logname}"
echo " ======================================== "