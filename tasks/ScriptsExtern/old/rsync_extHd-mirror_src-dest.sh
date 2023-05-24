#!/usr/bin/env bash

#set -x

# ### rsync - zusätzliche Parameter:
paramRsync='--dry-run'

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
	echo "Quellpfad ist: ${source}"
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


# ### ##############
# ### rsync (Mirror)

read -rp "Start mit beliebiger Eingabe"

# ### Gesamt, ohne VM
echo -e "\n ======================================== "
echo "Starte rsync von '${source}' nach '${dest}' - MIRROR ohne '01_VM'"
logname="rsync_mirror-extHd_para_src-dest_ohneVM_$(date +"%Y-%m-%d_%H%M%S").log"
# exclude '01_VM' im ersten Lauf wg. sudo   
# ### dry-run:
#rsync "${paramRsync}" -aPhEv --delete --force --exclude={'01_VM','lost+found','.Trash*'} "${source}/" "${dest}/" | tee "/tmp/${logname}"   
rsync -aPhEv --delete --force --exclude={'01_VM','lost+found','.Trash*'} "${source}/" "${dest}/" | tee "/tmp/${logname}"

# ### VM (sudo)
echo "Starte rsync von '${source}/01_VM/' nach '${dest}/01_VM/'"
read -rp "Start mit beliebiger Eingabe"
logname="rsync_mirror-extHd_para_src-dest_VM_$(date +"%Y-%m-%d_%H%M%S").log"
#sudo rsync "${paramRsync}" -aPhEv --delete --force "${source}/01_VM/" "${dest}/01_VM/" | tee "/tmp/${logname}"
sudo rsync -aPhEv --delete --force "${source}/01_VM/" "${dest}/01_VM/" | tee "/tmp/${logname}"
echo " ======================================== "
