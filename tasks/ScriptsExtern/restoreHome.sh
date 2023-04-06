#!/usr/bin/env bash

#set -x

# ### rsync - zusätzliche Parameter:
paramRsync='--dry-run'
#paramRsync=''

# ### Variablen / Prüfung:
dest=${HOME}

if [ $# -gt 0 ]; then   # wenn (mehr als 0) Übergabeparameter vorhanden
	source=$1			# erster Parameter: Quellpfad
	source=${source%/}	# '/' am Ende entfernen, wenn vorhanden
else
	echo "Parameter 1 für Quellpfad wurde nicht übergeben, Ende."
	exit 1
	#source='/run/media/sandro/Seagate8TB-crypt'
fi

# Prüfung Quellpfad:
if [ -e "${source}" ]; then				# Prüfung, ob Quellpfad existiert
	echo "Quellpfad ist: ${source}"
else
	echo "Parameter 1: Quellpfad '${source}' existiert nicht, Ende."
	exit 1
fi


# ### ##########################
# ### Restore home aus Sicherung

read -rp "Start mit beliebiger Eingabe"

echo -e "\n ======================================== "
echo "Starte restore von '${source}' nach '${dest}'"
logname="restoreHome_$(date +"%Y-%m-%d_%H%M%S").log"
#rsync -aPhEv "${paramRsync}" "${source}/" "${dest}/" | tee "/tmp/${logname}"   # ### dry-run
rsync -aPhEv "${source}/" "${dest}/" | tee "/tmp/${logname}"
echo ' ======================================== '
