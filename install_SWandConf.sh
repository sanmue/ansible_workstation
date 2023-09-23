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
playbookdir="ansible_workstation"   # also repo name
playbook="local.yml"
userid=$(whoami)   # or: userid=${USER}
oslist=("Ubuntu" "EndeavourOS" "Arch Linux")   # currently supportet distributions
bootloaderId='GRUB'   # or 'endeavouros', ...

if [ -e "/efi" ]; then          # Uefi - EFI path
	efiDir="/efi"
elif [ -e "/boot/efi" ]; then   # Uefi - EFI path (deprecated location)
	efiDir="/boot/efi"
else                            # Bios
	# echo "Bios boot mode"
	efiDir=""
fi

snapperConfigName_root="root"
snapperSnapshotFolder="/.snapshots"
declare -A btrfsSubvolLayout=(  ["@"]="/" 
                                ["@snapshots"]="${snapperSnapshotFolder}" 
                                ["@home"]="/home" 
                                ["@opt"]="/opt" 
                                ["@srv"]="/srv" 
                                ["@tmp"]="/tmp" 
                                ["@usrlocal"]="/usr/local"
                                ["@varcache"]="/var/cache" 
                                ["@varlog"]="/var/log" 
                                ["@varopt"]="/var/opt" 
                                ["@varspool"]="/var/spool" 
                                ["@vartmp"]="/var/tmp" 
                                ["@libvirtimages"]="/var/lib/libvirt/images" )

btrfsFstabMountOptions_standard='defaults,noatime,discard=async,compress=zstd,space_cache=v2 0 0'   # desired mountOptions for btrfs-filesystem
btrfsFstabMountOptions_endeavour='defaults,noatime,compress=zstd 0 0'                               # searchString; fstab-entry will be replaced with $btrfsFstabMountOptions_standard


### ---
### Check Operating System (OS)
### ---
os=$(grep -e "^NAME=" /etc/os-release | cut -d '"' -f 2 | xargs)
echo "Current OS: ${os}"

supportedOS="false"
for osname in "${oslist[@]}"; do
    if [ "${os}" = "${osname}" ]; then
        supportedOS="true"
    fi
done
if [ "${supportedOS}" = "false" ]; then 
    echo -e "\e[0;31mSorry, your OS '${os}' is not supported. Script/Playbook won't work for you.\e[39m"
    echo "Skript will exit here :-("
    #read -r -p
    exit 1
fi


### ---
### Hostname
### ---
echo -e "\nCurrent hostname: '$(hostname)'"
read -r -p "Change hostname? ('y'=yes, other input=no): " changeHostname
if [ "${changeHostname}" = 'y' ]; then
    read -r -p "Enter new hostname: " newHostname
    sudo hostnamectl hostname "${newHostname}"
    echo "New hostname '${newHostname}' set, continue with any input"
fi


### ---
### Inst + config snapper
### ---

# check filesystem type + aks if snapper should be installed:
if [[ $(stat -f -c %T /) = 'btrfs' ]] && [[ ! -e "/home/${userid}/.ansible_bootstrap_snapperGrub" ]]; then   # prüfe '/' auf btrfs-filsystem;  -f, --file-system; -c, --format; %T - Type in human readable form
    read -r -p "Should 'snapper' (for snapshot creation) be installed/configured ('y'=yes, other input=no)?: " doSnapper
fi

