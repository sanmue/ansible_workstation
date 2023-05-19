#!/usr/bin/env bash

#set -x

# ### Skript zur Sicherung/Update von $rescueAppConfDataPath nach extern ($dest = Übergabe-Parameter)
# zuvor am besten noch Skript 'rsync_appConfData-intern.sh' ausführen
#
# - Quellpfad: $rescueAppConfDataPath
# - Zielpfad: $dest (Übergabe-Parameter)

# ### rsync - zusätzliche Parameter:
paramRsync='--dry-run'

# ### Variablen - für backup home Verzeichnis aktueller User
source=${HOME}
echo "Quellpfad (Home) ist: ${source}"

# Quell-Pfade für Backup von $source/RescueSystem/AppConfData
rescueAppConfDataPath="${source}/RescueSystem/AppConfData"
if [ -e "${rescueAppConfDataPath}" ]; then
	echo "Quelle rescueAppConfDataPath ist: ${rescueAppConfDataPath}"
else
	echo "Quelle rescueAppConfDataPath '${rescueAppConfDataPath}' existiert nicht, Ende."
	exit 1
fi

# Parameter (Zielpfad):
if [ $# -gt 0 ]; then   # wenn (mehr als 0) Übergabeparameter vorhanden
	dest=$1             # erster Parameter: Pfad Sicherungsziel
	dest=${dest%/}      # '/' am Ende entfernen, wenn vorhanden
else
	echo "Parameter 1 für Ziel-Pfad wurde nicht übergeben, Ende."
	exit 1
	#dest='/run/media/sandro/WDGold8TB-crypt/home'
fi

# - Prüfung Zielpfad:
if [ -e "${dest}" ]; then
	echo "Zielpfad ist: ${dest}"
else
	echo "Parameter 1: Zielpfad '${dest}' existiert nicht, Ende."
	exit 1
fi


# ### Backup
read -rp "Start nach Drücken der Eingabe-Taste"

logname="rsync_appConfData-extern_dest.sh_$(date +"%Y-%m-%d_%H%M%S").log"

echo -e "\n========================================"
echo "Starte Update von '${rescueAppConfDataPath}/' nach '${dest}/'"
#rsync -aPhEv "${paramRsync}" "${rescueAppConfDataPath}/" "${dest}/" | tee -a "/tmp/${logname}"
rsync -aPhEv "${rescueAppConfDataPath}/" "${dest}/" | tee -a "/tmp/${logname}"
echo '========================================'
