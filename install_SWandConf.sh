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
oslist=("Arch Linux" "EndeavourOS" "Ubuntu")   # currently supportet distributions
currentHostname=$(hostname)
bootloaderId='GRUB'   # or 'endeavouros', ...

if [ -e "/efi" ]; then          # Uefi - EFI path
	efiDir="/efi"
elif [ -e "/boot/efi" ]; then   # Uefi - EFI path (deprecated location)
	efiDir="/boot/efi"
else                            # Bios
	# echo "Bios boot mode"
	efiDir="/no/efi/dir/available"
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

deleteOldRootInFstab="false"    # default: "false", may be modified later in the script
                                # if Sytem was initially installed without speacial btrfs subvolume layout -> e.g.: "UUID=8a6bb50a-... / btrfs rw,noatime,...,subvolid=5,subvol=/ 0 0"

### ---
### Check Operating System (OS)
### ---
os=$(grep -e "^NAME=" /etc/os-release | cut -d '"' -f 2 | xargs)
echo -e "\n\e[0;33mCurrent OS:\e[39m ${os}"

supportedOS="false"
for osname in "${oslist[@]}"; do
    if [ "${os}" = "${osname}" ]; then
        supportedOS="true"
    fi
done
if [ "${supportedOS}" = "false" ]; then 
    echo -e "\e[0;31mSorry, your OS '${os}' is not supported. Script/Playbook won't work for you.\e[39m"
    echo "Skript will exit here :-("
    exit 1
fi


### ---
### Hostname
### ---
echo -e "\e[0;33mCurrent hostname:\e[39m '${currentHostname}'"
read -r -p "  |_ Change hostname? ('y'=yes, other input=no): " changeHostname
if [ "${changeHostname}" = 'y' ]; then
    read -r -p "     Enter new hostname: " newHostname
    sudo hostnamectl hostname "${newHostname}"
    sudo sed -i "s/${currentHostname}/${newHostname}/g" /etc/hosts
    echo "     Hostname set to '${newHostname}'"
fi


### ---
### Inst + config snapper
### ---

# check filesystem type + aks if snapper should be installed:
if [[ $(stat -f -c %T /) = 'btrfs' ]] && [[ ! -e "/home/${userid}/.ansible_installScript_snapperGrub" ]]; then   # prüfe '/' auf btrfs filesystem;  -f, --file-system; -c, --format; %T - Type in human readable form (e.g. 'btrfs', 'ext4', ...)
    echo -e "\n\e[0;33mSystem snapshots\e[39m"
    read -r -p "Install + configure 'snapper'? ('y' = yes, other input = no): " doSnapper
fi

