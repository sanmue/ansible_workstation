#!/bin/bash

### -------------------------------------------
### Installation der initial benötigten Pakete
### Git Config
### Start automatisierte Installation (Ansible)
### -------------------------------------------


### ---
### Variablen
### ---
repodir="dev"
playbookdir="ansible_workstation"
sshkeydir=".ssh"
userid=$(whoami)   # oder: userid=${USER}
defaultDomain="universalaccount.de"
defaultMail="${userid}@${defaultDomain}"
gitOnlineRepo="git@github.com:sanmue/${playbookdir}.git"
os=""
oslist=("Ubuntu" "Manjaro")   # aktuell berücksichtige Betriebssysteme


# echo "Ich bin: ${userid}"
#if [ "${userid}" != "root" ]; then 
#    echo "Skript bitte mit sudo/root-Rechten ausführen."
#    echo "Skript wird beendet."
#    echo "Bitte Enter drücken."
#    read -r
#    exit 0
#fi


### ---
### Abfrage verwendetes Betriebssystem (OS)
### ---
if [ "$(hostnamectl)" ] ; then
    os=$(hostnamectl | grep "Operating System" | cut -d : -f 2 | xargs)
else
    echo "Befehl 'hostnamectl' nicht verfügbar, Eingabe verwendetes System erforderlich."

    promptOk=false
    while [ ! "${promptOk}" = true ] ; do   #Eingabe-Schleife
        echo "Aktuell mögliche Eingaben für OS: ${oslist[*]}"
        read -r -p "OS eingeben, Ende mit 'x': " os

        if [[ "${os}" == "x" ]] ; then
            exit 0
        fi

        if [[ ! "${oslist[*]}" =~ ${os} ]] ; then
            echo -e "Falsche Eingabe\n"
        else
            promptOk=true
            #echo "Eingegebenes OS: ${os}"
        fi

    done
fi

echo "Verwendetes OS: ${os}"


### ---
### Installation initial benötigter Pakete und Services abhängig von Betriebssystem:
### ---
case ${os} in
    Manjaro*)
        #if [ ! -f "/home/${userid}/.bootstrapMirrorPool" ]; then
            #touch "/home/${userid}/.bootstrapMirrorPool"

            echo -e "\nReset custom mirror list + customize mirror pool + full refresh of the package database and update all packages on the system..."
            sudo pacman-mirrors -c all && pacman-mirrors --country Germany,France,Austria,Switzerland,Netherlands && sudo pacman -Syyu
        #fi

        echo -e "\nInstallation initial benoetigte Software (git, ansible, openssh, ufw)..."
        sudo pacman -Syu --needed --noconfirm rsync git ansible openssh ufw ufw-extras vim

        echo -e "\nInstallation benoetigte Software zur Installation von AUR-Packages..."
        sudo pacman -Syu --needed --noconfirm base-devel

        echo -e "\nAktiviere Firewall 'ufw' und erlaube ssh ..."
        sudo systemctl enable ufw.service && sudo ufw enable && sudo ufw allow ssh comment 'SSH' && sudo ufw reload

        echo -e "\nStarte und aktiviere sshd.service..."
        sudo systemctl start sshd.service && sudo systemctl enable sshd.service
    ;;

    Ubuntu*)
        echo -e "\nUpdate Repos und Installation benoetigte Software (git,ansible,ssh,ufw,chrome-genome-shell)..."
        sudo apt-get update && sudo apt-get dist-upgrade -y && sudo apt-get install -y --show-progress rsync git ansible chrome-gnome-shell ssh ufw vim

        echo -e "\nInstalliere benötigte Packages für Installation von Microsoft PowerShell"
        sudo apt-get install -y --show-progress wget apt-transport-https software-properties-common

        echo -e "\nInstalliere noch fehlende, benötigte Packages für Installation von Brave Web Browser"
        sudo apt-get install -y --show-progress curl

        echo -e "\nAktiviere Firewall 'ufw' und erlaube ssh ..."
        sudo ufw enable && sudo ufw allow ssh comment 'SSH' && sudo ufw reload
    ;;

    Debian*)
        if [[ ! $(grep sudo /etc/group) = *"${userid}"* ]]; then 
            echo "Füge User '${userid}' der sudo-Gruppe hinzu"
            su -l root --command "usermod -aG sudo ${userid}"

            echo "Erzwinge ausloggen des aktuellen Users, sudo-Gruppeneintrag greift nach Neuanmeldung."
            read -rp "Bitte Eingabe-Taste drücken, um fortzufahren."
            pkill -KILL -u "${userid}"
        fi

        echo -e "\nUpdate Repos und Installation benoetigte Software (git,ansible,ssh,ufw,chrome-genome-shell)..."
        sudo apt-get update && sudo apt-get dist-upgrade -y && sudo apt-get install -y --show-progress rsync git ansible chrome-gnome-shell openssh-client openssh-server ufw vim

        echo -e "\nInstalliere benötigte Packages für Installation von Microsoft PowerShell"
        sudo apt-get install -y --show-progress wget apt-transport-https software-properties-common

        echo -e "\nInstalliere noch fehlende, benötigte Packages für Installation von Brave Web Browser"
        sudo apt-get install -y --show-progress curl

        echo -e "\nStarte + Aktiviere ssh ..."
        sudo systemclt start ssh && sudo systemctl enable ssh

        echo -e "\nAktiviere Firewall 'ufw' und erlaube ssh ..."
        sudo ufw enable && sudo ufw allow ssh comment 'SSH' && sudo ufw reload
    ;;

    openSUSE*)
        echo -e "\nUpdate Repos und Installation benoetigte Software (git,ansible,ssh,firewalld)..."
        sudo zypper refresh && sudo zypper dist-upgrade -y --details && sudo zypper install -y --details rsync git ansible openssh firewalld vim

        #echo -e "\nInstalliere benötigte Packages für Installation von Microsoft PowerShell"
        # https://learn.microsoft.com/en-us/powershell/scripting/install/install-other-linux?view=powershell-7.3
        # https://en.opensuse.org/PowerShell
        # PowerShell is not provided by any official openSUSE repositories. ...ways for Leap and Tumbleweed:
        # Möglichkeit 1: snap-package (https://snapcraft.io/install/powershell/opensuse)
        # Möglichkeit 2: Install directly from RPM; Install binaries from tar.gz; Install using "sudo dotnet tool install --global powershell" command
        
        echo -e "\nInstalliere noch fehlende, benötigte Packages für Installation von Brave Web Browser"
        sudo apt-get install -y --details curl

        echo -e "\nAktiviere Firewall 'firewalld' und erlaube ssh ..."
        sudo systemctl enable firewalld && sudo systemctl start firewalld && sudo firewall-cmd --zone=public --add-service=ssh --permanent && sudo firewall-cmd --reload
    ;;


    *)
        echo "Unbehandelter Fall: switch os - default-switch Zweig"
        read -r -p "Eingabe-Taste drücken zum Beenden"
        exit 0
    ;;
