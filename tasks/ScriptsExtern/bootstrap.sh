#!/usr/bin/env bash

#set -x   # enable debug mode

### ---------------------------------------------------------------------------
### Installation initial benötigter Pakete / Config (e.g. firewall, git, ...)
### Start automatisierte Installation (Ansible)
### Archlinux(-Derivate): Installationen (aus AUR) separat außerhalb playbook
### - um Ausführung playbook nicht wg. evtl. manueller Eingaben zu unterbrechen
### ---------------------------------------------------------------------------


### ---
### Variablen
### ---
repodir="ansible-install"
playbookdir="ansible_workstation"
playbook="local.yml"
sshkeydir=".ssh"
userid=$(whoami)   # oder: userid=${USER}
defaultDomain="universalaccount.de"
defaultMail="${userid}@${defaultDomain}"
gitOnlineRepo="git@github.com:sanmue/${playbookdir}.git"
gitdefaultBranchName="main"
os=""
oslist=("Ubuntu" "Manjaro" "EndeavourOS")   # aktuell berücksichtige Betriebssysteme


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

# ### Alle Systeme:
# Download 'Starshiop Shell Prompt' install-script
curl -sS "https://starship.rs/install.sh" > "/home/${userid}/starship_install.sh" && chmod +x "/home/${userid}/starship_install.sh"

