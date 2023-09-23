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
repodir="ansible-install"           # local (-> git clone to /home/${userid}/${repodir}/${playbookdir})
playbookdir="ansible_workstation"   # github repo name
playbook="local.yml"

userid=$(whoami)   # or: userid=${USER}
githubUserid="sanmue"
defaultDomain="universalaccount.de"
defaultMail="${userid}@${defaultDomain}"

sshkeydir="/home/${userid}/.ssh"

gitOnlineRepo="git@github.com:${githubUserid}/${playbookdir}.git"
gitdefaultBranchName="main"
gitPagerStatus="true"   # (standard: true) # e.g.: 'git log', 'git diff' output goes to Pager, not terminal

os=""
oslist=("Ubuntu" "EndeavourOS" "ManjaroLinux" "openSUSE Tumbleweed")   # currently supportet distributions

bootloaderId='GRUB'   # or 'endeavouros', ...

if [ -e "/efi" ]; then
	efiDir="/efi"
elif [ -e "/boot/efi" ]; then   # deprecated location
	efiDir="/boot/efi"
else
	# echo "Bios boot mode, not in Uefi Boot mode"
	efiDir=""
fi

snapperConfigName_root="root"
snapperSnapshotFolder="/.snapshots"
# Manjaro: 'associative array' with additional subvolumes to be created (in addition to the already existing for '/', '/home', '/var/cache', '/var/log')
# - https://stackoverflow.com/questions/1494178/how-to-define-hash-tables-in-bash
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

btrfsFstabMountOptions_standard='defaults,noatime,compress=zstd,space_cache=v2 0 0'    # desired mountOptions for btrfs-filesystem
btrfsFstabMountOptions_manjaro='defaults 0 0'                                          # searchString; fstab-entry will be replaced with $btrfsFstabMountOptions_standard
btrfsFstabMountOptions_endeavour='defaults,noatime,compress=zstd 0 0'                  # searchString; fstab-entry will be replaced with $btrfsFstabMountOptions_standard


### ---
### Query used Operating System (OS)
### ---
if [ "$(hostnamectl)" ] ; then
    os=$(hostnamectl | grep "Operating System" | cut -d : -f 2 | xargs)
else
    echo "Command 'hostnamectl' not available, manual input of OS necessary."

    promptOk=false
    while [ ! "${promptOk}" = true ] ; do   #input-loop
        echo "Currently valid input/supported for OS: ${oslist[*]}"
        read -r -p "Enter name of your OS (exit program with 'x'): " os

        if [[ "${os}" == "x" ]] ; then
            exit 0
        fi

        if [[ ! "${oslist[*]}" =~ ${os} ]] ; then
            echo -e "Falsche Eingabe\n"
        else
            promptOk=true
            #echo "OS entered by you: ${os}"
        fi

    done
fi

echo "OS used: ${os}"


### ---
### Hostname
### ---
echo -e "\nCurrent hostname: '$(hostname)'"
read -r -p "Should hostname be changed ('y'=yes, other input=no)?: " changeHostname
if [ "${changeHostname}" = 'y' ]; then
    read -r -p "Enter new hostname: " newHostname
    sudo hostnamectl hostname "${newHostname}"
    read -r -p  "New hostname set, continue with any input"
fi


### ---
### Inst + config snapper
### ---
# https://unix.stackexchange.com/questions/34623/how-to-tell-what-type-of-filesystem-youre-on
# https://www.tecmint.com/find-linux-filesystem-type/
if [[ $(stat -f -c %T /) = 'btrfs' ]] && [[ ! -e "/home/${userid}/.ansible_bootstrap_snapperGrub" ]]; then   # prüfe '/' auf btrfs-filsystem;  -f, --file-system; -c, --format; %T - Type in human readable form
    read -r -p "Should 'snapper' (for snapshot creation) be installed/configured ('y'=yes, other input=no)?: " doSnapper
fi

