#!/usr/bin/env bash

#set -x

# ### Skript zur Sicherung Home-Verzeichnis aktueller User inkl. vorausgewählte .config-Dateien
# ### und "01_Videos-min"
#     - 1.) rsync von "Sync" (Dance) nach "01_Videos-min" (Dance)
#     - 2.) rsync "01_Videos-min" Quelle nach "01_Videos-min" Ziel
#
# ### einfache Archivierung rsync Quelle-Ziel (mit include/exclude)
# - Quellpfad: Home-Verzeichnis aktueller User (aus $HOME)
# - Parameter 1: Zielpfad


# ### rsync - zusätzliche Parameter:
paramRsync='--dry-run'

# ### Variablen - für backup home Verzeichnis aktueller User
source=${HOME}
echo "Quellpfad (Home) ist: ${source}"

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

# Zielpfade + Liste zu sichernde Daten aus $HOME und Unterverz. '.config', '.local', '.var' für confAppData/01_bak-ScriptService
confAppData2ndBakPath="${source}/RescueSystem/AppConfData/01_bak-ScriptService"
if [ -e "${confAppData2ndBakPath}" ]; then
	echo "Zweiter Backup-Path für confAppData ist: ${confAppData2ndBakPath}"
else
	echo "Zweiter Backup-Path für confAppData '${confAppData2ndBakPath}' existiert nicht, Ende."
	exit 1
fi
arrConfAppDataBakPath=("${confAppData2ndBakPath}" "${dest}")

# - Liste zu sichernde Daten aus $HOME und Unterverz. '.config', '.local', '.var'
# 	- nemo bookmarks: 								.config/gtk-3.0/bookmarks
# 	- gnome 'places-bookmarks' for filebrowser: 	.config/user-dirs.dirs
arrConfPath=('.bashrc' '.ssh' '.zshrc' \
'.config/autokey' '.config/autostart' '.config/borg' '.config/BraveSoftware/Brave-Browser/Default/Bookmarks' \
'.config/chromium/Default/Bookmarks' '.config/Cryptomator' '.config/evolution' '.config/gtk-3.0/bookmarks' '.config/rclone' \
'.config/remmina' '.config/starship.toml' '.config/syncthing' '.config/ulauncher' '.config/user-dirs.dirs' \
'.local/bin/rclone_pCloud-Mnt.sh' '.local/share/evolution' '.local/share/remmina' '.local/share/Vorta' \
'.var/app/net.ankiweb.Anki/data')

# Pfade für Update (intern) von $source/Sync/Default/AppConfData nach $source/RescueSystem/AppConfData
syncAppConfDataPath="${source}/Sync/Default/AppConfData"
rescueAppConfDataPath="${source}/RescueSystem/AppConfData"
if [ -e "${syncAppConfDataPath}" ]; then
	echo "Quelle syncAppConfDataPath ist: ${syncAppConfDataPath}"
else
	echo "Quelle syncAppConfDataPath '${syncAppConfDataPath}' existiert nicht, Ende."
	exit 1
fi
if [ -e "${rescueAppConfDataPath}" ]; then
	echo "Ziel rescueAppConfDataPath ist: ${rescueAppConfDataPath}"
else
	echo "Ziel rescueAppConfDataPath '${rescueAppConfDataPath}' existiert nicht, Ende."
	exit 1
fi

# Pfade für Update (intern) von dev/Ansible...ScriptsExtern nach $rescueAppConfDataPath/$scriptsExternFoldername
scriptsExternFoldername="ScriptsExtern"
scriptsExternFolderpath="${source}/dev/Ansible/ansible_workstation/tasks"
scriptsExternPath="${scriptsExternFolderpath}/${scriptsExternFoldername}"
if [ -e "${scriptsExternPath}" ]; then
	echo "Quelle scriptsExternPath ist: ${scriptsExternPath}"
else
	echo "Quelle scriptsExternPath '${scriptsExternPath}' existiert nicht, Ende."
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
# ### Sicherung $home, $home/.config, ..., Sync 001_Dance

read -rp "Start nach Drücken der Eingabe-Taste"

logname="rsync_homeBackup_para_dest_$(date +"%Y-%m-%d_%H%M%S").log"

