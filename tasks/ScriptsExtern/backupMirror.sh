#!/usr/bin/env bash

#set -x

# ### rsync - zusätzliche Parameter:
#paramRsync='--dry-run'
#paramRsync=''

if [ $# -gt 1 ]; then   # wenn (mehr als 0) Übergabeparameter vorhanden
	source=$2
	source=${dest%/}
	dest=$2
	dest=${dest%/}
else
	echo "Keine 2 Parameter (Quelle, Ziel), Ende."
	exit 1
fi

# Prüfung Quell:
if [ -e "${source}" ]; then             # Prüfung, ob Sicherungsziel existiert
	echo "Quellpfad ist: ${dest}"
else
	echo "Parameter 1: Quellpfad '${source}' existiert nicht, Ende."
	exit 1
fi
# Prüfung Zielpfad:
if [ -e "${dest}" ]; then             # Prüfung, ob Sicherungsziel existiert
	echo "Zielpfad ist: ${dest}"
else
	echo "Parameter 2: Zielpfad '${dest}' existiert nicht, Ende."
	exit 1
fi


# ### ###############################
# ### Sicherung (Mirror)
echo -e "\n========================================"
echo "Starte backup von '${source}' nach '${dest}' - MIRROR"
logname="backupMirror_$(date +"%Y-%m-%d_%H%M%S").log"
rsync --dry-run -aPhEv --delete --force --exclude={'lost+found','.Trash*'} "${source}/" "${dest}/" | tee "/tmp/${logname}"
#rsync -aPhEv --delete --force --exclude={'lost+found','.Trash*'} "${source}/" "${dest}/" | tee "/tmp/${logname}"
echo '========================================'