if [[ "${doSnapper}" = 'y' ]]; then
    if [ ! -e "${snapperSnapshotFolder}" ]; then   # check if ${snapperSnapshotFolder} exists
        echo -e "\e[0;33mVerzeichnis '${snapperSnapshotFolder}' nicht vorhanden. Evlt. abweichendes Verzeichnis konfiguriert?!\nGgf. vorheriger manueller Eingriff erforderlich.\e[39m" 
        read -r -p "Installation/Konfiguration fortsetzen mit beliebiger Eingabe, Abbrechen mit <CTRL> + <c>"
    fi

    echo -e "\n*** ********************************************"
    echo      "*** Start: Installation und config von 'snapper'"
    case ${os} in
        Arch* | Endeavour*)        # aktuell für UEFI oder GRUB2 + Grub sowie für UEFI + systemd boot
            # https://wiki.archlinux.org/title/Btrfs
            # https://wiki.archlinux.org/title/Snapper
            # https://documentation.suse.com/sles/15-SP4/html/SLES-all/cha-snapper.html

            echo -e "\n*** Installation snapper+grub software packages..."
            sudo pacman --needed --noconfirm -S snapper snap-pac inotify-tools      # snap-sync

            if [ -e "${efiDir}/grub.cfg" ] || [ -e "/boot/grub" ]; then             # GRUB (UEFI oder BIOS)
                sudo pacman --needed --noconfirm -S grub-btrfs
            fi


            echo -e "\n*** (Re)create snapshots folder + snapper config..."
            # Arch Linux | EndeavourOS:
            # - '/.snapshots' wird nicht standardmäßig erstellt
            #
            # Info: beim erstellen der config ${snapperConfigName_root} wird automatisch ein Subvolume (und damit Verzeichnis) '.snapshots' auf '/' erstellt
            # welches wieder gelöscht wird, da das Subvolume für Snapshots '@snapshots' heißen soll
            #
            if [ -e "${snapperSnapshotFolder}" ]; then   # falls bereits vorhanden
                echo "Unmount + Löschen '${snapperSnapshotFolder}', um angepasste Konfiguration durchzuführen..."
                sudo umount "${snapperSnapshotFolder}"
                sudo rm -rf "${snapperSnapshotFolder}"   # entspricht löschen subvolume
            fi

            echo "*** Erstelle snapper config '${snapperConfigName_root}' für '/'"
            sudo snapper -c "${snapperConfigName_root}" create-config /


            echo "*** Lösche autom. angelegtes Subvolume '${snapperSnapshotInitialSubvolume}' (aus vorherigem Schritt 'Erstelle snapper config')..."
            sudo btrfs subvolume delete "${snapperSnapshotFolder}"
            echo "*** Erstelle (wieder) Verzeichnis '${snapperSnapshotFolder}'..."
            sudo sudo mkdir -p "${snapperSnapshotFolder}"


            echo "*** Erstelle Subvolumes (sofern nicht schon vorhanden) und entsprechende fstab-Einträge"
            echo "Aktuelle /etc/fstab:"
            cat /etc/fstab
            filesystemName=$(grep -e "subvol=/@[^a-zA-Z]" /etc/fstab | cut -f 1 | xargs)   # Endeavour/Manjaro (mit btrfsSubvolLayouterschlüssellung) mounted schon subvols in fstab # z.B.: UUDI=luks-8f1cf7bc-8064-422b-bd46-466438199874
            if [ -z "${filesystemName}" ]; then   # if filesystemName not found in the step before, make a new attempt:
                filesystemName=$(grep -w "subvol=/" /etc/fstab | cut -f 1 | xargs)   # just default btrfs root subvol '/', if nothing else configured beforehand; default subvol not set to a seperately created subvol e.g. named '@' / ID XXX  # e.g.: UUID=0a6f7460-736b-4823-b959-846cb47cde34
            fi

            read -r -p "Nutze file system '${filesystemName}'. Ist das korrekt ('n'=nein, sonstige Eingabe=ja)?: " fsok
            if [ "${fsok}" = "n" ]; then
                endloop='n'
                while [ ! "$endloop" = 'j' ]; do
                    read -r -p "Manuelle Eingabe: " filesystemName
                    read -r -p "Ist '${filesystemName}' korrekt ('j'=ja, beliebige Eingabe für Korrektur)?: " endloop
                done
            fi

            sudo cp /etc/fstab /etc/fstab.bak   # Sicherung
            echo -e "\nMount: 'subvolid=5' '${filesystemName}' nach '/mnt'..."
            sudo mount -t btrfs -o subvolid=5 "${filesystemName}" /mnt

            for subvol in "${!btrfsSubvolLayout[@]}"; do
                if [ ! -e "/mnt/${subvol}" ]; then      # wenn Subvolume noch nicht vorhanden
                    echo "|__ Erstelle Subvolume '/mnt/${subvol}'..."
                    sudo btrfs subvolume create "/mnt/${subvol}"
                else
                    echo -e "\e[0;33m|__ Subvolume '/mnt/${subvol}' bereits vorhanden\e[39m"                 
                fi
            done

            echo "Unmount '/mnt'..."
            sudo umount /mnt


            echo -e "\n*** Erstelle Einträge in '/etc/fstab':"
            for subvol in "${!btrfsSubvolLayout[@]}"; do
                subvolInFstab='false'
                mountPointInFstab='false'

                echo "|__ erstelle Eintrag für Subvolume '${subvol}' mit mount point '${btrfsSubvolLayout[${subvol}]}'..."

                if [ ! -e  "${btrfsSubvolLayout[${subvol}]}" ]; then    # wenn Mount-Ziel (Verzeichnis) noch nicht vorhanden
                    echo -e "\e[0;33m    |__ Mount-Ziel '${btrfsSubvolLayout[${subvol}]}' nicht vorhanden, Verzeichnis wird erstellt...\e[39m"
                    sudo mkdir -p "${btrfsSubvolLayout[${subvol}]}"
                fi

                if [[ $(grep "subvol=/${subvol}," /etc/fstab) ]]; then  # wenn Eintrag für z.B. ...'subvol=/@,'... bereits vorhanden
                    echo -e "\e[0;33m    |__ Eintrag für Subvolume '${subvol}' bereits vorhanden, ggf. prüfen/korrigieren\e[39m"
                    subvolInFstab='true'
                fi

                if [[ $(grep -E " +${btrfsSubvolLayout[${subvol}]} +" /etc/fstab) ]]; then  # wenn Mount Point (z.B. für '/') bereits vorhanden
                    echo -e "\e[0;33m    |__ Mount-Ziel '${btrfsSubvolLayout[${subvol}]}' bereits vorhanden, '${subvol}' wird nicht (nochmal) hinterlegt, ggf. prüfen/korrigieren\e[39m"
                    mountPointInFstab='true'
                fi

                if [ "${subvolInFstab}" = 'false' ] && [ "${mountPointInFstab}" = 'false' ]; then
                    echo "${filesystemName} ${btrfsSubvolLayout[${subvol}]} btrfs subvol=/${subvol},${btrfsFstabMountOptions_standard}" | sudo tee -a /etc/fstab
                fi
            done

            echo -e "\nErsetze/korrigiere ggf. mount-options in '/etc/fstab':"
            echo -e "Ersetze ggf. fstab btrfs mount-option (Endeavour)'...${btrfsFstabMountOptions_endeavour}' mit '...${btrfsFstabMountOptions_standard}'"
            sudo sed -i "s/${btrfsFstabMountOptions_endeavour}/${btrfsFstabMountOptions_standard}/g" /etc/fstab

            echo "Aktualisiere systemd units aus fstab + mount all..."
            sudo systemctl daemon-reload && sudo mount -a


            echo -e "\n*** Default-Subvolume festlegen"
            echo "aktuelles default-Subvolume für '/': $(sudo btrfs subvolume get-default /)"
            echo -e "Subvolume-Liste:\n$(sudo btrfs subvolume list /)"
            endloop='n'
            while [ ! "$endloop" = 'j' ]; do
                read -r -p "Bitte ID von @ eingeben: " idRootSubvol
                read -r -p "Ist ID '${idRootSubvol}' korrekt ('j'=ja, beliebige Eingabe für Korrektur)?: " endloop
            done
            sudo btrfs subvolume set-default "${idRootSubvol}" / && \
            echo "aktuelles root default-Subvolume: $(sudo btrfs subvolume get-default /)"


            # UEFI+Grub / BIOS+Grub / UEFI+systemD
            echo -e "\n*** Re-Install grub + Update grub boot-Einträge"
            # https://wiki.archlinux.org/title/GRUB
            # if [ -e "/sys/firmware/efi/efivars" ]; then    # check if booted into UEFI mode and UEFI variables are accessible
            if [ -e "${efiDir}/" ] && [ -e "/boot/grub/grub.cfg" ]; then    # UEFI + Grub
                sudo grub-install --target=x86_64-efi --efi-directory="${efiDir}" --bootloader-id="${bootloaderId}" && \
                sudo grub-mkconfig -o /boot/grub/grub.cfg && \
                sudo grub-mkconfig
            elif [ -e "/boot/grub/grub.cfg" ]; then                         # BIOS + Grub
                lsblk
                endloop='n'
                while [ ! "$endloop" = 'j' ]; do
                    read -r -p "Eingabe device-Pfad für grub-install (z.B. '/dev/vda'): " devGrubInstallPath    # nicht Partition (z.B. '/dev/vda1'), sondern Disk (z.B. '/dev/vda')
                    read -r -p "Ist '${devGrubInstallPath}' korrekt ('j'=ja, beliebige Eingabe für Korrektur)?: " endloop
                done
                # https://wiki.archlinux.org/title/GRUB#Installation_2
                # BIOS: grub-install --target=i386-pc /dev/sdX; where i386-pc is deliberately used regardless of your actual architecture, and /dev/sdX is the disk (not a partition) where GRUB is to be installed.
                sudo grub-install --target=i386-pc "${devGrubInstallPath}" && sudo grub-mkconfig -o /boot/grub/grub.cfg && \
                sudo grub-mkconfig
            elif [ -e "${efiDir}/loader/loader.conf" ]; then                # UEFI + Systemd Boot
                echo -e "\e[0;33m UEFI + systemD boot, kein TODO\e[39m"
            else
                echo "--- Bootloader nicht erkennbar ---"
                # systemd boot: kein Eintrag, manueller Sprung in tty (bzw. dracut macht neues img?)
            fi


            echo -e "\n*** Snapper config '${snapperConfigName_root}' wird angepasst..."   # /etc/snapper/configs/CONFIGS (z.B. /etc/snapper/configs/root)
            # sudo snapper -c "${snapperConfigName_root}" set-config "ALLOW_USERS=${userid}"
            sudo snapper -c "${snapperConfigName_root}" set-config "ALLOW_GROUPS=wheel"
            sudo snapper -c "${snapperConfigName_root}" set-config "TIMELINE_CREATE=no"
            sudo snapper -c "${snapperConfigName_root}" set-config "TIMELINE_LIMIT_HOURLY=5"
            sudo snapper -c "${snapperConfigName_root}" set-config "TIMELINE_LIMIT_DAILY=7"
            sudo snapper -c "${snapperConfigName_root}" set-config "TIMELINE_LIMIT_WEEKLY=0"
            sudo snapper -c "${snapperConfigName_root}" set-config "TIMELINE_LIMIT_MONTHLY=0"
            sudo snapper -c "${snapperConfigName_root}" set-config "TIMELINE_LIMIT_YEARLY=0"
            

            echo -e "\n*** Zugriffs- und Besitzrechte für '${snapperSnapshotFolder}' werden festgelegt..."
            sudo chown -R :wheel "${snapperSnapshotFolder}" && sudo chmod -R 750 "${snapperSnapshotFolder}"

            # UEFI oder BIOS + GRUB    # systemd boot: kein Eintrag, manueller Sprung in tty, um auf best. snapshot zurückzusetzen
            # if [ -e "${efiDir}/grub.cfg" ] || [ -e "/boot/grub" ]; then    # Grub
            if [ -e "/boot/grub" ]; then    # Grub
                echo -e "\n*** Enable 'grub-btrfsd.service', 'snapper-cleanup.timer'..."
                sudo systemctl enable --now grub-btrfsd.service
                sudo systemctl enable --now snapper-cleanup.timer
            fi


            echo -e "\n*** Erstelle Hook für backup '/boot' (benötigt rsync)"
            echo "Installiere rsync, falls nicht vorhanden..."
            sudo pacman --needed --noconfirm -S rsync

            echo "Erstelle (kopiere nach) '/etc/pacman.d/hooks/95-bootbackup.hook'..."
            # SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)   # https://codefather.tech/blog/bash-get-script-directory/
            SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
            sudo mkdir -p /etc/pacman.d/hooks && \
            sudo cp "${SCRIPT_DIR}/95-bootbackup.hook" /etc/pacman.d/hooks/95-bootbackup.hook && \
            sudo chown root:root /etc/pacman.d/hooks/95-bootbackup.hook

            #if [ -e "/efi/loader/loader.conf" ]; then           # systemd Boot
            if [ -e "${efiDir}/loader/loader.conf" ]; then           # systemd Boot
                #echo -e "\n*** Erstelle Hook für backup '/efi' (benötigt rsync)"
                echo -e "\n*** Erstelle Hook für backup '${efiDir}' (benötigt rsync)"
                echo "Installiere rsync, falls nicht vorhanden..."
                sudo pacman --needed --noconfirm -S rsync
                echo "Erstelle (kopiere nach) '/etc/pacman.d/hooks/95-efibackup.hook'..."
                # SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)   # absolute path # https://codefather.tech/blog/bash-get-script-directory/
                SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")                    # relative path
                sudo mkdir -p /etc/pacman.d/hooks && \
                sudo cp "${SCRIPT_DIR}/95-efibackup.hook" /etc/pacman.d/hooks/95-efibackup.hook && \
                sudo chown root:root /etc/pacman.d/hooks/95-efibackup.hook
            fi


            echo -e "\n*** Erstelle snapshot (single) '***Base System Install***' und aktualisiere grub-boot Einträge"
            sudo snapper -c "${snapperConfigName_root}" create -d "***Base System Install***" && \
            echo "Aktuelle Liste der Snapshots:"
            sudo snapper ls

            #if [ -e "/boot/efi/grub.cfg" ] || [ -e "/boot/grub" ]; then     # GRUB (bei systemd Boot: kein Booteintrag, manuell in tty)
            if [ -e "${efiDir}/grub.cfg" ] || [ -e "/boot/grub" ]; then     # GRUB (bei systemd Boot: kein Booteintrag, manuell in tty)
                echo -e "\n*** Aktualisiere Grub"
                echo "Aktualisiere 'grub.cfg'"
                sudo grub-mkconfig -o /boot/grub/grub.cfg && \
                echo "(Re)Generiere Snapshots-(Sub)Menüeinträge in grub"
                sudo grub-mkconfig
            fi
        ;;

        *)
            echo -e "\e[0;33mFür verwendetes OS '${os}' wurde Installation/Konfiguration von 'snapper' noch nicht getestet."
            echo -e "Manuelle Durchführung notwendig\e[39m"
            read -r -p "Eingabe-Taste drücken um fortzufahren"
            exit 0
        ;;
    esac

    touch "/home/${userid}/.ansible_bootstrap_snapperGrub"   # wird auch bei default-switch - Zweig erstellt, d.h. snapper nicht konfiguriert (-> Manuelle Durchführung notwendig)

    echo -e  "*** Ende Snapper-Teil"
    echo     "*** ********************************************"
