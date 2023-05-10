#!/usr/bin/env bash

#set -x

# ### Skript zur Wiederherstellung Home-Verzeichnis aktueller User inkl. vorausgewählte .config-Dateien
# ### und "01_Videos-min"
#
# ### einfache Archivierung rsync Quelle-Ziel (mit include/exclude)
# - Zielpfad: Home-Verzeichnis aktueller User (aus $HOME)
# - Parameter 1: Quellpfad


# ### rsync - zusätzliche Parameter:
paramRsync='--dry-run'

# ### Variablen / Prüfung:
dest="${HOME}"
echo "Zielpfad ist: ${dest}"

if [ $# -gt 0 ]; then   # wenn (mehr als 0) Übergabeparameter vorhanden
	source=$1			# erster Parameter: Quellpfad
	source=${source%/}	# '/' am Ende entfernen, wenn vorhanden
else
	echo "Parameter 1 für Quellpfad wurde nicht übergeben, Ende."
	exit 1
	#source='/run/media/sandro/Seagate8TB-crypt/home'
fi

# Prüfung Quellpfad:
if [ -e "${source}" ]; then				# Prüfung, ob Quellpfad existiert
	echo "Quellpfad ist: ${source}"
else
	echo "Parameter 1: Quellpfad '${source}' existiert nicht, Ende."
	exit 1
fi

# Prüfung Video-min Verzeichnis:
# - Anmerkung: Zielverzeichnis '$videosMinDest' wurde bereits während ansible-Lauf erstellt
videosMinDest="/home/01_Videos-min"				# Ziel-Verzeichnis

videosMinSrc=$(dirname "${source}")   			# /run/media/user/extHD/home -> /run/media/user/extHD
videosMinSrc="${videosMinSrc}/01_Videos-min"	# -> /run/media/user/extHD/01_Videos-min

if [ -e "${videosMinDest}" ]; then             # Prüfung, ob Sicherungsziel existiert
	echo "Ziel videosMinDest ist: ${videosMinDest}"
else
	echo "Ziel videosMinDest '${videosMinDest}' existiert nicht, Ende."
	exit 1
fi
if [ -e "${videosMinSrc}" ]; then             # Prüfung, ob Sicherungsziel existiert
	echo "Quelle videosMinSrc ist: ${videosMinSrc}"
else
	echo "Quelle videosMinSrc '${videosMinSrc}' existiert nicht, Ende."
	exit 1
fi


# ### ##########################
# ### Restore home aus Sicherung

read -rp "Start mit beliebiger Eingabe"

echo -e "\n ======================================== "
echo "Starte restore von '${source}' nach '${dest}'"
logname="restoreHome_para_src_$(date +"%Y-%m-%d_%H%M%S").log"
#rsync -aPhEv "${paramRsync}" "${source}/" "${dest}/" | tee "/tmp/${logname}"   # ### dry-run
rsync -aPhEv "${source}/" "${dest}/" | tee "/tmp/${logname}"
echo ' ======================================== '

echo -e "\n ======================================== "
echo "Starte restore von '${videosMinSrc}' nach '${videosMinDest}'"
logname="restoreHome_para_src_$(date +"%Y-%m-%d_%H%M%S").log"
#rsync -aPhEv "${paramRsync}" "${videosMinSrc}/" "${videosMinDest}/" | tee "/tmp/${logname}"   # ### dry-run
rsync -aPhEv "${videosMinSrc}/" "${videosMinDest}/" | tee "/tmp/${logname}"
echo ' ======================================== '