if [[ "${doSnapper}" = 'y' ]]; then
    if [ ! -e "${snapperSnapshotFolder}" ]; then
        echo -e "\e[0;33mVerzeichnis '${snapperSnapshotFolder}' nicht vorhanden. Evlt. abweichendes Verzeichnis konfiguriert?!\nGgf. vorheriger manueller Eingriff erforderlich.\e[39m" 
        read -r -p "Installation/Konfiguration fortsetzen mit beliebiger Eingabe, Abbrechen mit <CTRL> + <c>"
    fi

    echo -e "\n*** ********************************************"
    echo      "*** Start: Installation und config von 'snapper'"
    case ${os} in
        EndeavourOS* | Manjaro*)        # aktuell für UEFI oder GRUB2 + Grub sowie für UEFI + systemd boot
            # https://wiki.archlinux.org/title/Btrfs
            # https://wiki.archlinux.org/title/Snapper
            # https://documentation.suse.com/sles/15-SP4/html/SLES-all/cha-snapper.html

            echo -e "\n*** Installation snapper+grub software packages..."
            sudo pacman --needed --noconfirm -S snapper snap-pac inotify-tools  # snap-sync

            #if [ -e "/boot/efi/grub.cfg" ] || [ -e "/boot/grub" ]; then         # GRUB (UEFI oder BIOS)
            if [ -e "${efiDir}/grub.cfg" ] || [ -e "/boot/grub" ]; then         # GRUB (UEFI oder BIOS)
                sudo pacman --needed --noconfirm -S grub-btrfs
            fi

            echo -e "\n*** (Re)create snapshots folder + snapper config..."
            # Archlinux | EndeavourOS | Manjaro:
            # - '/.snapshots' wird nicht standardmäßig erstellt
            # - bei Archlinux natürlich ggf. manuell gemacht
            #
            # Info: beim erstellen der config ${snapperConfigName_root} wird automatisch ein Subvolume '/.snapshots' erstellt, 
            # welches wieder gelöscht wird, da das Subvolume für Snapshots '@snapshots' heißen soll
            #
            if [ -e "${snapperSnapshotFolder}" ]; then   # falls bereits vorhanden
                echo "Unmount + Löschen '${snapperSnapshotFolder}', um angepasste Konfiguration durchzuführen..."
                sudo umount "${snapperSnapshotFolder}" && sudo rm -rf "${snapperSnapshotFolder}"
            fi

            echo "*** Erstelle snapper config '${snapperConfigName_root}' für '/'"
            sudo snapper -c "${snapperConfigName_root}" create-config /

            echo "*** Lösche autom. angelegtes Subvolume '${snapperSnapshotFolder}' (aus vorherigem Schritt 'Erstelle snapper config')..."
            sudo btrfs subvolume delete "${snapperSnapshotFolder}"

            echo "*** Erstelle (wieder) Verzeichnis '${snapperSnapshotFolder}'..."
            sudo sudo mkdir -p "${snapperSnapshotFolder}"


            echo "*** Erstelle Subvolumes (sofern nicht schon vorhanden) und entsprechende fstab-Einträge"
            echo "Aktuelle /etc/fstab:"
            cat /etc/fstab
            filesystemName=$(grep subvol=/@, /etc/fstab | cut -d ' ' -f 1 | xargs)   # z.B.: luks-8f1cf7bc-8064-422b-bd46-466438199874
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
            # Manjaro:
            echo -e "Ersetze ggf. fstab btrfs mount-option '...${btrfsFstabMountOptions_manjaro}' mit '...${btrfsFstabMountOptions_standard}'"
            sudo sed -i "s/${btrfsFstabMountOptions_manjaro}/${btrfsFstabMountOptions_standard}/g" /etc/fstab
            # Endeavour:
            echo -e "Ersetze ggf. fstab btrfs mount-option '...${btrfsFstabMountOptions_endeavour}' mit '...${btrfsFstabMountOptions_standard}'"
            sudo sed -i "s/${btrfsFstabMountOptions_endeavour}/${btrfsFstabMountOptions_standard}/g" /etc/fstab

            echo "Aktualisiere systemd units aus fstab + mount all..."
            sudo systemctl daemon-reload && sudo mount -a


            echo -e "\n*** Default-Subvolume festlegen"
            echo "aktuelles default-Subvolume für '/': $(sudo btrfs subvolume get-default /)"
            echo -e "Subvolume-Liste:\n$(sudo btrfs subvolume list /)"
            endloop='n'
            while [ ! "$endloop" = 'j' ]; do
                read -r -p "Bitte ID von @ eingeben (initial i.d.R. 256): " idRootSubvol
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
            elif [ -e "/boot/grub/grub.cfg" ]; then    # BIOS + Grub
                lsblk
                endloop='n'
                while [ ! "$endloop" = 'j' ]; do
                    read -r -p "Eingabe device-Pfad für grub-install (z.B. '/dev/vda'): " devGrubInstallPath    # nicht Partition (z.B. '/dev/vda1'), sondern Disk (z.B. '/dev/vda')
                    read -r -p "Ist '${devGrubInstallPath}' korrekt ('j'=ja, beliebige Eingabe für Korrektur)?: " endloop
                done
                # https://wiki.archlinux.org/title/GRUB#Installation_2
                # BIOS: grub-install --target=i386-pc /dev/sdX;
                # where i386-pc is deliberately used regardless of your actual architecture, and /dev/sdX is the disk (not a partition) where GRUB is to be installed.
                sudo grub-install --target=i386-pc "${devGrubInstallPath}" && sudo grub-mkconfig -o /boot/grub/grub.cfg && \
                sudo grub-mkconfig
            #elif [ -e "/efi/loader/loader.conf" ]; then    # UEFI + Systemd Boot
            elif [ -e "${efiDir}/loader/loader.conf" ]; then    # UEFI + Systemd Boot
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
                # SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)   # absolute path # https://codefather.tech/blog/bash-get-script-directory/ # absolute path
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

    touch "/home/${userid}/.ansible_bootstrap_snapperGrub"   # auch bei default-switch - Zweig (-> Manuelle Durchführung notwendig)

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
    Manjaro* | EndeavourOS*)
        if [ ! -f "/home/${userid}/.ansible_bootstrapMirrorPool" ]; then
            touch "/home/${userid}/.ansible_bootstrapMirrorPool"

            if [[ "${os}" = "Manjaro"* ]]; then
                echo -e "\nReset custom mirror list + customize mirror pool + full refresh of the package database and update all packages on the system..."
                # from listet countries:
                sudo pacman-mirrors -c all && sudo pacman-mirrors --method rank --country 'Germany,France,Austria,Switzerland,Sweden' && sudo pacman -Syyu --noconfirm
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
                # (reflector conf: /etc/xdg/reflector/reflector.conf
                echo "reflector - aktualisiere archlinux mirrors..."
                sudo reflector --age 12 --protocol https --sort rate --country 'Germany,France,Austria,Switzerland,Sweden' --save /etc/pacman.d/mirrorlist
                sudo systemctl enable --now reflector.service
                # Update all packages on the system:    # (pacman conf: /etc/pacman.conf)
                sudo pacman -Syyu --noconfirm
            fi
        fi

        echo -e "\nInstallation initial benoetigte Software (git, ansible, openssh, ufw)..."
        sudo pacman -S --needed --noconfirm rsync git ansible openssh vim yay firewalld curl

        # if [ "${os}" = "EndeavourOS" ]; then
            # echo -e "\nInstallation Archlinux, EndeavourOS: 'pamac-all'..."
            # if [ -f "/home/${userid}/.ansible_bootstrap_yay-pamacInstall" ]; then
            #     echo "pamac-all bereits installiert"
            # else
            #     yay -S --needed pamac-all && touch "/home/${userid}/.ansible_bootstrap_yay-pamacInstall"
            # fi
            # mit pamac ist (aktuell noch) es einfacher (automatisiert) mehrere (AUR)pakete ohne Nachfrage zu installieren 
            # (pamac build --no-confirm SW1 SW2 ...)
            # mit ansible modul pacman, executable yay + argumente (noch) nicht hingekriegt

            #echo -e "\nInstall 'snapd' from AUR (Archlinux, not Manjaro)"
            #if [ -f "/home/${userid}/.ansible_bootstrap_snapdAURInstalled" ]; then
            #    echo "snapd bereits installiert"
            #else
            #    yay -S --needed snapd && touch "/home/${userid}/.ansible_bootstrap_snapdAURInstalled"
            #fi
        # fi

        echo -e "\nInstallation benoetigte Softwarepackages zur Installation von AUR-Packages..."
        sudo pacman -S --needed --noconfirm base-devel

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

    openSUSE*)
        echo -e "\nUpdate Repos und Installation benoetigte Software (git,ansible,ssh,firewalld)..."
        sudo zypper refresh && sudo zypper dist-upgrade -y --details && sudo zypper install -y --details rsync git ansible openssh vim firewalld curl

        #echo -e "\nInstalliere benötigte Packages für Installation von Microsoft PowerShell"
        # https://learn.microsoft.com/en-us/powershell/scripting/install/install-other-linux?view=powershell-7.3
        # https://en.opensuse.org/PowerShell
        # PowerShell is not provided by any official openSUSE repositories. ...ways for Leap and Tumbleweed:
        # Möglichkeit 1: snap-package (https://snapcraft.io/install/powershell/opensuse)
        # Möglichkeit 2: Install directly from RPM; Install binaries from tar.gz; Install using "sudo dotnet tool install --global powershell" command

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