# ### je System individuell:
case ${os} in
    Manjaro* | EndeavourOS*)
        if [ ! -f "/home/${userid}/.ansible_bootstrapMirrorPool" ]; then
            touch "/home/${userid}/.ansible_bootstrapMirrorPool"

            if [[ "${os}" = "Manjaro"* ]]; then
                echo -e "\nReset custom mirror list + customize mirror pool + full refresh of the package database and update all packages on the system..."
                # from listet countries:
                sudo pacman-mirrors -c all && sudo pacman-mirrors --method rank --country 'Germany,France,Austria,Switzerland,Netherlands,Belgium,Sweden' && sudo pacman -Syyu --noconfirm
            fi

            if [[ "${os}" = "EndeavourOS"* ]]; then
                echo -e "\nRetrieve up-to-date Arch Linux mirror data, rank it and update all packages on the system..."
                # https://wiki.archlinux.org/title/Mirrors#top-page
                # https://wiki.archlinux.org/title/Reflector#top-page
                # https://man.archlinux.org/man/reflector.1#EXAMPLES

                # Backup current mirrorlists:
                sudo cp /etc/pacman.d/endeavouros-mirrorlist /etc/pacman.d/endeavouros-mirrorlist.backup
                sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
                # rankmirrors für EndeavourOS (config: /etc/eos-rankmirrors.conf):
                sudo eos-rankmirrors # --verbose
                # Retrieve the latest mirror list from the Arch Linux Mirror Status page + listed countries:
                # (relector conf: /etc/xdg/reflector/reflector.conf
                sudo reflector --age 12 --protocol https --sort rate --country 'Germany,France,Austria,Switzerland,Netherlands,Belgium,Sweden' --save /etc/pacman.d/mirrorlist
                #sudo systemctl start reflector.service
                # Update all packages on the system:    # (pacman conf: /etc/pacman.conf)
                sudo pacman -Syyu --noconfirm
            fi
        fi

        echo -e "\nInstallation initial benoetigte Software (git, ansible, openssh, ufw)..."
        sudo pacman -Syu --needed --noconfirm rsync git ansible openssh vim yay firewalld

        if [ "${os}" = "EndeavourOS" ]; then
            echo -e "\nInstallation Archlinux, EndeavourOS: 'pamac-all'..."
            yay -S --needed --no-confirm pamac-all && touch "/home/${userid}/.ansible_bootstrap_yay-pamacInstall"
            # mit pamac ist (aktuell noch) es einfacher (automatisiert) mehrere (AUR)pakete ohne Nachfrage zu installieren 
            # (pamac build --no-confirm SW1 SW2 ...)
            # mit ansible modul pacman, executable yay + argumente (noch) nicht hingekriegt
        fi

        echo -e "\nInstallation benoetigte Software zur Installation von AUR-Packages..."
        sudo pacman -S --needed --noconfirm base-devel

        echo -e "\n Installation (wenn VM) spice agent for Linux guests (z.B. für clipboard sharing host+guest)"
        [[ $(systemd-detect-virt) != *"none"* ]] && sudo pacman -Syu --needed --noconfirm spice-vdagent

        echo -e "\nAktiviere Firewall 'firewalld' und erlaube ssh ..."
        sudo systemctl enable --now firewalld.service && sudo firewall-cmd --zone=public --add-service=ssh --permanent && sudo firewall-cmd --reload

        echo -e "\nStarte und aktiviere sshd.service..."
        sudo systemctl enable --now sshd.service

        echo -e "\nVM - Qemu/KVM: Wiki empfiehlt inst. von 'iptables-nft'"
        echo -e "Bestätige, dass 'iptables' (und 'inxi') gelöscht und 'iptables-nft' installiert wird"
        echo -e "Anmerkung: 'inxi' wird im Rahmen basis-inst wieder installiert"
        sudo pacman -S iptables-nft
    ;;    

    Ubuntu*)
        echo -e "\nUpdate Repos und Installation benoetigte Software (git,ansible,ssh,ufw,chrome-genome-shell)..."
        sudo apt-get update && sudo apt-get dist-upgrade -y && sudo apt-get install -y --show-progress rsync git ansible chrome-gnome-shell ssh ufw vim

        echo -e "\nInstalliere benötigte Packages für Installation von Microsoft PowerShell"
        sudo apt-get install -y --show-progress wget apt-transport-https software-properties-common

        echo -e "\nInstalliere noch fehlende, benötigte Packages für Installation von Brave Web Browser"
        sudo apt-get install -y --show-progress curl

        echo -e "\nInstallation (wenn VM) spice agent for Linux guests (z.B. für clipboard sharing host+guest)"
        [[ $(systemd-detect-virt) != *"none"* ]] && sudo apt-get install -y --show-progress spice-vdagent

        echo -e "\nFüge Repo für 'ulauncher' hinzu"
        if [ -e "/home/${userid}/.ansible_ppaUlauncherAdded" ]; then
            echo "Repo wurde bereits hinzugefügt, Schritt wird übersprungen"
        else
            sudo add-apt-repository ppa:agornostal/ulauncher && touch "/home/${userid}/.ansible_ppaUlauncherAdded"
        fi

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

        echo -e "\nInstallation (wenn VM) spice agent for Linux guests (z.B. für clipboard sharing host+guest)"
        [[ $(systemd-detect-virt) != *"none"* ]] && sudo apt-get install -y --show-progress spice-vdagent

        echo -e "\nDownload Visual Studio Code deb-file"
        if [ -f "/home/${userid}/Downloads/code.deb" ]; then
            echo "Datei '/home/${userid}/Downloads/code.deb' bereits vorhanden, Schritt wird übersprungen"
        else
            curl -L --create-file-mode 0755 -o "/home/${userid}/Downloads/code.deb" "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64"
        fi

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

        # https://unix.stackexchange.com/questions/89714/easy-way-to-determine-the-virtualization-technology-of-a-linux-machine
        echo -e "\n Installation (wenn VM) spice agent for Linux guests (z.B. für clipboard sharing host+guest)"
        [[ $(systemd-detect-virt) != *"none"* ]] && sudo zypper install -y --details spice-vdagent

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
echo -e "\nErstelle git config mit Name '${userid}', Email '${defaultMail}' und defaultBranch '${gitdefaultBranchName}' ..."
git config --global user.name "${userid}"
git config --global user.email "${defaultMail}"
git config --global init.defaultBranch "${gitdefaultBranchName}"
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
### Checke ssh-keys (einfache Prüfung)
### ---
echo -e "\nPrüfe auf ssh-keys..."
if [[ -n $(ls -I 'known_hosts' -I 'known_hosts.old' -I 'authorized_keys' "/home/${userid}/${sshkeydir}") ]] ; then   #einfacher Test; ggf. ssh-key für gitOnlineRepo trotzdem nicht vorhanden
    echo "SSH-Key - Verzeichnis '/home/${userid}/${sshkeydir}' enthält SSH-Keys."
else
    echo "SSH-Key - Verzeichnis '/home/${userid}/${sshkeydir}' scheint keine SSH-Keys zu enthalten."
    echo "Bitte erforderliche(n) SSH-Key hinzufügen, das sonst das git-repo nicht heruntergeladen werden kann."
    read -r -p "Programmende, bitte Eingabetaste drücken."
    exit 0
fi


### ---
### Git-repo mit Ansible Playbook herunterladen (clone oder pull)
### ---
echo -e "\nGit-repo mit Ansible Playbook herunterladen oder aktualisieren (clone oder pull) ..."
if [ -d "/home/${userid}/${repodir}/${playbookdir}" ]; then
    echo "Verzeichnis für repo '/home/${userid}/${repodir}/' existiert bereits, führe 'git pull origin' aus..."
    cd "/home/${userid}/${repodir}/${playbookdir}" && git pull origin