if [[ "${doSnapper}" = 'y' ]]; then
    # --- START check fstab + set file system name ----------------------------
    # Script only works if btrfs subvolumes are already created (e.g. recommended subvolume layout, with subvolumes: '@', '@home', ...)
    # therefore checking fstab: - for btrfs root subvolume '@/'
    #                           - '<file system>' part will be used later for creating new fstab entries for subvolumes (see further below)

    fstabEntryBtrfsRootSubvol=$(grep -e "subvol=/@[^a-zA-Z]" /etc/fstab)    # btrfs subvolumes already created + mounted (+ encryption)
                                                                            # e.g.: "/dev/mapper/luks-7bee452d-... / btrfs subvol=/@,defaults,... 0 0" or: "UUID=luks-8f1cf7bc-8064-...   / btrfs subvol=/@,defaults,... 0 0"

    # if the above grep did not return a match, its perhaps because of no (recommended) btrfs subvolume layout has been created (-> e.g. no subvolumes: '@', '@home', ...):
    if [ -z "${fstabEntryBtrfsRootSubvol}" ]; then                                      # "default" btrfs root '/' without (recommended) subvolumes: "initial" entry still in fstab
        echo "Aktuelle /etc/fstab:"
        cat /etc/fstab

        # --- START #TODO: aktuell nicht implementiert 
        # fstabFileSystem=$(grep -w "subvol=/" /etc/fstab | cut -f 1 | xargs)           # e.g.: "UUID=8a6bb50a-11d3-4aff-bba9-e7234a9228c5 / btrfs rw,noatime,...,subvolid=5,subvol=/ 0 0"
                                                                                        #       - can occur: standard install with btrfs, but without specifying (recommended) subvolume layout # '...subvolid=5,subvol=/...' is default entry for btrfs root subvolume
        # --- ENDE aktuell nicht implementiert
        deleteOldRootInFstab="true"                                                     # marker, that this fstab entry has to be erased (or we will have 2 entries for '/' in fstab later)

        echo -e "\e[0;31mEs muss schon ein btrfs subvolume layout vorhanden sein, damit dieses Script funkiontiert.\e[39m"
        echo -e "\e[0;31mManuelle Durchführung erforderlich. Sorry, Ende.\e[39m"
        exit 1
    fi

    case ${fstabEntryBtrfsRootSubvol} in
        /dev*)                                                                                  # /dev/mapper/luks-cc2e4215-6edc-41c8-9b03-d478bee0a61c / btrfs subvol=/@,defaults,noatime,compress=zstd 0 0'
                                                                                                # e.g. EndeavourOS + luks encryption
            fstabFileSystem=$(echo "${fstabEntryBtrfsRootSubvol}" | cut -d ' ' -f 1 | xargs)    # /dev/mapper/luks-cc2e4215-6edc-41c8-9b03-d478bee0a61c
        ;;

        UUID*)                                                                                  # UUID=luks-8f1cf7bc-8064-...   / btrfs subvol=/@,defaults,... 0 0
            fstabFileSystem=$(echo "${fstabEntryBtrfsRootSubvol}" | cut -f 1 | xargs)           # UUID=luks-8f1cf7bc-8064-...
            if [ -z "${fstabFileSystem}" ]; then fstabFileSystem=$(echo "${fstabEntryBtrfsRootSubvol}" | cut -d ' ' -f 1 | xargs); fi
        ;;

        *)
            fstabFileSystem=$(echo "${fstabEntryBtrfsRootSubvol}" | cut -d ' ' -f 1 | xargs)
            echo -e "\e[0;31mDefault case 'fstabEntryBtrfsRootSubvol': fstab file system name could not be defined clearly.\e[39m"
        ;;
    esac

    echo -e "\e[0;33mSetting fstab file system name to\e[39m '${fstabFileSystem}' \e[0;33mfor now.\nYou can correct this later manually when prompted for confirmation.\e[39m"
    # --- END check fstab + set file system name ------------------------------


    if [ ! -e "${snapperSnapshotFolder}" ]; then                                    # check if ${snapperSnapshotFolder} exists
        echo -e "\e[0;33m- Verzeichnis '${snapperSnapshotFolder}' nicht vorhanden. Evlt. abweichendes Verzeichnis konfiguriert?!\n- Ggf. vorheriger manueller Eingriff erforderlich.\e[39m"
        echo "Current btrfs subvolume list:"
        sudo btrfs subvolume list /
        read -r -p "Installation/Konfiguration fortsetzen? (beliebige Eingabe = ja, 'n' = nein): " continueScript
        if [ "${continueScript}" = "n" ]; then
            echo "Stopping Script"
            exit 0
        fi
    fi

    echo -e "\n\e[0;33m*** ********************************************\e[39m"
    echo -e   "\e[0;33m*** Start: Installation und config von 'snapper'\e[39m"
    case ${os} in
        Arch* | Endeavour*)        # aktuell für UEFI oder BIOS jeweils mit GRUB-Bootloader (TODO: sowie für UEFI + systemd boot -> not (re-)tested)
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

            echo "*** Lösche autom. angelegtes Subvolume '${snapperSnapshotFolder}' (aus vorherigem Schritt 'Erstelle snapper config')..."
            sudo btrfs subvolume delete "${snapperSnapshotFolder}"
            echo "*** Erstelle (wieder) Verzeichnis '${snapperSnapshotFolder}'..."
            sudo sudo mkdir -p "${snapperSnapshotFolder}"

            echo "*** Erstelle Subvolumes (sofern nicht schon vorhanden) und entsprechende fstab-Einträge"
            echo "Aktuelle /etc/fstab:"
            cat /etc/fstab

            read -r -p "Nutze file system '${fstabFileSystem}'. Ist das korrekt ? ('n'=nein, sonstige Eingabe=ja): " fsok
            if [ "${fsok}" = "n" ]; then
                endloop='no'
                while [ ! "$endloop" = 'j' ]; do
                    read -r -p "Manuelle Eingabe: " fstabFileSystem
                    read -r -p "Ist '${fstabFileSystem}' korrekt ? ('j'=ja, beliebige Eingabe für Korrektur): " endloop
                done
            fi

            sudo cp /etc/fstab /etc/fstab.bak                                           # Sicherung fstab
            echo -e "\nMount: 'subvolid=5' '${fstabFileSystem}' nach '/mnt'..."
            sudo mount -t btrfs -o subvolid=5 "$fstabFileSystem" /mnt                    # bzw. sudo mount -t btrfs -o "$btrfsFstabMountOptions_standard" /dev/vda3 /mnt

            for subvol in "${!btrfsSubvolLayout[@]}"; do
                if [ ! -e "/mnt/${subvol}" ]; then                                      # wenn Subvolume noch nicht vorhanden
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

                if [ ! -e  "${btrfsSubvolLayout[${subvol}]}" ]; then                        # wenn Mount-Ziel (Verzeichnis) noch nicht vorhanden
                    echo -e "\e[0;33m    |__ Mount-Ziel '${btrfsSubvolLayout[${subvol}]}' nicht vorhanden, Verzeichnis wird erstellt...\e[39m"
                    sudo mkdir -p "${btrfsSubvolLayout[${subvol}]}"
                fi

                if [[ $(grep "subvol=/${subvol}," /etc/fstab) ]]; then                      # wenn Eintrag für z.B. ...'subvol=/@,'... bereits vorhanden
                    echo -e "\e[0;33m    |__ Eintrag für Subvolume '${subvol}' bereits vorhanden, ggf. prüfen/korrigieren\e[39m"
                    subvolInFstab='true'
                fi

                if [[ $(grep -E " +${btrfsSubvolLayout[${subvol}]} +" /etc/fstab) ]]; then  # wenn Mount Point (z.B. für '/') bereits vorhanden
                    echo -e "\e[0;33m    |__ Mount-Ziel '${btrfsSubvolLayout[${subvol}]}' bereits vorhanden, '${subvol}' wird nicht (nochmal) hinterlegt, ggf. prüfen/korrigieren\e[39m"
                    mountPointInFstab='true'
                fi

                if [ "${subvolInFstab}" = 'false' ] && [ "${mountPointInFstab}" = 'false' ]; then
                    echo "${fstabFileSystem} ${btrfsSubvolLayout[${subvol}]} btrfs subvol=/${subvol},${btrfsFstabMountOptions_standard}" | sudo tee -a /etc/fstab
                fi
            done

            if [ "${deleteOldRootInFstab}" = "true" ]; then
                sudo sed -i "/subvolid=5,subvol=\//d" /etc/fstab                            # delete the line containing 'subvolid=5,subvol=/'
            fi

            if [[ "${os}" = "Endeavour*" ]]; then
                echo -e "\nErsetze/korrigiere ggf. mount-options in '/etc/fstab':"
                echo -e "Ersetze ggf. fstab btrfs mount-option (Endeavour)'...${btrfsFstabMountOptions_endeavour}' mit '...${btrfsFstabMountOptions_standard}'"
                sudo sed -i "s/${btrfsFstabMountOptions_endeavour}/${btrfsFstabMountOptions_standard}/g" /etc/fstab
            fi

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
            if [ -e "${efiDir}/grub.cfg" ] || [ -e "/boot/grub" ]; then      # GRUB (bei systemd Boot: kein Booteintrag, manuell in tty)
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
            touch "/home/${userid}/.ansible_installScript_snapper_NOT-DONE"
            read -r -p "Eingabe-Taste drücken um fortzufahren"
            exit 0
        ;;
    esac

    touch "/home/${userid}/.ansible_installScript_snapperGrub"   # wird auch bei default-switch - Zweig erstellt, d.h. snapper nicht konfiguriert (-> Manuelle Durchführung notwendig)

    echo -e "\e[0;33m*** Ende Snapper-Teil\e[39m"
    echo -e "\e[0;33m*** ********************************************\e[39m"
