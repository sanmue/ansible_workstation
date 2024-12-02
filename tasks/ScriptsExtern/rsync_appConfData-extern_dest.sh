#!/usr/bin/env bash

#set -x

# ### Skript zur Sicherung/Update von $rescueAppConfDataFolder nach extern
# Parameter 1: $dest (Zielpfad)
#
# - Quellpfad: $rescueAppConfDataFolder (s.u.)

echo -e "\n\e[0;35mSicherung AppConfData\e[0m"
echo -e "\n\e[1;33mVariablen und Parameter (set + check)\e[0m"

# ### -----------------
# ### Variablen - Start
echo "Pfad home directory: '${HOME}'" # home directory
borgConfFolder="${HOME}/.config/borg" # borg conf directory
rescueAppConfDataFolder="${HOME}/RescueSystem/AppConfData" # AppConfData directory
# ### Variablen - Ende
# ### ----------------

# ### ---------------------------------
# ### Check paths and parameter - Start
# - Zielpfad (Parameter 1):
if [ $# -gt 0 ]; then   # wenn (mehr als 0) Übergabeparameter vorhanden
	dest="${1}"         # erster Parameter: Pfad Sicherungsziel
	dest=${dest%/}      # '/' am Ende entfernen, wenn vorhanden
else
	echo -e "\e[0;31mParameter 1 für Ziel-Pfad wurde nicht übergeben.\nSkript wird beendet.\e[0m"
	exit 1
	#dest='/run/media/sandro/WDGold8TB-crypt/home'
fi
if [ "$(ls "${dest}")" ]; then
	echo "Zielpfad ist: '${dest}'"
else
	echo -e "\e[0;31mParameter 1: Zielpfad '${dest}' existiert nicht.\nSkript wird beendet.\e[0m"
	exit 1
fi

# - borgConfFolder:
if [ "$(ls "${borgConfFolder}")" ]; then
	echo "borgConfFolder: '${borgConfFolder}'"
else
	echo -e "\e[0;31mborgConfFolder '${borgConfFolder}' existiert nicht, bitte prüfen.\nSkript wird beendet.\e[0m"
	exit 1
fi

# - rescueAppConfDataFolder:
if [ "$(ls "${rescueAppConfDataFolder}")" ]; then
	echo "rescueAppConfDataFolder (Quelle) ist: '${rescueAppConfDataFolder}'"
else
	echo -e "\e[0;31mrescueAppConfDataFolder (Quelle) '${rescueAppConfDataFolder}' existiert nicht, bitte prüfen.\nSkript wird beendet.\e[0m"
	exit 1
fi
# ### Check paths and parameter - Ende
# ### --------------------------------

# ### --------------
# ### Backup - Start
echo -e "\nStart des Backups erfolgt nach Drücken der Eingabe-Taste."
read -r

logfolder="/var/log"
logname="rsync_appConfData-extern_dest.sh_$(date +"%Y-%m-%d_%H%M%S").log"
logfile="${logfolder}/${logname}"

# rsyncOption='--dry-run'
rsyncOptionTxt="# ---------\n# ${rsyncOption}\n# ---------"

echo -e "\n\e[1;33mStarte rsync von '${borgConfFolder}' nach '${rescueAppConfDataFolder}'...\e[0m"
if [ -z "${rsyncOption}" ]; then # -z: True if the length of string is zero
	echo -e "# '${borgConfFolder}' nach '${rescueAppConfDataFolder}'\n" | sudo tee -a "${logfile}"
	rsync -aPhEv --stats --delete "${borgConfFolder}" "${rescueAppConfDataFolder}" | sudo tee -a "${logfile}"
else
	echo -e "${rsyncOptionTxt}\n# '${borgConfFolder}' nach '${rescueAppConfDataFolder}'\n" | sudo tee -a "${logfile}"
	rsync -aPhEv --stats --delete "${rsyncOption}" "${borgConfFolder}" "${rescueAppConfDataFolder}" | sudo tee -a "${logfile}"
fi

echo -e "\n\e[1;33mStarte rsync von '${rescueAppConfDataFolder}' nach '${dest}/'...\e[0m"
if [ -z "${rsyncOption}" ]; then # -z: True if the length of string is zero
	echo -e "\n# '${rescueAppConfDataFolder}' nach '${dest}'\n" | sudo tee -a "${logfile}"
	rsync -aPhEv --stats --delete "${rescueAppConfDataFolder}" "${dest}" | sudo tee -a "${logfile}"
else
	echo -e "\n${rsyncOptionTxt}\n# '${rescueAppConfDataFolder}' nach '${dest}'\n" | sudo tee -a "${logfile}"
	rsync -aPhEv --stats --delete "${rsyncOption}" "${rescueAppConfDataFolder}" "${dest}" | sudo tee -a "${logfile}"
	echo -e "${rsyncOptionTxt}" | sudo tee -a "${logfile}"
fi

echo -e "\n\e[1;33mÄndere Zugriffsrechte und Owner des logfile...\e[0m"
sudo chmod 660 "${logfile}"
sudo chown ":${USER}" "${logfile}"
ls -la "${logfile}"
# ### Backup - Ende
# ### -------------