# ### Alle Systeme:

### ---
### Download 'Starship Shell Prompt' install-script
### ---
echo -e "\nDownload 'Starship Shell Prompt' install-script..."
curl -sS "https://starship.rs/install.sh" > "/home/${userid}/starship_install.sh" && chmod +x "/home/${userid}/starship_install.sh"

### ---
### Git Config
### ---
echo -e "\nErstelle git config mit Name '${userid}', Email '${defaultMail}' und defaultBranch '${gitdefaultBranchName}' ..."
git config --global user.name "${userid}"
git config --global user.email "${defaultMail}"
git config --global init.defaultBranch "${gitdefaultBranchName}"
git config --global pager.status "${gitPagerStatus}"
echo "Git-config ist nun:" 
#git config --list   #bei openSUSE wird auch dieser Befehl in Pager (less?) geöffnet
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
if [[ -n $(ls -I 'known_hosts' -I 'known_hosts.old' -I 'authorized_keys' "${sshkeydir}") ]] ; then   #einfacher Test; ggf. ssh-key für gitOnlineRepo trotzdem nicht vorhanden
    echo "SSH-Key - Verzeichnis '${sshkeydir}' enthält SSH-Keys."
else
    echo "SSH-Key - Verzeichnis '${sshkeydir}' scheint keine SSH-Keys zu enthalten."
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