# else 
#     echo -e "\n'/' hat kein btrfs-Filesystem"
fi


### ---
### Installation initial benötigter Pakete und Services abhängig von Betriebssystem:
### ---

# ### distributionsspezifische Anpassungen:
case ${os} in
    Arch* | Endeavour*)
        if [ ! -f "/home/${userid}/.ansible_installScript_MirrorPool" ]; then
            touch "/home/${userid}/.ansible_installScript_MirrorPool"

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

        echo -e "\nInstallation initial benoetigte Software (git, ansible, openssh, vi, firewalld, )..."
        sudo pacman -S --needed --noconfirm rsync git ansible-core ansible openssh vim firewalld curl

        echo -e "\nInstallation benoetigte Softwarepackages zur Installation von AUR helpers, AUR-Packages..."
        sudo pacman -S --needed --noconfirm base-devel

        echo -e "\nInstalling 'yay' - AUR helper..."
        sudo git clone https://aur.archlinux.org/yay.git /opt/yay
        sudo chown -R "${userid}":users /opt/yay
        cd /opt/yay && makepkg -si --needed && cd || return

        echo -e "\nInstalling 'paru' - AUR helper..."
        sudo git clone https://aur.archlinux.org/paru.git /opt/paru
        sudo chown -R "${userid}":users /opt/paru
        cd /opt/paru && makepkg -si --needed && cd || return

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

echo -e "\nStarte Ansible-Playbook ...\n"
echo -e "\e[0;33m### Info\e[39m"
echo -e "\e[0;33m#   - If you encounter a problem/error while executing the playbook (e.g. with pip / python, ...)\e[39m"
echo -e "\e[0;33m#     logout + login and start the script / playbook again (for other errors a reboot may be needed)\e[39m"
echo -e "\e[0;33m#   - If VS Code (Code OSS) opens you can simply close it again or leave it open until script is finished\e[39m"
echo -e "\e[0;33m###\e[39m\n"