esac


### ---
### Git Config
### ---
echo -e "\nErstelle git config mit Name '${userid}' und Mailadresse '${defaultMail}'..."
git config --global user.name "${userid}"
git config --global user.email "${defaultMail}"
echo "Git-config ist nun:" 
#git config --list   #bei openSUSE wird .gitconfig in vi geöffnet
cat "/home/${userid}/.gitconfig"

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


### ---
### (Neu-)Erstellen Verzeichnis für Ansible Playbook im Home-Verzeichnis aktueller User
### ---
echo -e "\nErstelle neues Verzeichnis '${repodir}' und Unterverzeichnis '${playbookdir}' im Home-Verzeichnis von '${userid}' ..."
if [ -d "/home/${userid}/${repodir}/${playbookdir}" ]; then
    echo "Verzeichnis '${playbookdir}' existiert bereits, wird gelöscht."
    sudo rm -r "/home/${userid}/${repodir}/${playbookdir}" # && mkdir -p "/home/${userid}/${repodir}/${playbookdir}"
    #cd "/home/${userid}/${repodir}/${playbookdir}"
    #git pull origin
    #cd
else
    mkdir -p "/home/${userid}/${repodir}/${playbookdir}"
fi


### ---
### Clone Git-Repo des Ansible Playbook ins lokale Ansible Playbook-Verzeichnis
### ---
echo -e "\nClone github-Repo des Ansible-Playbook nach '/home/${userid}/${repodir}/${playbookdir}' ..."
if [[ -n $(ls -I 'known_hosts' -I 'known_hosts.old' -I 'authorized_keys' "/home/${userid}/${sshkeydir}") ]] ; then   #einfacher Test; ggf. ssh-key für gitOnlineRepo trotzdem nicht vorhanden
    git clone "${gitOnlineRepo}" "/home/${userid}/${repodir}/${playbookdir}"
else
    echo "SSH-Key - Verzeichnis '/home/${userid}/${sshkeydir}' scheint keine SSH-Keys zu enthalten."
    echo "Bitte erforderliche(n) SSH-Key hinzufügen."
    read -r -p "Programmende, bitte Eingabetaste drücken."
    exit 0
fi


### ---
### Test / Ausführen Ansbile Playbook
### ---
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

echo -e "\nStarte Ansible-Playbook ..."
ansible-playbook "/home/${userid}/${repodir}/${playbookdir}/local.yml" -v --ask-become-pass
# bei verschlüsselten Daten:
#ansible-playbook "/home/${userid}/${repodir}/${playbookdir}/local.yml" -v -K --vault-password-file "/home/${userid}/.ansibleVaultKey"
