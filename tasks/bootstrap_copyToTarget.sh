#!/bin/bash

# -------------------------------------------------------------------
# Kopieren des bootstrap-skripts auf die Zielmaschine
# es kann ein Parameter übergeben werden: IP-Adresse der Zielmaschine
# -------------------------------------------------------------------

# #####################
# region Initialisation
# #####################

# IP-Adresse Ziel
if [ $# == 1 ]; then   # wenn Anzahl Argumente (die an Skript übergeben wurden) = 1 ist
    targetIP=$1
else
    read -rp "IP des Zielrechners eingeben: " targetIP
fi

# UserID
userid=$(whoami)
read -rp "Soll die aktuelle UserID '${userid}' auch auf dem Zielrechner verwendet werden (j/n)?: " useCurrentUserId
if [ "${useCurrentUserId}" = "n" ]; then
    read -rp "UserID auf Zielrechner angeben: " userid
else
    echo "Aktuelle UserID '${userid}' wird verwendet"
fi

# ssh keys
sshKeyFile="id_ed25519_loginTest.pub"
gitKeyFile="id_ed25519_githubTest.pub"


# ###########
# region main
# ###########

# Copy bootstrap-Skript to target
echo ""
echo "Kopiere bootstrap-Skript ins Home-Verzeichnis von '${userid}' auf Zielrechner '${targetIP}' ..."
#rsync -avPEzh --stats "bootstrap_ubuntu.sh" "${userid}@${targetIP}:~"
rsync -avPEzh --stats --exclude={"bootstrap_copyToTarget.sh","config_workstation-desktopPreferences-terminal.sh","config_all-servcices-misc-vim.sh","*.yml*"} --include="*.sh" "./" "${userid}@${targetIP}:~"
#rsync -avPEzh --stats --include="*.sh" --exclude={"bootstrap_copyToTarget.sh","config_workstation-desktopPreferences-terminal.sh","*.yml*"} "./" "${userid}@${targetIP}:~"   # kopiert nicht nur alle .sh außer den excludeten, sondern auch die excludeten mit (warum?):
# https://unix.stackexchange.com/questions/307862/rsync-include-only-certain-files-types-excluding-some-directories


# Copy login ssh-KeyFile to target
echo ""
echo "Kopiere login ssh-KeyFile '${sshKeyFile}' ins Home-Verzeichnis von '${userid}' auf Zielrechner '${targetIP}' ..."
ssh-copy-id -i "/home/${userid}/.ssh/${sshKeyFile}" "${userid}@${targetIP}"


# Copy public git-KeyFile to target
echo ""
echo "Kopiere public git-KeyFile '${gitKeyFile}' ins Home-Verzeichnis von '${userid}' auf Zielrechner '${targetIP}' ..."
rsync -Pv "/home/${userid}/.ssh/${gitKeyFile}" "${userid}@${targetIP}:~/.ssh"


echo ""
echo "Kopiervorgang beendet."