case ${os} in
    Manjaro* | EndeavourOS*)
        ### ---
        ### Archlinux (EndeavourOS), Manjaro: weitere Installationen
        ### - am Schluss, damit Playbook nicht aufhalten
        ### ---
        read -r -p "Install from AUR: Citrix ICA-Client, autokey, virtio-win, MS TTF Fonts, ...? ('j'=ja, sonstige Eingabe: nein)" installAUR

        if [ "${installAUR}" == "j" ]; then
            echo -e "\nInstall 'autokey-gtk' from AUR (Arch)"   # da aktuell Gnome verwende
            yay -S --needed autokey-gtk && touch "/home/${userid}/.ansible_bootstrap_autokeyGtkInstalled"

            # echo -e "\nInstall 'autokey-qt' from AUR (Arch)"
            # yay -S --needed autokey-qt # && touch "/home/${userid}/.ansible_bootstrap_autokeyQtInstalled"

            echo -e "\nInstall several AUR Packages: gsconnect,dashtopanel,gtkhash,steam,ttf-meslo(10k),vorta,... (Arch, Manjaro)"
            yay -S --needed gnome-shell-extension-gsconnect gnome-shell-extension-dash-to-panel gtkhash linux-steam-integration ttf-meslo-nerd-font-powerlevel10k units vorta
            if [[ ${os} = *"Endeavour"* ]]; then   # bei Manjaro bereits im Playbook installiert (da in dessen repo drin)
                yay -S --needed brave-bin
            fi
            echo -e "\nInstall ulauncher from AUR (Arch,Manjaro)"
            yay -S --needed ulauncher
            # 'flag'-file:
            touch "/home/${userid}/.ansible_bootstrap_severalAurPkgInstalled"

            echo -e "\nStart + enable ulauncher.service für '${userid}'"
            #su -u "${userid}" -c "systemctl --user enable --now ulauncher.service"
            systemctl --user enable --now ulauncher.service

            echo -e "\nInstall Citrix Workspace App (icaclient) from AUR (Arch,Manjaro)"
            #pamac build icaclient && touch "/home/${userid}/.ansible_bootstrap_pamac-icaclientInstalled"
            yay -S --needed icaclient && touch "/home/${userid}/.ansible_bootstrap_pamac-icaclientInstalled"

            echo -e "\nInstall 'btrfs-assistant' from AUR (Archlinux; bei Manjaro (sollte) schon installiert (sein))"
            yay -S --needed btrfs-assistant && touch "/home/${userid}/.ansible_bootstrap_pamac-btrfsassistantInstalled"

            echo -e "\nVM - Install virtio-win image from AUR (Arch,Manjaro))"
            yay -S --needed virtio-win && touch "/home/${userid}/.ansible_bootstrap_pamac-vmVirtioWinInstalled"

            echo -e "\nInstall Microsoft TTF Fonts from AUR (Arch,Manjaro))"
            yay -S --needed ttf-ms-fonts && touch "/home/${userid}/.ansible_bootstrap_pamac-ttfmsfontsInstalled"

            #echo -e "\nInstall woeusb-ng (Tool to create Windows boot stick) from AUR (Arch,Manjaro)"  
            #yay -S --needed woeusb-ng && touch "/home/${userid}/.ansible_bootstrap_pamac-woeusbngInstalled"
        fi
    ;;

    *)
        echo -e "\nDefault-switch Zweig - keine zusätzlichen Installationen nach Ausführung Ansible Playbook."
        read -r -p "Eingabe-Taste drücken zum Beenden"
        exit 0
    ;;
esac