# else 
#     echo -e "\n'/' hat kein btrfs-Filesystem"
fi


### ---
### Installation initial benötigter Pakete und Services abhängig von Betriebssystem:
### ---

# ### distributionsspezifische Anpassungen:
case ${os} in
    Arch* | Endeavour*)
        if [ ! -f "/home/${userid}/.ansible_bootstrapMirrorPool" ]; then
            touch "/home/${userid}/.ansible_bootstrapMirrorPool"

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
                # Retrieve the latest mirror list from the Arch Linux Mirror Status page + listed countries: # (reflector conf: /etc/xdg/reflector/reflector.conf
                echo "reflector - aktualisiere archlinux mirrors..."
                sudo reflector --age 12 --protocol https --sort rate --country 'Germany,France,Austria,Switzerland,Sweden' --save /etc/pacman.d/mirrorlist
                sudo systemctl enable --now reflector.service
                # Update all packages on the system:    # (pacman conf: /etc/pacman.conf)
                sudo pacman -Syyu --noconfirm
            fi
        fi

        echo -e "\nInstallation initial benoetigte Software (git, ansible, openssh, ufw)..."
        sudo pacman -S --needed --noconfirm rsync git ansible openssh vim firewalld curl

        echo -e "\nInstallation benoetigte Softwarepackages zur Installation von AUR-Packages..."
        sudo pacman -S --needed --noconfirm base-devel

        echo -e "\nInstalling 'yay' - AUR helper..."
        sudo git clone https://aur.archlinux.org/yay.git /opt/yay
        sudo chown -R "${userid}":users /opt/yay
        cd /opt/yay && makepkg -si --needed && cd || return


        echo -e "\n Installation (wenn VM) spice agent for Linux guests (z.B. für clipboard sharing zwischen host+guest)"
        [[ $(systemd-detect-virt) != *"none"* ]] && sudo pacman -S --needed --noconfirm spice-vdagent

        echo -e "\nAktiviere Firewall 'firewalld' und erlaube ssh ..."
        sudo systemctl enable --now firewalld.service && sudo firewall-cmd --zone=public --add-service=ssh --permanent && sudo firewall-cmd --reload

        echo -e "\nStarte und aktiviere sshd.service..."
        sudo systemctl enable --now sshd.service

        echo -e "\nVM - Qemu/KVM: Wiki empfiehlt inst. von 'iptables-nft'"
        echo -e "Bestätige, dass 'iptables' (und 'inxi') gelöscht und 'iptables-nft' installiert wird"
        echo -e "Anmerkung: 'inxi' wird im Rahmen basis-inst wieder installiert"
        sudo pacman -S --needed iptables-nft
    ;;

    Ubuntu*)
        echo -e "\nUpdate Repos und Installation benoetigte Software (git,ansible,ssh,ufw,chrome-genome-shell)..."
        sudo apt-get update && sudo apt-get dist-upgrade -y && sudo apt-get install -y --show-progress rsync git ansible chrome-gnome-shell ssh ufw vim curl

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

        echo -e "\nDownload Visual Studio Code deb-file"
        if [ -f "/home/${userid}/Downloads/code.deb" ]; then
            echo "Datei '/home/${userid}/Downloads/code.deb' bereits vorhanden, Schritt wird übersprungen"
        else
            curl -L --create-file-mode 0755 -o "/home/${userid}/Downloads/code.deb" "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64"
        fi

        echo -e "\nDownload Installer-Skript for Pyenv"
        if [ -f "/home/${userid}/Downloads/pyenv-installer.sh" ]; then
            echo "Datei '/home/${userid}/Downloads/pyenv-installer.sh' bereits vorhanden, Schritt wird übersprungen"
        else
            curl -L --create-file-mode 0755 -o "/home/${userid}/Downloads/pyenv-installer.sh" "https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer"
            chmod +x "/home/${userid}/Downloads/pyenv-installer.sh"   # --create-file-mode hat nicht funktioniert
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
        sudo apt-get update && sudo apt-get dist-upgrade -y && sudo apt-get install -y --show-progress rsync git ansible chrome-gnome-shell openssh-client openssh-server ufw vim curl

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

        echo -e "\nDownload Visual Studio Code deb-file"
        if [ -f "/home/${userid}/Downloads/code.deb" ]; then
            echo "Datei '/home/${userid}/Downloads/code.deb' bereits vorhanden, Schritt wird übersprungen"
        else
            curl -L --create-file-mode 0755 -o "/home/${userid}/Downloads/code.deb" "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64"
        fi

        echo -e "\nDownload Installer-Skript for Pyenv"
        if [ -f "/home/${userid}/Downloads/pyenv-installer.sh" ]; then
            echo "Datei '/home/${userid}/Downloads/pyenv-installer.sh' bereits vorhanden, Schritt wird übersprungen"
        else
            curl -L --create-file-mode 0755 -o "/home/${userid}/Downloads/pyenv-installer.sh" "https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer"
            chmod +x "/home/${userid}/Downloads/pyenv-installer.sh"   # --create-file-mode hat nicht funktioniert
        fi

        echo -e "\nStarte + Aktiviere ssh ..."
        sudo systemclt start ssh && sudo systemctl enable ssh

        echo -e "\nAktiviere Firewall 'ufw' und erlaube ssh ..."
        sudo ufw enable && sudo ufw allow ssh comment 'SSH' && sudo ufw reload
    ;;

    *)
        echo "Unbehandelter Fall: switch os - default-switch Zweig"
        read -r -p "Eingabe-Taste drücken zum Beenden"
        exit 0
    ;;
