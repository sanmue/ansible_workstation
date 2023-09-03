#!/usr/bin/env bash

#set -x

# TEST

# ### Skript zur Sicherung $arrBak nach extern ($dest = Übergabe-Parameter)
# WIRD NICHT MEHR BENÖTIGT, siehe neu: rsync_appConfData-extern_dest.sh (bwz. zuvor rsync_appConfData-intern.sh)

# ### rsync - zusätzliche Parameter:
paramRsync='--dry-run'

# ### Variablen
source=${HOME}
echo "Zu sicherndes Home-Verzeichnis: ${source}"

if [ $# -gt 0 ]; then   # wenn (mehr als 0) Übergabeparameter vorhanden
	dest=$1             # erster Parameter: Pfad Sicherungsziel
	dest=${dest%/}      # '/' am Ende entfernen, wenn vorhanden
else
	echo "Parameter 1 für Ziel-Pfad wurde nicht übergeben, Ende."
	exit 1
fi

# Prüfung Zielpfad:
if [ -e "${dest}" ]; then
	echo "Zielpfad ist: ${dest}"
else
	echo "Parameter 1: Zielpfad '${dest}' existiert nicht, Ende."
	exit 1
fi

# Liste Sicherungspfade ausgehend von $source:
arrBak=("dev/Ansible/ansible_workstation/tasks/ScriptsExtern" "RescueSystem/AppConfData" "Sync/Default/AppConfData/Keepass" ".config/borg" ".config/Cryptomator" ".config/rclone" ".config/syncthing" ".local/share/Vorta" ".ssh")


# ### ###########################
# ### rsync Liste Sicherungspfade

#read -rp "Start mit beliebiger Eingabe"
logname="rsync_bak_para_dest_$(date +"%Y-%m-%d_%H%M%S").log"

for bakpath in "${arrBak[@]}"; do
	if [ -e "${source}/${bakpath}" ]; then
		echo -e "\033[0;32m\n+ rsync von '${source}/${bakpath}' nach '${dest}/'\033[0m"
		#rsync -aPhEv "${paramRsync}" --log-file="/tmp/${logname}" "${source}/${bakpath}" "${dest}/"
		rsync -aPhEv --log-file="/tmp/${logname}" "${source}/${bakpath}" "${dest}/"
	else
		echo -e "\033[0;31m\n- Quelle '${source}/${bakpath}' nicht vorhanden, überspringe...\033[0m" >> "/tmp/${logname}"
	fi
done