# 1: Update (intern) und Sicherung (extern $dest) von: ${source}, .config, .local und .var:
echo -e "\n========================================"
echo "Starte Update/Backup ausgwählter Teile von '${source}, .config, .local und .var' nach '${dest}' und lokal in 'RescueSystem/...'"
for bakPath in "${arrConfAppDataBakPath[@]}"; do
	for confPath in "${arrConfPath[@]}"; do   # $confPath kann Pfad zu Verzeichnis oder Datei sein
		if [ -e "${source}/${confPath}" ]; then
			if [ -d "${source}/${confPath}" ]; then		# wenn Verzeichnis
				echo -e "\033[0;32m\n+ rsync von '${source}/${confPath}/' nach '${bakPath}/${confPath}/'\033[0m"
				#rsync -aPhEv --mkpath "${paramRsync}" "${source}/${confPath}/" "${bakPath}/${confPath}/" | tee -a "/tmp/${logname}"
				rsync -aPhEv --mkpath  "${source}/${confPath}/" "${bakPath}/${confPath}/" | tee -a "/tmp/${logname}"
			fi

			if [ -f "${source}/${confPath}" ]; then		# wenn Datei
				echo -e "\033[0;32m\n+ rsync von '${source}/${confPath}' nach '${bakPath}/${confPath}'\033[0m"
				#rsync -aPhEv --mkpath "${paramRsync}"  "${source}/${confPath}" "${bakPath}/${confPath}" | tee -a "/tmp/${logname}"
				rsync -aPhEv --mkpath  "${source}/${confPath}" "${bakPath}/${confPath}" | tee -a "/tmp/${logname}"
			fi		
		else
			echo -e "\033[0;31m\n- Quelle '${source}/${confPath}' nicht vorhanden, überspringe...\033[0m" >> "/tmp/${logname}"
		fi
	done
done
echo '========================================'

# 2: Update (intern) von $source/Sync/Default/AppConfData nach $source/RescueSystem/AppConfData
echo -e "\n========================================"
echo "Starte Update von 'Sync/Default/AppConfData' nach 'RescueSystem/AppConfData'"
#rsync -aPhEv "${paramRsync}" "${syncAppConfDataPath}/" "${rescueAppConfDataPath}/" | tee -a "/tmp/${logname}"
rsync -aPhEv "${syncAppConfDataPath}/" "${rescueAppConfDataPath}/" | tee -a "/tmp/${logname}"
echo '========================================'

# 3. Update (intern) von dev/Ansible...ScriptsExtern nach $rescueAppConfDataPath/$scriptsExternFoldername
echo "Starte Update von '${scriptsExternPath}/ nach '${rescueAppConfDataPath}/${scriptsExternFoldername}/'"
#rsync -aPhEv "${paramRsync}" "${scriptsExternPath}/" "${rescueAppConfDataPath}/${scriptsExternFoldername}" | tee -a "/tmp/${logname}"
rsync -aPhEv "${scriptsExternPath}/" "${rescueAppConfDataPath}/${scriptsExternFoldername}/" | tee -a "/tmp/${logname}"
echo '========================================'

# 4: Sicherung $source
echo -e "\n========================================"
echo "Starte Backup ausgwählter Teile von '${source}/' nach '${dest}/'"
#rsync -aPhEv "${paramRsync}" "${sourceInclude}" "${sourceExclude} "${source}/" "${dest}/" | tee -a "/tmp/${logname}"
#rsync -aPhEv "${paramRsync}" --include={'.ssh/***','.bashrc','.zshrc'} --exclude={'Downloads','pCloud-Mnt/*','Pictures/Screenshots/*','snap','.*','./*'} "${source}/" "${dest}/" | tee -a "/tmp/${logname}"
rsync -aPhEv --include={'.ssh/***','.bashrc','.zshrc'} --exclude={'Downloads','pCloudDrive','pCloud-Mnt/*','Pictures/Screenshots/*','snap','.*','./*'} "${source}/" "${dest}/" | tee -a "/tmp/${logname}"
echo '========================================'

# 5: Kopiere '$videosMinSyncDanceSrc' (Quelle) ins '$videosMinDanceDest' Verzeichnis (ebenfalls Quelle)
# - ja, Dateien existieren dann ggf. doppelt an der Quelle (wenn nicht vorher manuell bereinigt wurde)
echo -e "\n========================================"
echo "Starte Backup von '${videosMinSyncDanceSrc}/' nach '${videosMinDanceDest}/'"
#rsync -aPhEv "${paramRsync}" "${videosMinSyncDanceSrc}" "${videosMinDanceDest}/" | tee -a "/tmp/${logname}"
rsync -aPhEv "${videosMinSyncDanceSrc}/" "${videosMinDanceDest}/" | tee -a "/tmp/${logname}"
echo '========================================'

# 6: Sicherung '$videosMinSrc' (Quelle, gesamt inkl. Dance)
echo -e "\n========================================"
echo "Starte Backup von '${videosMinSrc}' nach '${videosMinDest}'"
#rsync -aPhEv "${paramRsync}" "${videosMinSrc}/" "${videosMinDest}/" | tee -a "/tmp/${logname}"
rsync -aPhEv "${videosMinSrc}/" "${videosMinDest}/" | tee -a "/tmp/${logname}"
echo '========================================'
