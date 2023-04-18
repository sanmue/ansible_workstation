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
	#dest='/run/media/sandro/WDGold8TB-crypt/home'
fi

# Prüfung Zielpfad:
if [ -e "${dest}" ]; then
	echo "Zielpfad ist: ${dest}"
else
	echo "Parameter 1: Zielpfad '${dest}' existiert nicht, Ende."
	exit 1
fi

# Prüfung Video-min Verzeichnis:
# - Quelle:
videosMinSrc="/home/01_Videos-min"
videosMinDanceDest="${videosMinSrc}/v2b-min/001_Dance"   			# ist Kopier-Zielverzeichnis (auf Quelle) für $videosMinSyncDanceSrc (Quelle); -> ja, Dateien dann doppelt auf Quell-Rechner
videosMinSyncDanceSrc="${source}/Sync/Default/Videos/v2b/001_Dance"

if [ -e "${videosMinDanceDest}" ]; then
	echo "Ziel videosMinDanceDest ist: ${videosMinDanceDest}"
else
	echo "Ziel videosMinDanceDest '${videosMinDanceDest}' existiert nicht, Ende."
	exit 1
fi
if [ -e "${videosMinSyncDanceSrc}" ]; then
	echo "Quelle videosMinSyncDanceSrc ist: ${videosMinSyncDanceSrc}"
else
	echo "Quelle videosMinSyncDanceSrc '${videosMinSyncDanceSrc}' existiert nicht, Ende."
	exit 1
fi

# - Ziel:
videosMinDest=$(dirname "${dest}")				# /run/media/user/extHD/home -> /run/media/user/extHD
videosMinDest="${videosMinDest}/01_Videos-min"	# -> /run/media/user/extHD/01_Videos-min
if [ -e "${videosMinDest}" ]; then
	echo "Ziel videosMinDest ist: ${videosMinDest}"
else
	echo "Ziel videosMinDest '${videosMinDest}' existiert nicht, Ende."
	exit 1
fi


# ### ##############################################
# ### Sicherung $home, $home/.config, Sync 001_Dance

read -rp "Start mit beliebiger Eingabe"

# 1: Sicherung $source
echo -e "\n========================================"
echo "Starte backup von '${source}/' nach '${dest}/'"
logname="rsync_homeBackup_para_dest_$(date +"%Y-%m-%d_%H%M%S").log"
#rsync -aPhEv "${paramRsync}" "${sourceInclude}" "${sourceExclude} "${source}/" "${dest}/" | tee "/tmp/${logname}"
#rsync -aPhEv "${paramRsync}" --include={'.ssh/***','.bashrc','.zshrc'} --exclude={'Downloads','pCloud-Mnt/*','Pictures/Screenshots/*','snap','.*','./*'} "${source}/" "${dest}/" | tee "/tmp/${logname}"
rsync -aPhEv --include={'.ssh/***','.bashrc','.zshrc'} --exclude={'Downloads','pCloud-Mnt/*','Pictures/Screenshots/*','snap','.*','./*'} "${source}/" "${dest}/" | tee "/tmp/${logname}"
echo '========================================'

# 2: Sicherung $source/.config
echo -e "\n========================================"
echo "Starte backup von '${source}/.config/' nach '${dest}/.config/'"
#rsync -aPhEv "${paramRsync}" "${sourceConfigInclude}" "${sourceConfigExclude}" "${source}/.config/" "${dest}/.config/" | tee -a "/tmp/${logname}"
#rsync -aPhEv "${paramRsync}" --include={'starship.toml','autokey/***','autostart/***','borg/***','rclone/***','remmina/***','syncthing/***','ulauncher/***'} --exclude='*' "${source}/.config/" "${dest}/.config/" | tee -a "/tmp/${logname}"
rsync -aPhEv --include={'starship.toml','autokey/***','autostart/***','borg/***','rclone/***','remmina/***','syncthing/***','ulauncher/***'} --exclude='*' "${source}/.config/" "${dest}/.config/" | tee -a "/tmp/${logname}"
echo '========================================'

# 3: Kopiere '$videosMinSyncDanceSrc' (Quelle) ins '$videosMinDanceDest' Verzeichnis (ebenfalls Quelle)
# - ja, Dateien existieren dann doppelt auf Quelle
echo -e "\n========================================"
echo "Starte backup von '${videosMinSyncDanceSrc}/' nach '${videosMinDanceDest}/'"
#rsync -aPhEv "${paramRsync}" "${videosMinSyncDanceSrc}" "${videosMinDanceDest}/" | tee -a "/tmp/${logname}"
rsync -aPhEv "${videosMinSyncDanceSrc}/" "${videosMinDanceDest}/" | tee -a "/tmp/${logname}"
echo '========================================'

# 4: Sicherung '$videosMinSrc' (Quelle, gesamt inkl. Dance)
echo -e "\n========================================"
echo "Starte backup von '${videosMinSrc}' nach '${videosMinDest}'"
#rsync -aPhEv "${paramRsync}" "${videosMinSrc}/" "${videosMinDest}/" | tee -a "/tmp/${logname}"
rsync -aPhEv "${videosMinSrc}/" "${videosMinDest}/" | tee -a "/tmp/${logname}"
echo '========================================'
