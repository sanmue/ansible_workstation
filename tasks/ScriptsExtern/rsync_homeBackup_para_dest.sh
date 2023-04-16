#!/usr/bin/env bash

#set -x

# ### rsync - zusätzliche Parameter:
#paramRsync='--dry-run'
#paramRsync=''

# ### Variablen - für backup home Verzeichnis aktueller User
source=${HOME}
#sourceInclude="--include={'.ssh/***','.bashrc','.zshrc'}"
#sourceExclude="--exclude={'snap','Pictures/Screenshots/*','Downloads','.*','./*'}"
#sourceConfigInclude="--include={'starship.toml','autokey/***','ulauncher/***'}"
#sourceConfigExclude="--exclude='*'"

if [ $# -gt 0 ]; then   # wenn (mehr als 0) Übergabeparameter vorhanden
	dest=$1             # erster Parameter: Pfad Sicherungsziel
	dest=${dest%/}      # '/' am Ende entfernen, wenn vorhanden
else
	echo "Parameter 1 für Ziel-Pfad wurde nicht übergeben, Ende."
	exit 1
	#dest='/run/media/sandro/WDGold8TB-crypt/Home'
fi

# Prüfung Zielpfad:
if [ -e "${dest}" ]; then             # Prüfung, ob Sicherungsziel existiert
	echo "Zielpfad ist: ${dest}"
else
	echo "Parameter 1: Zielpfad '${dest}' existiert nicht, Ende."
	exit 1
fi


# ### ###############################
# ### Sicherung $home und $home/.config

read -rp "Start mit beliebiger Eingabe"

# 1: Sicherung $source
echo -e "\n========================================"
echo "Starte backup von '${source}/' nach '${dest}/'"
logname="backupHome_$(date +"%Y-%m-%d_%H%M%S").log"
#rsync -aPhEv "${paramRsync}" "${sourceInclude}" "${sourceExclude} "${source}/" "${dest}/" | tee "/tmp/${logname}"
rsync -aPhEv --include={'.ssh/***','.bashrc','.zshrc'} --exclude={'Downloads','pCloud-Mnt/*','Pictures/Screenshots/*','snap','.*','./*'} "${source}/" "${dest}/" | tee "/tmp/${logname}"
echo '========================================'

# 2: Sicherung $source/.config
echo -e "\n========================================"
echo "Starte backup von '${source}/.config/' nach '${dest}/.config/'"
#rsync -aPhEv "${paramRsync}" "${sourceConfigInclude}" "${sourceConfigExclude}" "${source}/.config/" "${dest}/.config/" | tee -a "/tmp/${logname}"
rsync -aPhEv --include={'starship.toml','autokey/***','autostart/***','borg/***','rclone/***','remmina/***','ulauncher/***'} --exclude='*' "${source}/.config/" "${dest}/.config/" | tee -a "/tmp/${logname}"
echo '========================================'
