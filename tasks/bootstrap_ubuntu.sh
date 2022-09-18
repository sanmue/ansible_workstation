#!/bin/bash

# Installieren benötigte Software zur Ausführung der autom. Inst. über Ansible
# Skript ist mit root-rechten zu Starten

repodir="dev"
playbookdir="ansible_test"
userid=$(whoami)

# echo "Ich bin: ${userid}"
#if [ "${userid}" != "root" ]; then 
#    echo "Skript bitte mit root-Rechten ausfuehren."
#    echo "Skript wird beendet."
#    echo "Bitte Enter druecken."
#    read -r
#    exit 0
#fi

echo "Update Repos und Installation benoetigte Software ..."
sudo apt-get update && sudo apt-get dist-upgrade -y && sudo apt-get install -y --show-progress git ansible chrome-gnome-shell ssh ufw

echo "Installiere benötigte Packages für Installation von Microsoft PowerShell"
sudo apt-get install -y --show-progress wget apt-transport-https software-properties-common

echo "Aktiviere Firewall 'ufw' und erlaube ssh ..."
sudo ufw enable && sudo ufw allow ssh comment 'SSH' && sudo ufw reload

read -rp "Soll Git konfiguriert werden (git config Name+Mail) für '${userid}' (j/n): " gitconf
if [ "${gitconf}" = 'j' ]; then
    read -rp "Name und Vorname eingeben: " fullname
    read -rp "E-Mail Adresse eingeben: " email
    #touch "/home/${userid}/.gitconfig"
    #echo "[user]" > "/home/${userid}/.gitconfig"
    #echo "  email = ${email}" >> "/home/${userid}/.gitconfig"
    #echo "  name = ${fullname}" >> "/home/${userid}/.gitconfig"
    git config --global user.name "${fullname}"
    git config --global user.email "${email}"
    echo "Git-config ist nun:" 
    git config --list
else
    echo "Git config wird übersprungen"
fi

echo "Erstelle neues Verzeichnis '${repodir}' und Unterverzeichnis '${playbookdir}' im Home-Verzeichnis von '${userid}' ..."
mkdir -p "/home/${userid}/${repodir}/${playbookdir}"

echo "Clone git-Repo des Ansible-Playbooks ins Verzeichnis '${repodir}' ..."
#cd "/home/${userid}/${repodir}"
git clone git@github.com:sanmue/ansible_test.git "/home/${userid}/${repodir}/${playbookdir}"
#cd "/home/${userid}/${repodir}"

#echo "Starte TEST des Playbooks ..."
#ansible-playbook "/home/${userid}/dev/ansible_test/local.yml" -v --ask-become-pass --check
# bei verschllüsselten Daten:
#ansible-playbook "/home/${userid}/dev/ansible_test/local.yml" -v -K -C --vault-password-file "/home/${userid}/.ansibleVaultKey"

echo "Starte Playbook ..."
ansible-playbook "/home/${userid}/dev/ansible_test/local.yml" -v --ask-become-pass
