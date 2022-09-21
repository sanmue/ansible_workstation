#!/bin/bash

# Kopieren des bootstrap-skripts auf die Zielmaschine
# es kann ein Parameter übergeben werden: IP-Adresse der Zielmaschine


# #####################
# region Initialisation
# #####################
if [ $# == 1 ]; then   # wenn Anzahl Argumente (die an Skript übergeben wurden) = 1 ist
    targetIP=$1
else
    read -rp "IP des Zielrechners eingeben: " targetIP
fi
#targetIP="192.168.122.211"

userid=$(whoami)
read -rp "Soll die aktuelle UserID '${userid}' auch auf dem Zielrechner verwendet werden (j/n)?: " aktUser
if [ "${aktUser}" = "n" ]; then
    read -rp "UserID auf Zielrechner angeben: " userid
else
    echo "Aktuelle UserID '${userid}' wird verwendet"
fi


# ###########
# region main
# ###########
echo ""
echo "Kopiere bootstrap-Skript ins Home-Verzeichnis von '${userid}' auf Zielrechner '${targetIP}' ..."
#rsync -avPEzh --stats "bootstrap_ubuntu.sh" "${userid}@${targetIP}:~"
rsync -avPEzh --stats --exclude={"bootstrap_copyToTarget.sh","config_workstation-desktopPreferences-terminal.sh","*.yml*"} --include="*.sh" "./" "${userid}@${targetIP}:~"

#rsync -avPEzh --stats --include="*.sh" --exclude={"bootstrap_copyToTarget.sh","config_workstation-desktopPreferences-terminal.sh","*.yml*"} "./" "${userid}@${targetIP}:~"   # kopiert nicht nur alls .sh außer den excludeten, sondern auch die exclludeten mit (warum?):
# https://unix.stackexchange.com/questions/307862/rsync-include-only-certain-files-types-excluding-some-directories

echo ""
echo "Kopiervorgang beendet beendet."