esac


# ### Alle Systeme:

### ---
### Download 'Starship Shell Prompt' install-script
### ---
echo -e "\nDownload 'Starship Shell Prompt' install-script..."
curl -sS "https://starship.rs/install.sh" > "/home/${userid}/starship_install.sh" && chmod +x "/home/${userid}/starship_install.sh"


### ---
### Git-repo mit Ansible Playbook herunterladen (clone oder pull)
### ---
#echo -e "\nGit-repo mit Ansible Playbook herunterladen..."
#git clone "${gitOnlineRepo}"


### ---
### Test Ansbile Playbook
### ---
#echo ""
#read -rp "Soll TEST des Ansible-Playbooks durchgeführt werden (j/n)?: " testplay
#if [ "${testplay}" = 'j' ]; then
#    echo "Starte TEST des Playbooks ..."
#    ansible-playbook "/home/${userid}/${playbookdir}/${playbook}" -v --ask-become-pass --check
#    # bei verschlüsselten Daten z.B.:
#    #ansible-playbook "/home/${userid}/${playbookdir}/${playbook}" -v -K -C --vault-password-file "/home/${userid}/.ansibleVaultKey"
#else
#    echo "TEST des Playbooks wird NICHT durchgefürt"
#fi


echo -e "\nStarte Ansible-Playbook ..."
ansible-playbook "/home/${userid}/${playbookdir}/${playbook}" -v -K
# bei verschlüsselten Daten z.B.:
#ansible-playbook "/home/${userid}/${playbookdir}/${playbook}" -v -K --vault-password-file "/home/${userid}/.ansibleVaultKey"


