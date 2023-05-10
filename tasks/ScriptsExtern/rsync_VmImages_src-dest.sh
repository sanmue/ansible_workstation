#!/usr/bin/env bash

#set -x

# ### Skript rsync der VM-Images
# ### einfache Archivierung rsync Quelle-Ziel
# - Parameter1: Quell-Pfad
# - Parameter2: Zielpfad


# ### rsync - zusätzliche Parameter:
paramRsync='--dry-run'

if [ $# -gt 1 ]; then   # wenn (mehr als 1) Übergabeparameter vorhanden
	source=$1
	source=${source%/}
	dest=$2
	dest=${dest%/}
else
	echo "Keine 2 Parameter (Quelle, Ziel), Ende."
	exit 1
fi

# Prüfung Quell:
if [ -e "${source}" ]; then				# Prüfung, ob Sicherungsziel existiert
	echo "Quellpfad ist: ${source}"
else
	echo "Parameter 1: Quellpfad '${source}' existiert nicht, Ende."
	exit 1
fi
# Prüfung Zielpfad:
if [ -e "${dest}" ]; then				# Prüfung, ob Sicherungsziel existiert
	echo "Zielpfad ist: ${dest}"
else
	echo "Parameter 2: Zielpfad '${dest}' existiert nicht, Ende."
	exit 1
	#dest="/var/lib/libvirt/images"
	#echo "Standard-Zielpfad wird verwendet: '${dest}'"
fi


# ### ###############
# ### rsync VM Images

read -rp "Start mit beliebiger Eingabe"

# ### VM
echo -e "\n ======================================== "
echo "Starte rsync (sudo) von '${source}' nach '${dest}'"
logname="rsync_VmImages_para_src-dest_$(date +"%Y-%m-%d_%H%M%S").log"
#sudo rsync "${paramRsync}" -aPhEv "${source}/" "${dest}/" | tee "/tmp/${logname}"
sudo rsync -aPhEv "${source}/" "${dest}/" | tee "/tmp/${logname}"
echo " ======================================== "
