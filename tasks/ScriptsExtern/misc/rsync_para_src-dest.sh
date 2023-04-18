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


# ### #####
# ### rsync

read -rp "Start mit beliebiger Eingabe"

echo "Starte rsync (sudo) von '${source}/' nach '${dest}/'"
logname="rsync_sudo_para_src-dest_$(date +"%Y-%m-%d_%H%M%S").log"
#rsync "${paramRsync}" -aPhEv "${source}/" "${dest}/" | tee "/tmp/${logname}"   # ### dry-run
rsync -aPhEv "${source}/" "${dest}/" | tee "/tmp/${logname}"
echo " ======================================== "