case ${os} in
    Arch* | Endeavour*)
        ### ---
        ### weitere Installationen mit yay (Arch Linux, EndeavourOS)
        ### - an den Schluss gestellt, damit Playbookausführung nicht aufgehalten wird
        ### ---
        read -r -p "Install some predefined additonal software from AUR ? ('j'=ja, sonstige Eingabe: nein)" installAUR

        if [ "${installAUR}" == "j" ]; then
            echo -e "\nInstall 'autokey-gtk' from AUR..."          # da aktuell Gnome verwende
            yay -S --needed autokey-gtk && touch "/home/${userid}/.ansible_bootstrap_autokeyGtkInstalled"

            # echo -e "\nInstall 'autokey-qt' from AUR (Arch)"   # e.g. when using Plasma
            # yay -S --needed autokey-qt # && touch "/home/${userid}/.ansible_bootstrap_autokeyQtInstalled"

            echo -e "\nInstall some Gnome Extensions (gsconnect, dash-to-panel) from AUR ..."
            yay -S --needed gnome-shell-extension-gsconnect gnome-shell-extension-dash-to-panel

            echo -e "\nInstall several Packages (gtkhash, ttf-meslo-nerd-font (10k), units, vorta from AUR..."
            yay -S --needed gtkhash ttf-meslo-nerd-font-powerlevel10k units vorta 
            # bashdb   # A debugger for Bash scripts loosely modeled on the gdb command syntax

            echo -e "\nInstall Brave Browser from AUR..."
            yay -S --needed brave-bin

            echo -e "\nInstall ulauncher from AUR..."
            yay -S --needed ulauncher && touch "/home/${userid}/.ansible_bootstrap_severalAurPkgInstalled"

            echo -e "\nStart + enable ulauncher.service for '${userid}'..."
            systemctl --user enable --now ulauncher.service   # su -u "${userid}" -c "systemctl --user enable --now ulauncher.service"

            echo -e "\nInstall linux steam integration from AUR..."
            yay -S --needed linux-steam-integration

            echo -e "\nInstall Citrix Workspace App (icaclient) from AUR..."
            yay -S --needed icaclient && touch "/home/${userid}/.ansible_bootstrap_pamac-icaclientInstalled"

            echo -e "\nInstall 'btrfs-assistant' from AUR..."
            yay -S --needed btrfs-assistant && touch "/home/${userid}/.ansible_bootstrap_pamac-btrfsassistantInstalled"

            #echo -e "\nInstall Microsoft TTF Fonts from AUR..."
            #yay -S --needed ttf-ms-fonts && touch "/home/${userid}/.ansible_bootstrap_pamac-ttfmsfontsInstalled"

            #echo -e "\nInstall woeusb-ng (Tool to create Windows boot stick) from AUR..."  
            #yay -S --needed woeusb-ng && touch "/home/${userid}/.ansible_bootstrap_pamac-woeusbngInstalled"

            #echo -e "\nVM - Install virtio-win image from AUR..."
            #yay -S --needed virtio-win && touch "/home/${userid}/.ansible_bootstrap_pamac-vmVirtioWinInstalled"
        fi
    ;;

    *)
        echo -e "\nKeine abschließenden zusätzlichen Installationen definiert --- default switch (case os, final step)"
    ;;
esac

echo -e "\n\e[0;33mSkript beendet.\e[39m"