ansible-playbook "/home/${userid}/${playbookdir}/${playbook}" -v -K
# bei verschlüsselten Daten z.B.:
#ansible-playbook "/home/${userid}/${playbookdir}/${playbook}" -v -K --vault-password-file "/home/${userid}/.ansibleVaultKey"


case ${os} in
    Arch* | Endeavour*)
        ### ---
        ### weitere Installationen mit yay (Arch Linux, EndeavourOS)
        ### - an den Schluss gestellt, damit Playbookausführung nicht aufgehalten wird
        ### ---
        read -r -p "Install some predefined additonal software from AUR ? ('j'=ja, sonstige Eingabe: nein): " installAUR

        if [ "${installAUR}" == "j" ]; then
            echo -e "\nInstall some Gnome Extensions (gsconnect, dash-to-panel) from AUR ..."
            yay -S --needed gnome-shell-extension-gsconnect gnome-shell-extension-dash-to-panel

            echo -e "\nInstall several Packages (bashdb, gtkhash, ttf-meslo-nerd-font (10k), units) from AUR..."
            yay -S --needed bashdb gtkhash ttf-meslo-nerd-font-powerlevel10k units    # bashdb: # A debugger for Bash scripts loosely modeled on the gdb command syntax

            #echo -e "\nInstall several Applications (Vorta) from AUR..."
            #yay -S --needed vorta joplin-desktop   # -> flatpak

            #echo -e "\nInstall Brave Browser from AUR..."
            #yay -S --needed brave-bin  # -> flatpak

            echo -e "\nInstall linux steam integration from AUR..."
            yay -S --needed linux-steam-integration

            echo -e "\nInstall ulauncher from AUR..."
            yay -S --needed ulauncher
            echo -e "\nStart + enable ulauncher.service for '${userid}'..."
            systemctl --user enable --now ulauncher.service         # su -u "${userid}" -c "systemctl --user enable --now ulauncher.service"

            #lsblkBtrfs=$(lsblk -P -o +FSTYPE | grep "btrfs")   # $(blkid | grep btrfs) # $(mount | grep "^/dev" | grep btrfs)  # $(grep btrfs /etc/fstab)
            #if [ -n "${lsblkBtrfs}" ]; then
            if [[ $(stat -f -c %T /) = 'btrfs' ]]; then
                echo -e "\nInstall 'btrfs-assistant' from AUR..."
                yay -S --needed btrfs-assistant && touch "/home/${userid}/.ansible_installScript_AUR-btrfsassistantInstalled"
            fi

            echo -e "\nInstall espanso (wayland) + espanso-gui from AUR..."
            yay -S --needed espanso-wayland espanso-gui

            echo -e "\nInstall Citrix Workspace App (icaclient) from AUR..."
            yay -S icaclient && touch "/home/${userid}/.ansible_installScript_AUR-icaclientInstalled" && mkdir -p "/home/${userid}/.ICAClient/cache" && \
            sudo rsync -aPhEv /opt/Citrix/ICAClient/config/{All_Regions,Trusted_Region,Unknown_Region,canonicalization,regions}.ini "/home/${userid}/.ICAClient/"

            echo -e "\nCreating flag-file '.ansible_installScript_severalAurPkgInstalled'..."
            touch "/home/${userid}/.ansible_installScript_severalAurPkgInstalled"

            #echo -e "\nInstall Microsoft TTF Fonts from AUR..."
            #yay -S --needed ttf-ms-fonts && touch "/home/${userid}/.ansible_installScript_AUR-ttfmsfontsInstalled"

            # --- 'autokey' auskommentiert, da nicht mit Wayland funktioniert --- #
            # echo -e "\nInstall 'autokey-gtk' from AUR..."         # da aktuell Gnome verwende
            # yay -S --needed autokey-gtk && touch "/home/${userid}/.ansible_installScript_autokeyGtkInstalled"
            # echo -e "\nInstall 'autokey-qt' from AUR (Arch)"      # e.g. when using Plasma
            # yay -S --needed autokey-qt # && touch "/home/${userid}/.ansible_installScript_autokeyQtInstalled"

            #echo -e "\nInstall woeusb-ng (Tool to create Windows boot stick) from AUR..."  
            #yay -S --needed woeusb-ng && touch "/home/${userid}/.ansible_installScript_AUR-woeusbngInstalled"

            #echo -e "\nVM - Install virtio-win image from AUR..."
            #yay -S --needed virtio-win && touch "/home/${userid}/.ansible_installScript_AUR-vmVirtioWinInstalled"
        fi
    ;;

    *)
        echo -e "\nNo final additional installations defined --- default switch (case os, final step)"
    ;;
esac

echo -e "\n\e[0;33mScript finished.\e[39m"