else
    echo "Erstelle Verzeichnis '${playbookdir}' unter '/home/${userid}/${repodir}/' für git repo..."
    mkdir -p "/home/${userid}/${repodir}/${playbookdir}"

    echo "Clone git-repo lokal nach '/home/${userid}/${repodir}/${playbookdir}'..."
    git clone "${gitOnlineRepo}" "/home/${userid}/${repodir}/${playbookdir}"
fi

### ---
### Test / Ausführen Ansbile Playbook
### ---
#echo ""
#read -rp "Soll TEST des Ansible-Playbooks durchgeführt werden (j/n)?: " testplay
#if [ "${testplay}" = 'j' ]; then
#    echo "Starte TEST des Playbooks ..."
#    ansible-playbook "/home/${userid}/${repodir}/${playbookdir}/${playbook}" -v --ask-become-pass --check
#    # bei verschlüsselten Daten:
#    #ansible-playbook "/home/${userid}/${repodir}/${playbookdir}/${playbook}" -v -K -C --vault-password-file "/home/${userid}/.ansibleVaultKey"
#else
#    echo "TEST des Playbooks wird NICHT durchgefürt"
#fi

echo -e "\nStarte Ansible-Playbook ..."
ansible-playbook "/home/${userid}/${repodir}/${playbookdir}/${playbook}" -v -K
# bei verschlüsselten Daten:
#ansible-playbook "/home/${userid}/${repodir}/${playbookdir}/${playbook}" -v -K --vault-password-file "/home/${userid}/.ansibleVaultKey"



### ---
### Archlinux/Manjaro: weitere Installationen
### - am Schluss, damit nicht aufhalten
### ---
read -r -p "Install from AUR: Citrix ICA-Client, autokey, virtio-win, MS TTF Fonts, ...? ('j'=ja, sonstige Eingabe: nein)" installAUR

if [ "${installAUR}" == "j" ]; then
    case ${os} in
        Manjaro* | EndeavourOS*)
            echo -e "\nInstall 'autokey-gtk' from AUR (Arch)"
            yay -S --needed autokey-gtk && touch "/home/${userid}/.ansible_bootstrap_autokeyGtkInstalled"

            # echo -e "\nInstall 'autokey-qt' from AUR (Arch)"
            # yay -S --needed autokey-qt # && touch "/home/${userid}/.ansible_bootstrap_autokeyQtInstalled"

            echo -e "\nInstall brave,steam,ttf-meslo(10k) from AUR (Arch)"
            yay -S --needed brave-bin linux-steam-integration ttf-meslo-nerd-font-powerlevel10k && touch "/home/${userid}/.ansible_bootstrap_severalAurPkgInstalled"

            echo -e "\nInstall Citrix Workspace App (icaclient) from AUR (Arch,Manjaro)"
            #pamac build icaclient && touch "/home/${userid}/.ansible_bootstrap_pamac-icaclientInstalled"
            yay -S --needed --no-confirm icaclient && touch "/home/${userid}/.ansible_bootstrap_pamac-icaclientInstalled"

            echo -e "\nVM - Install virtio-win image from AUR (Arch,Manjaro))"
            #pamac build virtio-win && touch "/home/${userid}/.ansible_bootstrap_pamac-vmVirtioWinInstalled"
            yay -S --needed virtio-win && touch "/home/${userid}/.ansible_bootstrap_pamac-vmVirtioWinInstalled"

            echo -e "\nInstall Microsoft TTF Fonts from AUR (Arch,Manjaro))"
            #pamac build ttf-ms-fonts && touch "/home/${userid}/.ansible_bootstrap_pamac-ttfmsfontsInstalled"
            yay -S --needed ttf-ms-fonts && touch "/home/${userid}/.ansible_bootstrap_pamac-ttfmsfontsInstalled"

            echo -e "\nInstall 'btrfs-assistant' from AUR (Archlinux; bei Manjaro (sollte) schon installiert (sein))"
            #pamac build --no-confirm btrfs-assistant
            yay -S --needed btrfs-assistant && touch "/home/${userid}/.ansible_bootstrap_pamac-btrfsassistantInstalled"

            #echo -e "\nInstall woeusb-ng from AUR (Arch,Manjaro))"
            ##pamac build woeusb-ng && touch "/home/${userid}/.ansible_bootstrap_pamac-woeusbngInstalled"   # Tool to create Windows boot stick
            #yay -S --needed --no-confirm woeusb-ng && touch "/home/${userid}/.ansible_bootstrap_pamac-woeusbngInstalled"
        ;;

        *)
            echo -e "\nUnbehandelter Fall: switch os - Arch weitere Installationen - default-switch Zweig"
            read -r -p "Eingabe-Taste drücken zum Beenden"
            exit 0
        ;;
    esac
fi
