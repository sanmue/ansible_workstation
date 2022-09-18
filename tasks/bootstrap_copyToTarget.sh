#!/bin/bash

# Kopieren des bootstrap-skripts auf die Zielmaschine

# region Initialisation
userid=$(whoami)
read -rp "IP des Zielrechners eingeben: " targetIP
#targetIP="192.168.122.237"

# region main
echo "Kopiere bootstrap-Skript ins Home-Verzeichnis von '${userid}' auf Zielrechner '${targetIP}' ..."
#rsync -avPEzh --stats "bootstrap_ubuntu.sh" "${userid}@${targetIP}:~"
rsync -avPEzh --stats --exclude={"bootstrap_copyToTarget.sh","config_workstation-desktopPreferences-terminal.sh","*.yml*"} --include="*.sh" "./" "${userid}@${targetIP}:~"

#rsync -avPEzh --stats --include="*.sh" --exclude={"bootstrap_copyToTarget.sh","config_workstation-desktopPreferences-terminal.sh","*.yml*"} "./" "${userid}@${targetIP}:~"   # kopiert nicht nur alls .sh außer den excludeten, sondern auch die exclludeten mit (warum?):
# https://unix.stackexchange.com/questions/307862/rsync-include-only-certain-files-types-excluding-some-directories

echo ""
echo "Kopiervorgang beendet beendet."
