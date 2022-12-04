#!/bin/bash

# -------------------------------------------------------------------
# TestLab
# Kopiere bootstrap-skript von aktuellem System auf die Zielmaschine
# mögliche Übergabe-Parameter: 
#   - IP-Adresse der Zielmaschine
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
sshKeyFile="id_ed25519_loginTest"
gitKeyFile="id_ed25519_githubTest"
pubFileType=".pub"   # public ssh key


# ###########
# region main
# ###########

# Copy bootstrap-Skript to target
echo "----------------------------------------"
echo "Kopiere bootstrap-Skript ins Home-Verzeichnis von '${userid}' auf Zielrechner '${targetIP}' ..."
#rsync -avPEzh --stats "bootstrap_ubuntu.sh" "${userid}@${targetIP}:~"
#rsync -avPEzh --stats --include="*.sh" --exclude={"bootstrap_copyToTarget.sh","config_workstation-desktopPreferences-terminal.sh","*.yml*"} "./" "${userid}@${targetIP}:~"   # kopiert nicht nur alle .sh außer den excludeten, sondern auch die excludeten mit (warum?):
# https://unix.stackexchange.com/questions/307862/rsync-include-only-certain-files-types-excluding-some-directories
# current:
rsync -avPEzh --stats --exclude={"bootstrap_copyToTarget-TestLab.sh","config_workstation-desktopPreferences-terminal.sh","config_all-servcices-misc-vim.sh","*.yml*"} --include="*.sh" "./" "${userid}@${targetIP}:~"


# Copy login ssh-KeyFile to target
echo "----------------------------------------"
echo "Kopiere public ssh-KeyFile (logon) '${sshKeyFile}${pubFileType}' ins ssh-Verzeichnis von '${userid}' auf Zielrechner '${targetIP}' ..."
ssh-copy-id -i "/home/${userid}/.ssh/${sshKeyFile}${pubFileType}" "${userid}@${targetIP}"


# Copy public + pivate git-KeyFile to target
echo "----------------------------------------"
echo "Kopiere public + private ssh-KeyFile (git) '${gitKeyFile}' ins ssh-Verzeichnis von '${userid}' auf Zielrechner '${targetIP}' ..."
rsync -PEzhv "/home/${userid}/.ssh/${gitKeyFile}" "${userid}@${targetIP}:~/.ssh"
rsync -PEzhv "/home/${userid}/.ssh/${gitKeyFile}${pubFileType}" "${userid}@${targetIP}:~/.ssh"

# Importiere ssh-KeyFile (git)
# - nicht (mehr) notwendigt, da privaten ssh-KeyFile (git) auch kopiere (s.o.)
# - damit wird in Gnome "seahorse" ("Passwords and Keys") der Key korrekt vertraut/aufgeführt
#echo "----------------------------------------"
#echo "Importiere ssh-KeyFile (git) '${gitKeyFile}' für '${userid}' auf Zielrechner '${targetIP}' ..."
#lokale Variante (ungestestet, Variablen sind zu ersetzen): #sudo -u "${userid}" "ssh-add ~/.ssh/${gitKeyFile}"
#remote-Variante (ungestestet, evtl. wird bei Befehlsteil "...{gitKeyFile}..." auf Zielsystem nicht bakannt sein): 
#   #ssh "${userid}@${targetIP}" "ssh-add ~/.ssh/${gitKeyFile}"


echo ""
echo "Kopiervorgang beendet."
