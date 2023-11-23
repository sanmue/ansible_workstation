#!/usr/bin/env bash

#set -x

# ### Skript zur Sicherung/Updata AppConfData (intern, -> in zentrales RescueSystem-Verzeichnis, doppel)
#
# ### wird auch nach '/usr/local/bin/'' kopiert und von systemd/Timer / service (user) aufgerufen
# ### - 'AppConfData_rsync.timer' / 'AppConfData_rsync.service'
#
# 1. Config etc von Apps (z.B. unter .config, .var, .local im Home-Verzeichnis):
# 	- Quellpfade1: ausgewählte Dateien/Verzeichnisse in ${arrConfPath} (befinden sich unter ${HOME})
# 	- Zielpfad1: arrConfAppDataBakPath (hier: nur $confAppData2ndBakPath)
#
# 2. Config / Backups / Daten von Apps im Sync-Verzeichnis (main) nach RescueSystem (zentral)
# 	- Quellpfad2: $syncAppConfDataPath
# 	- Zielpfad2: $rescueAppConfDataPath
#
# 3. Sicherung/Update "ScriptsExtern" (aus ansible workstation)
# 	- Quellpfad3: $scriptsExternPath (="${scriptsExternFolderpath}/${scriptsExternFoldername}")
# 	- Zielpfad3: ${rescueAppConfDataPath}/${scriptsExternFoldername}


# ### rsync - zusätzliche Parameter:
paramRsync='--stats'
#paramRsync+='--dry-run'


# ### ######################################################
# ### Variablen - für backup home Verzeichnis aktueller User
source=${HOME}
echo "Homepfad ist: ${source}"

# ### Zielpfade + Liste zu sichernde Daten aus $HOME und Unterverz. '.config', '.local', '.var' für confAppData/01_bak-ScriptService
confAppData2ndBakPath="${source}/RescueSystem/AppConfData/01_bak-ScriptService"
if [ -e "${confAppData2ndBakPath}" ]; then
	echo "Zweiter Backup-Path für confAppData ist: ${confAppData2ndBakPath}"
else
	echo "Zweiter Backup-Path für confAppData '${confAppData2ndBakPath}' existiert nicht, Ende."
	exit 1
fi
arrConfAppDataBakPath=("${confAppData2ndBakPath}")

# ### Liste zu sichernde Daten aus $HOME und Unterverz. '.config', '.local', '.var'
#	Anmerkungen:
# 	- nemo nimmt bookmarks aus:				.config/gtk-3.0/bookmarks 	(Gnome, Stand 05/2023)
# 	- 'places'-bookmarks' for filebrowser: 	.config/user-dirs.dirs		(Gnome, Stand 05/2023)
#   - Vorta
#     - '.var/app/com.borgbase.Vorta'       -> wenn flatpak install
#     - '.local/share/Vorta'                -> wenn AUR install
#   - Joplin
#     - '.var/app/net.cozic.joplin_desktop' -> wenn flatpak install
#     - '.config/joplin-desktop'            -> wenn AUR install
arrConfPath=('.bashrc' '.ssh' '.zshrc' \
'.config/autokey' '.config/autostart' '.config/borg' '.config/BraveSoftware/Brave-Browser/Default/Bookmarks' \
'.config/chromium/Default/Bookmarks' '.config/Cryptomator' '.config/evolution' '.config/gtk-3.0/bookmarks' \
'.config/joplin-desktop' '.config/keepassxc' '.config/rclone' '.config/remmina' \
'.config/starship.toml' '.config/syncthing' '.config/ulauncher' '.config/user-dirs.dirs' \
'.local/bin/rclone_pCloud-Mnt.sh' '.local/share/evolution' '.local/share/keyrings' \
'.local/share/remmina' '.local/share/Vorta' \
'.var/app/de.haeckerfelix.Shortwave/data' '.var/app/net.ankiweb.Anki/data' \
'.var/app/net.cozic.joplin_desktop' '.var/app/com.borgbase.Vorta')


# ### Pfade für Update (intern) von $source/Sync/Default/AppConfData nach $source/RescueSystem/AppConfData
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

# ### Pfade für Update (intern) von dev/Ansible...ScriptsExtern nach $rescueAppConfDataPath/$scriptsExternFoldername
scriptsExternFoldername="ScriptsExtern"
scriptsExternFolderpath="${source}/dev/Projects/Ansible/ansible_workstation/tasks"
scriptsExternPath="${scriptsExternFolderpath}/${scriptsExternFoldername}"
if [ -e "${scriptsExternPath}" ]; then
	echo "Quelle scriptsExternPath ist: ${scriptsExternPath}"
else
	echo "Quelle scriptsExternPath '${scriptsExternPath}' existiert nicht, Ende."
	exit 1
fi


# ### ################################################################
# ### Sicherung/Update AppDataConf
# ### - verkürzte + angepasste Version von 'rsync_home-backup_dest.sh'

# read -rp "Start nach Drücken der Eingabe-Taste"

logname="rsync_appConfData-intern_$(date +"%Y-%m-%d_%H%M%S").log"

# ### 1: Update (intern) von: ${source}, .config, .local und .var nach RescueSystem/.../01_bak-ScriptService:
echo -e "\n========================================"
echo "*** Starte Update/Backup ausgwählter Teile von '${source}, .config, .local und .var' nach '${arrConfAppDataBakPath[*]}'"
for bakPath in "${arrConfAppDataBakPath[@]}"; do
	for confPath in "${arrConfPath[@]}"; do   # $confPath kann Pfad zu Verzeichnis oder Datei sein
		if [ -e "${source}/${confPath}" ]; then
			if [ -d "${source}/${confPath}" ]; then		# wenn Verzeichnis
				echo -e "\033[0;32m\n+ rsync von '${source}/${confPath}/' nach '${bakPath}/${confPath}/'\033[0m"
				rsync -aPhEv --mkpath "${paramRsync}" "${source}/${confPath}/" "${bakPath}/${confPath}/" | tee -a "/tmp/${logname}"
			fi

			if [ -f "${source}/${confPath}" ]; then		# wenn Datei
				echo -e "\033[0;32m\n+ rsync von '${source}/${confPath}' nach '${bakPath}/${confPath}'\033[0m"
				rsync -aPhEv --mkpath "${paramRsync}" "${source}/${confPath}" "${bakPath}/${confPath}" | tee -a "/tmp/${logname}"
			fi		
		else
			echo -e "\033[0;31m\n- Quelle '${source}/${confPath}' nicht vorhanden, überspringe...\033[0m" >> "/tmp/${logname}"
		fi
	done
done
echo '========================================'

# ### 2: Update (intern) von $source/Sync/Default/AppConfData nach $source/RescueSystem/AppConfData
echo -e "\n========================================"
echo "*** Starte Update von '${syncAppConfDataPath}/' nach '${rescueAppConfDataPath}/'"
rsync -aPhEv "${paramRsync}" "${syncAppConfDataPath}/" "${rescueAppConfDataPath}/" | tee -a "/tmp/${logname}"
echo '========================================'

# ### 3. Update (MIRROR) (intern) von dev/Ansible...ScriptsExtern nach $rescueAppConfDataPath/$scriptsExternFoldername
echo -e "\n========================================"
echo "*** Starte Update (MIRROR) von '${scriptsExternPath}/' nach '${rescueAppConfDataPath}/${scriptsExternFoldername}/'"
rsync -aPhEv --delete "${paramRsync}" "${scriptsExternPath}/" "${rescueAppConfDataPath}/${scriptsExternFoldername}/" | tee -a "/tmp/${logname}"
echo '========================================'
