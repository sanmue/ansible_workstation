#!/bin/bash

# Installieren benötigte Software zur Ausführung der autom. Inst. über Ansible
# Skript ist mit root-rechten zu Starten

repodir="dev"
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

echo "Aktiviere Firewall 'ufw' und erlaube ssh ..."
sudo ufw enable && sudo ufw allow ssh comment 'SSH' && sudo ufw reload

echo "Einrichten von git-config für ${userid} ..."
#userid=$(read -r "UserID des (Git-)Anwenders mit Ansible-Playbook eingeben:")
fullname=$(read -r "Name und Vorname eingeben:")
email=$(read -r "E-Mail Adresse eingeben:")
touch "/home/${userid}/.gitconfig"
echo "[user]" >> "/home/${userid}/.gitconfig"
echo "  email = ${email}" >> "/home/${userid}/.gitconfig"
echo "  name = ${fullname}" >> "/home/${userid}/.gitconfig"

echo "Erstelle neues Verzeichnis '${repodir}' im Home-Verzeichnis von '${userid}' ..."
mkdir -p "/home/${userid}/dev"

echo "Clone git-Repo des Ansible-Playbooks ins Verzeichnis '${repodir}' ..."
#cd "/home/${userid}/${repodir}"
git clone git@github.com:sanmue/ansible_test.git "/home/${userid}/${repodir}"
#cd "/home/${userid}/${repodir}"

echo "Starte TEST des Playbooks ..."
ansible-playbook "/home/${userid}/dev/ansible_test/local.yml" -v --ask-become-pass --check
# bei verschllüsselten Daten:
#ansible-playbook "/home/${userid}/dev/ansible_test/local.yml" -v -K -C --vault-password-file "/home/${userid}/.ansibleVaultKey"
