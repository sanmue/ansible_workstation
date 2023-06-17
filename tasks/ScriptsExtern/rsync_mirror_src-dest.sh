#!/usr/bin/env bash

#set -x

# ### rsync - zusätzliche Parameter:
#paramRsync='--dry-run'
paramRsync='--stats'

if [ $# -gt 1 ]; then   # wenn (mehr als 1) Übergabeparameter vorhanden
	source=$1
	source=${source%/}
	dest=$2
	dest=${dest%/}
else
	echo "Keine 2 Parameter (Quelle, Ziel), Ende."
	exit 1
fi

# Prüfung Quelle:
if [ -e "${source}" ]; then			# Prüfung, ob Quelle existiert
	echo "Quellpfad ist: ${source}"
else
	echo "Parameter 1: Quellpfad '${source}' existiert nicht, Ende."
	exit 1
fi
# Prüfung Zielpfad:
if [ -e "${dest}" ]; then			# Prüfung, ob Sicherungsziel existiert
	echo "Zielpfad ist: ${dest}"
else
	echo "Parameter 2: Zielpfad '${dest}' existiert nicht, Ende."
	exit 1
fi


# ### ##############
# ### rsync (Mirror)

read -rp "Start MIRROR mit beliebiger Eingabe"

logname="rsync_mirror_src-dest_$(date +"%Y-%m-%d_%H%M%S").log" 

echo -e "\n========================================"
echo "*** Starte rsync von '${source}/' nach '${dest}/' - MIRROR"
rsync -aPhEv --delete --force "${paramRsync}" "${source}/" "${dest}/" | tee "/tmp/${logname}"
echo "========================================"
