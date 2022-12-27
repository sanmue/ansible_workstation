#!/bin/bash

# Installieren benötigte Software zur Ausführung der autom. Inst. über Ansible
# Skript ist mit root-Rechten zu Starten

repodir="dev"
playbookdir="ansible_test"
userid=$(whoami)
defaultDomain=universalaccount.de
defaultMail=${userid}@${defaultDomain}
githubOnlineRepo="git@github.com:sanmue/ansible_test.git"

# echo "Ich bin: ${userid}"
#if [ "${userid}" != "root" ]; then 
#    echo "Skript bitte mit root-Rechten ausfuehren."
#    echo "Skript wird beendet."
#    echo "Bitte Enter druecken."
#    read -r
#    exit 0
#fi

echo ""
echo "Update Repos und Installation benoetigte Software (git,ansible,ssh,ufw,chrome-genome-shell)..."
sudo apt-get update && sudo apt-get dist-upgrade -y && sudo apt-get install -y --show-progress git ansible chrome-gnome-shell ssh ufw

echo ""
echo "Installiere benötigte Packages für Installation von Microsoft PowerShell"
sudo apt-get install -y --show-progress wget apt-transport-https software-properties-common

echo ""
echo "Installiere noch fehlende, benötigte Packages für Installation von Brave Web Browser"
sudo apt-get install -y --show-progress curl

echo ""
echo "Aktiviere Firewall 'ufw' und erlaube ssh ..."
sudo ufw enable && sudo ufw allow ssh comment 'SSH' && sudo ufw reload

#echo ""
#read -rp "Soll Git konfiguriert werden (git config Name+Mail) für '${userid}' (j/n)?: " gitconf
#if [ "${gitconf}" = 'j' ]; then
#    read -rp "Name und Vorname eingeben: " fullname
#    read -rp "E-Mail Adresse eingeben: " email
#    #touch "/home/${userid}/.gitconfig"
#    #echo "[user]" > "/home/${userid}/.gitconfig"
#    #echo "  email = ${email}" >> "/home/${userid}/.gitconfig"
#    #echo "  name = ${fullname}" >> "/home/${userid}/.gitconfig"
#    git config --global user.name "${fullname}"
#    git config --global user.email "${email}"
#    echo "Git-config ist nun:" 
#    git config --list
#else
#    echo "Git config wird übersprungen"
#fi

echo ""
echo "Erstelle git config mit Name '${userid}' und Mailadresse '${defaultMail}'..."
git config --global user.name "${userid}"
git config --global user.email "${defaultMail}"
echo "Git-config ist nun:" 
git config --list

echo ""
echo "Erstelle neues Verzeichnis '${repodir}' und Unterverzeichnis '${playbookdir}' im Home-Verzeichnis von '${userid}' ..."
if [ -d "/home/${userid}/${repodir}/${playbookdir}" ]; then
    echo "Verzeichnis '${playbookdir}' existiert bereits."
    sudo rm -r "/home/${userid}/${repodir}/${playbookdir}" # && mkdir -p "/home/${userid}/${repodir}/${playbookdir}"
    #cd "/home/${userid}/${repodir}/${playbookdir}"
    #git pull origin
    #cd
else
    mkdir -p "/home/${userid}/${repodir}/${playbookdir}"
fi


echo ""
echo "Clone github-Repo des Ansible-Playbooks ins Verzeichnis '${playbookdir}' ..."
git clone ${githubOnlineRepo} "/home/${userid}/${repodir}/${playbookdir}"


#echo ""
#read -rp "Soll TEST des Ansible-Playbooks durchgeführt werden (j/n)?: " testplay
#if [ "${testplay}" = 'j' ]; then
#    echo "Starte TEST des Playbooks ..."
#    ansible-playbook "/home/${userid}/${repodir}/${playbookdir}/local.yml" -v --ask-become-pass --check
#    # bei verschlüsselten Daten:
#    #ansible-playbook "/home/${userid}/${repodir}/${playbookdir}/local.yml" -v -K -C --vault-password-file "/home/${userid}/.ansibleVaultKey"
#else
#    echo "TEST des Playbooks wird NICHT durchgefürt"
#fi

echo ""
echo "Starte Ansible-Playbook ..."
ansible-playbook "/home/${userid}/${repodir}/${playbookdir}/local.yml" -v --ask-become-pass
# bei verschlüsselten Daten:
#ansible-playbook "/home/${userid}/${repodir}/${playbookdir}/local.yml" -v -K --vault-password-file "/home/${userid}/.ansibleVaultKey"
