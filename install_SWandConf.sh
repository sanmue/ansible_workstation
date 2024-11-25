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
playbookdir="ansible_workstation" # also repo name
playbook="local.yml"
userid=$(whoami)                                       # or: userid=${USER}
oslist=("Arch Linux" "EndeavourOS" "Debian GNU/Linux") # currently supported distributions
# currentHostname=$(hostname) # command not available in arch (anymore); net-tool (deprecated) or inetutils not installed by default
# currentHostname=$(cat /etc/hostname)
currentHostname=$(hostnamectl hostname) # only systemd
bootloaderId='GRUB'                     # or 'endeavouros', ...

if [ "$(ls "/efi")" ]; then # Uefi - EFI path
    efiDir="/efi"
elif [ "$(ls "/boot/efi")" ]; then # Uefi - EFI path (deprecated location)
    efiDir="/boot/efi"
else # Bios
    # echo "Bios boot mode"
    efiDir="/no/efi/dir/available"
fi

snapperConfigName_root="root"
snapperSnapshotFolder="/.snapshots"
declare -A btrfsSubvolLayout=(
    ["@"]="/"
    ["@snapshots"]="${snapperSnapshotFolder}"
    ["@home"]="/home"
    ["@opt"]="/opt"
    ["@srv"]="/srv"
    ["@tmp"]="/tmp"
    ["@usrlocal"]="/usr/local"
    ["@varcache"]="/var/cache"
    ["@varlibclamav"]="/var/lib/clamav"
    ["@varlibflatpak"]="/var/lib/flatpak"
    ["@varlibdocker"]="/var/lib/docker"
    ["@varlibvirtimages"]="/var/lib/libvirt/images"
    ["@varlibmachines"]="/var/lib/machines"
    ["@varlibportables"]="/var/lib/portables"
    ["@varlog"]="/var/log"
    ["@varopt"]="/var/opt"
    ["@varspool"]="/var/spool"
    ["@vartmp"]="/var/tmp")

btrfsFstabMountOptions_standard='noatime,compress=zstd:3,space_cache=v2 0 0' # desired mountOptions for btrfs-filesystem
btrfsFstabMountOptions_endeavour='noatime,compress=zstd 0 0'                 # searchString; fstab-entry will be replaced with $btrfsFstabMountOptions_standard
# SSD TRIM: discard=asyncis enabled by default as of linux 6.2
# - https://wiki.archlinux.org/title/Btrfs#SSD_TRIM
# - https://wiki.archlinux.org/title/Dm-crypt/Specialties#Discard/TRIM_support_for_solid_state_drives_(SSD)
#   - Solid state drive users should be aware that, by default, TRIM commands are not enabled by the device-mapper, i.e. block-devices are mounted without the discard option unless you override the default.
# - https://wiki.archlinux.org/title/Solid_state_drive#TRIM
#   - dm-crypt (https://wiki.archlinux.org/title/Solid_state_drive#dm-crypt): ... but has security implications
#   - https://lore.kernel.org/linux-raid/508FA2C6.2050800@hesbynett.no/
# - https://unix.stackexchange.com/a/465413: # disable: with 'nodiscard' mount option

deleteOldRootInFstab="false" # default: "false", may be modified later in the script
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

    if [[ ! $(grep sudo /etc/group) = *"${userid}"* ]]; then # if user not in sudo group
        su -l root --command "hostnamectl hostname ${newHostname}"
        su -l root --command "sed -i 's/${currentHostname}/${newHostname}/g' /etc/hosts"
    else
        sudo hostnamectl hostname "${newHostname}"
        sudo sed -i "s/${currentHostname}/${newHostname}/g" /etc/hosts
    fi
    echo "     Hostname set to '${newHostname}'"
fi

### ---
### Inst + config snapper
### ---

# check filesystem type + aks if snapper should be installed:
if [[ $(stat -f -c %T /) = 'btrfs' ]] && [[ ! -e "/home/${userid}/.ansible_installScript_snapperGrub" ]]; then # prüfe '/' auf btrfs filesystem;  -f, --file-system; -c, --format; %T - Type in human readable form (e.g. 'btrfs', 'ext4', ...)
    echo -e "\n\e[0;33mSystem snapshots\e[39m"
    read -r -p "Install + configure 'snapper'? ('y' = yes, other input = no): " doSnapper
fi

if [[ "${doSnapper}" = 'y' ]]; then
    # --- START check fstab + set file system name ----------------------------
    # Script only works if btrfs subvolumes are already created (e.g. recommended subvolume layout, with subvolumes: '@', '@home', ...)
    # therefore checking fstab: - for btrfs root subvolume '@/'
    #                           - '<file system>' part will be used later for creating new fstab entries for subvolumes (see further below)

    fstabEntryBtrfsRootSubvol=$(grep -e "subvol=/@[^a-zA-Z]" /etc/fstab) # btrfs subvolumes already created + mounted (+ encryption)
    # e.g.: "/dev/mapper/luks-7bee452d-... / btrfs subvol=/@,defaults,... 0 0" or: "UUID=luks-8f1cf7bc-8064-...   / btrfs subvol=/@,defaults,... 0 0"

    # if the above grep did not return a match, its perhaps because of no (recommended) btrfs subvolume layout has been created (-> e.g. no subvolumes: '@', '@home', ...):
    if [ -z "${fstabEntryBtrfsRootSubvol}" ]; then # "default" btrfs root '/' without (recommended) subvolumes: "initial" entry still in fstab
        echo "Aktuelle /etc/fstab:"
        cat /etc/fstab

        # --- START #TODO: aktuell nicht implementiert
        # fstabFileSystem=$(grep -w "subvol=/" /etc/fstab | cut -f 1 | xargs)           # e.g.: "UUID=8a6bb50a-11d3-4aff-bba9-e7234a9228c5 / btrfs rw,noatime,...,subvolid=5,subvol=/ 0 0"
        #       - can occur: standard install with btrfs, but without specifying (recommended) subvolume layout # '...subvolid=5,subvol=/...' is default entry for btrfs root subvolume
        # --- ENDE aktuell nicht implementiert
        deleteOldRootInFstab="true" # marker, that this fstab entry has to be erased (or we will have 2 entries for '/' in fstab later)

        echo -e "\e[0;31mEs muss schon ein btrfs subvolume layout vorhanden sein, damit dieses Script funkiontiert.\e[39m"
        echo -e "\e[0;31mManuelle Durchführung erforderlich. Sorry, Ende.\e[39m"
        exit 1
    fi

    case ${fstabEntryBtrfsRootSubvol} in
    /dev*) # /dev/mapper/luks-cc2e4215-6edc-41c8-9b03-d478bee0a61c / btrfs subvol=/@,defaults,noatime,compress=zstd 0 0'
        # e.g. EndeavourOS + luks encryption
        fstabFileSystem=$(echo "${fstabEntryBtrfsRootSubvol}" | cut -d ' ' -f 1 | xargs) # /dev/mapper/luks-cc2e4215-6edc-41c8-9b03-d478bee0a61c
        ;;

    UUID*)                                                                        # UUID=luks-8f1cf7bc-8064-...   / btrfs subvol=/@,defaults,... 0 0
        fstabFileSystem=$(echo "${fstabEntryBtrfsRootSubvol}" | cut -f 1 | xargs) # UUID=luks-8f1cf7bc-8064-...
        if [ -z "${fstabFileSystem}" ]; then fstabFileSystem=$(echo "${fstabEntryBtrfsRootSubvol}" | cut -d ' ' -f 1 | xargs); fi
        ;;

    *)
        fstabFileSystem=$(echo "${fstabEntryBtrfsRootSubvol}" | cut -d ' ' -f 1 | xargs)
        echo -e "\e[0;31mDefault case 'fstabEntryBtrfsRootSubvol': fstab file system name could not be defined clearly.\e[39m"
        ;;
    esac

    echo -e "\e[0;33mSetting fstab file system name to\e[39m '${fstabFileSystem}' \e[0;33mfor now.\nYou can correct this later manually when prompted for confirmation.\e[39m"
    # --- END check fstab + set file system name ------------------------------

    if [ ! -e "${snapperSnapshotFolder}" ]; then # check if ${snapperSnapshotFolder} exists
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
    echo -e "\e[0;33m*** Start: Installation und config von 'snapper'\e[39m"
    case ${os} in
    Arch* | Endeavour*) # aktuell für UEFI oder BIOS jeweils mit GRUB-Bootloader (TODO: sowie für UEFI + systemd boot -> not (re-)tested)
        # https://wiki.archlinux.org/title/Btrfs
        # https://wiki.archlinux.org/title/Snapper
        # https://documentation.suse.com/sles/15-SP4/html/SLES-all/cha-snapper.html

        echo -e "\n*** Installation snapper+grub software packages..."
        sudo pacman --needed --noconfirm -S snapper snap-pac inotify-tools # snap-sync

        if [ -e "${efiDir}/grub.cfg" ] || [ -e "/boot/grub" ]; then # GRUB (UEFI oder BIOS)
            sudo pacman --needed --noconfirm -S grub-btrfs
        fi

        echo -e "\n*** (Re)create snapshots folder + snapper config..."
        # Arch Linux | EndeavourOS:
        # - '/.snapshots' wird nicht standardmäßig erstellt
        #
        # Info: beim erstellen der config ${snapperConfigName_root} wird automatisch ein Subvolume (und damit Verzeichnis) '.snapshots' auf '/' erstellt
        # welches wieder gelöscht wird, da das Subvolume für Snapshots '@snapshots' heißen soll
        #
        if [ -e "${snapperSnapshotFolder}" ]; then # falls bereits vorhanden
            echo "Unmount + Löschen '${snapperSnapshotFolder}', um angepasste Konfiguration durchzuführen..."
            sudo umount "${snapperSnapshotFolder}"
            sudo rm -rf "${snapperSnapshotFolder}" # entspricht löschen subvolume
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

        sudo cp /etc/fstab /etc/fstab.bak # Sicherung fstab
        echo -e "\nMount: 'subvolid=5' '${fstabFileSystem}' nach '/mnt'..."
        sudo mount -t btrfs -o subvolid=5 "$fstabFileSystem" /mnt # bzw. sudo mount -t btrfs -o "$btrfsFstabMountOptions_standard" /dev/vda3 /mnt

        for subvol in "${!btrfsSubvolLayout[@]}"; do
            if [ ! -e "/mnt/${subvol}" ]; then # wenn Subvolume noch nicht vorhanden
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

            if [ ! -e "${btrfsSubvolLayout[${subvol}]}" ]; then # wenn Mount-Ziel (Verzeichnis) noch nicht vorhanden
                echo -e "\e[0;33m    |__ Mount-Ziel '${btrfsSubvolLayout[${subvol}]}' nicht vorhanden, Verzeichnis wird erstellt...\e[39m"
                sudo mkdir -p "${btrfsSubvolLayout[${subvol}]}"
            fi

            if [[ $(grep "subvol=/${subvol}," /etc/fstab) ]]; then # wenn Eintrag für z.B. ...'subvol=/@,'... bereits vorhanden
                echo -e "\e[0;33m    |__ Eintrag für Subvolume '${subvol}' bereits vorhanden, ggf. prüfen/korrigieren\e[39m"
                subvolInFstab='true'
            fi

            if [[ $(grep -E " +${btrfsSubvolLayout[${subvol}]} +" /etc/fstab) ]]; then # wenn Mount Point (z.B. für '/') bereits vorhanden
                echo -e "\e[0;33m    |__ Mount-Ziel '${btrfsSubvolLayout[${subvol}]}' bereits vorhanden, '${subvol}' wird nicht (nochmal) hinterlegt, ggf. prüfen/korrigieren\e[39m"
                mountPointInFstab='true'
            fi

            if [ "${subvolInFstab}" = 'false' ] && [ "${mountPointInFstab}" = 'false' ]; then
                echo "${fstabFileSystem} ${btrfsSubvolLayout[${subvol}]} btrfs subvol=/${subvol},${btrfsFstabMountOptions_standard}" | sudo tee -a /etc/fstab
            fi
        done

        if [ "${deleteOldRootInFstab}" = "true" ]; then
            sudo sed -i "/subvolid=5,subvol=\//d" /etc/fstab # delete the line containing 'subvolid=5,subvol=/'
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
        sudo btrfs subvolume set-default "${idRootSubvol}" / &&
            echo "aktuelles root default-Subvolume: $(sudo btrfs subvolume get-default /)"

        # UEFI+Grub / BIOS+Grub / UEFI+systemD
        echo -e "\n*** Re-Install grub + Update grub boot-Einträge"
        # https://wiki.archlinux.org/title/GRUB
        # if [ -e "/sys/firmware/efi/efivars" ]; then    # check if booted into UEFI mode and UEFI variables are accessible
        if [ -e "${efiDir}/" ] && [ -e "/boot/grub/grub.cfg" ]; then # UEFI + Grub
            sudo grub-install --target=x86_64-efi --efi-directory="${efiDir}" --bootloader-id="${bootloaderId}" &&
                sudo grub-mkconfig -o /boot/grub/grub.cfg &&
                sudo grub-mkconfig
        elif [ -e "/boot/grub/grub.cfg" ]; then # BIOS + Grub
            lsblk
            endloop='n'
            while [ ! "$endloop" = 'j' ]; do
                read -r -p "Eingabe device-Pfad für grub-install (z.B. '/dev/vda'): " devGrubInstallPath # nicht Partition (z.B. '/dev/vda1'), sondern Disk (z.B. '/dev/vda')
                read -r -p "Ist '${devGrubInstallPath}' korrekt ('j'=ja, beliebige Eingabe für Korrektur)?: " endloop
            done
            # https://wiki.archlinux.org/title/GRUB#Installation_2
            # BIOS: grub-install --target=i386-pc /dev/sdX; where i386-pc is deliberately used regardless of your actual architecture, and /dev/sdX is the disk (not a partition) where GRUB is to be installed.
            sudo grub-install --target=i386-pc "${devGrubInstallPath}" && sudo grub-mkconfig -o /boot/grub/grub.cfg &&
                sudo grub-mkconfig
        elif [ -e "${efiDir}/loader/loader.conf" ]; then # UEFI + Systemd Boot
            echo -e "\e[0;33m UEFI + systemD boot, kein TODO\e[39m"
        else
            echo "--- Bootloader nicht erkennbar ---"
            # systemd boot: kein Eintrag, manueller Sprung in tty (bzw. dracut macht neues img?)
        fi

        echo -e "\n*** Snapper config '${snapperConfigName_root}' wird angepasst..." # /etc/snapper/configs/CONFIGS (z.B. /etc/snapper/configs/root)
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
        if [ -e "/boot/grub" ]; then # Grub
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
        sudo mkdir -p /etc/pacman.d/hooks &&
            sudo cp "${SCRIPT_DIR}/files/95-bootbackup.hook" /etc/pacman.d/hooks/95-bootbackup.hook &&
            sudo chown root:root /etc/pacman.d/hooks/95-bootbackup.hook

        #if [ -e "/efi/loader/loader.conf" ]; then           # systemd Boot
        if [ -e "${efiDir}/loader/loader.conf" ]; then # systemd Boot
            #echo -e "\n*** Erstelle Hook für backup '/efi' (benötigt rsync)"
            echo -e "\n*** Erstelle Hook für backup '${efiDir}' (benötigt rsync)"
            echo "Installiere rsync, falls nicht vorhanden..."
            sudo pacman --needed --noconfirm -S rsync
            echo "Erstelle (kopiere nach) '/etc/pacman.d/hooks/95-efibackup.hook'..."
            # SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)   # absolute path # https://codefather.tech/blog/bash-get-script-directory/
            SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}") # relative path
            sudo mkdir -p /etc/pacman.d/hooks &&
                sudo cp "${SCRIPT_DIR}/files/95-efibackup.hook" /etc/pacman.d/hooks/95-efibackup.hook &&
                sudo chown root:root /etc/pacman.d/hooks/95-efibackup.hook
        fi

        echo -e "\n*** Erstelle snapshot (single) '***Base System Install***' und aktualisiere grub-boot Einträge"
        sudo snapper -c "${snapperConfigName_root}" create -d "***Base System Install***" &&
            echo "Aktuelle Liste der Snapshots:"
        sudo snapper ls

        #if [ -e "/boot/efi/grub.cfg" ] || [ -e "/boot/grub" ]; then     # GRUB (bei systemd Boot: kein Booteintrag, manuell in tty)
        if [ -e "${efiDir}/grub.cfg" ] || [ -e "/boot/grub" ]; then # GRUB (bei systemd Boot: kein Booteintrag, manuell in tty)
            echo -e "\n*** Aktualisiere Grub"
            echo "Aktualisiere 'grub.cfg'"
            sudo grub-mkconfig -o /boot/grub/grub.cfg &&
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

    touch "/home/${userid}/.ansible_installScript_snapperGrub" # wird auch bei default-switch - Zweig erstellt, d.h. snapper nicht konfiguriert (-> Manuelle Durchführung notwendig)

    echo -e "\e[0;33m*** Ende Snapper-Teil\e[39m"
    echo -e "\e[0;33m*** ********************************************\e[39m"
# else
#     echo -e "\n'/' hat kein btrfs-Filesystem"
fi

### ---
### updatedb.conf anpassen: keine Indexierung des (Snapper) snapshotFolder
### ---
### * https://wiki.archlinux.org/title/Snapper#Preventing_slowdowns
### * https://unix.stackexchange.com/questions/566495/how-can-i-change-the-configuration-of-etc-updatedb-conf-file
### * https://serverfault.com/questions/454051/how-can-i-view-updatedb-database-content-and-then-exclude-certain-files-paths
###   * https://serverfault.com/a/565094
updbconf="/etc/updatedb.conf"
pngrep="PRUNENAMES"
snapshotFolder=$(gettext "${snapperSnapshotFolder}" | sed 's/^.//') # ohne führendes '/' in '/.snapshots' -> .snapshots
#                gettext: damit nicht Pfad '/.snapshots' aufruft, sondern nur String nimmt

if [[ -e "${snapperSnapshotFolder}" ]] && [[ -e "${updbconf}" ]]; then
    echo -e "\n*** ********************************************"
    echo -e "*** updatedb: '${snapshotFolder}' von Indexierung ausnehmen"

    if ! grep -q "${snapshotFolder}" "${updbconf}" && grep -q "${pngrep}" "${updbconf}"; then
        # wenn .snapshots noch nicht in conf oder PRUNENAMES nicht in conf

        prunenamesOld=$(grep "${pngrep}" "${updbconf}" | sed 's/.$//') # aktuelle Werte bei PRUNENAMES, ohne letztes Zeichen ('"')
        echo "prunenames alt: ${prunenamesOld}\""
        prunenamesNew="${prunenamesOld} ${snapshotFolder}\""
        echo "prunenames neu: ${prunenamesNew}"

        sudo sed -i "s/${prunenamesOld}\"/${prunenamesNew}/" "${updbconf}"
        # sudo updatedb --add-prunenames "${snapshotFolder}"    # sudo updatedb --prunenames NAMES
        # sudo updatedb --debug-pruning > ~/updatedb_debug.log 2>&1 &
        sudo updatedb --debug-pruning 2>&1 | tee ~/updatedb_debug.log 1>/dev/null
    else
        echo "Eintrag '${snapshotFolder}' bereits in '${updbconf}' vorhanden oder '${pngrep}' nicht vorhanden"
    fi
fi

### ---
### Installation initial benötigter Pakete und Services abhängig von Betriebssystem:
### ---

# ### distributionsspezifische Anpassungen:
case ${os} in
Arch* | Endeavour*)
    # ### Repo Mirrors / reflector
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

    # ### Installs
    echo -e "\nInstallation initial benoetigte Software (curl  git openssh rsync vim)"
    sudo pacman -S --needed --noconfirm ansible curl git openssh rsync vim # python-pipx # ansible-core firewalld

    echo -e "\nInstallation benoetigte Softwarepackages zur Installation von AUR helpers, AUR-Packages..."
    sudo pacman -S --needed --noconfirm base-devel

    echo -e "\nInstalling 'paru' - AUR helper..."
    if ! [ -x "$(command -v paru)" ]; then
        sudo git clone https://aur.archlinux.org/paru.git /tmp/paru
        sudo chown -R "${userid}":users /tmp/paru
        cd /tmp/paru && makepkg -sic --needed
        cd || return
        # cleanup:
        sudo rm -rf /tmp/paru
    else
        echo -e "paru is already available"
    fi

    # ### VM guest - spice-vdagent
    echo -e "\n Installation (wenn VM) spice agent for Linux guests (z.B. für clipboard sharing zwischen host+guest)"
    [[ $(systemd-detect-virt) != *"none"* ]] && sudo pacman -S --needed --noconfirm spice-vdagent

    # ### SSH
    echo -e "\nStarte sshd.service..." # wg. ssh von anderer Maschine für evtl. todos/checks, ...
    # sudo systemctl enable --now sshd.service # wird später in Ansible task (services) wieder deaktiviert (ober noch nicht gestoppt)
    sudo systemctl start sshd.service

    # ### VM Qemu/KVM: uninstall iptables, install iptables-nft
    echo -e "\nVM - Qemu/KVM: Wiki empfiehlt inst. von 'iptables-nft'"
    echo -e "Bestätige, dass 'iptables' (und 'inxi') gelöscht und 'iptables-nft' installiert wird"
    echo -e "Anmerkung: 'inxi' wird im Rahmen basis-inst wieder installiert"
    sudo pacman -S --needed iptables-nft
    ;;

Debian*)
    # ### sudo
    if [[ ! $(grep sudo /etc/group) = *"${userid}"* ]]; then
        echo "Füge User '${userid}' der sudo-Gruppe hinzu"
        su -l root --command "usermod -aG sudo ${userid}"

        echo "Erzwinge ausloggen des aktuellen Users, sudo-Gruppeneintrag greift nach Neuanmeldung."
        read -rp "Bitte Eingabe-Taste drücken, um fortzufahren."
        pkill -KILL -u "${userid}"
    fi

    # ### Update / Upgrade + Installs
    echo -e "\nUpdate Repos, upgrade and autoremove"
    sudo apt-get update && sudo apt-get upgrade -y
    sudo apt-get autoremove -y

    echo -e "\nInstallation benoetigte Software - ansible"
    sudo apt-get install -y ansible # ansible-core

    echo -e "\nInstallation benoetigte Software (git, rsync, vim, ..."
    sudo apt-get install -y git rsync ssh vim # pipx, ufw
    # bereits installiert: chrome-gnome-shell curl openssh-client openssh-server

    echo -e "\nInstalliere benötigte Packages für Installation von Microsoft PowerShell"
    sudo apt-get install -y apt-transport-https software-properties-common wget

    echo -e "\nInstalliere noch fehlende, benötigte Packages für Installation von Brave Web Browser"
    sudo apt-get install -y curl

    echo -e "\nInstallation (wenn VM) spice agent for Linux guests (z.B. für clipboard sharing host+guest)"
    [[ $(systemd-detect-virt) != *"none"* ]] && sudo apt-get install -y spice-vdagent

    # ### Ulauncher
    echo -e "\nInstalliere Voraussetzungen / ergänze Repo für 'ulauncher'"
    if [ -e "/home/${userid}/.ansible_ppaUlauncherAdded" ]; then
        echo "Repo wurde bereits hinzugefügt, Schritt wird übersprungen"
    else
        # https://ulauncher.io/#Download
        sudo apt install -y gnupg
        gpg --keyserver keyserver.ubuntu.com --recv 0xfaf1020699503176
        gpg --export 0xfaf1020699503176 | sudo tee /usr/share/keyrings/ulauncher-archive-keyring.gpg >/dev/null
        echo "deb [signed-by=/usr/share/keyrings/ulauncher-archive-keyring.gpg] \
                http://ppa.launchpad.net/agornostal/ulauncher/ubuntu jammy main" |
            sudo tee /etc/apt/sources.list.d/ulauncher-jammy.list
        # sudo apt update && sudo apt install -y ulauncher # installation in "packages_workstation-Gnome.yml"

        touch "/home/${userid}/.ansible_ppaUlauncherAdded"
    fi

    # ### SSH
    echo -e "\nStarte ssh ..." # initial temporär
    sudo systemctl start ssh   # && sudo systemctl enable ssh
    ;;

*)
    echo "Unbehandelter Fall: switch os - default-switch Zweig"
    read -r -p "Eingabe-Taste drücken zum Beenden"
    exit 0
    ;;
esac

# ### Alle Systeme: install ansible via pipx
# auskommenitert, da vorerst ansible wieder über Paketmanager installiere
#
# echo -e "\npipx ensurepath..."
# pipx ensurepath # pipx wurde erst (oben) neu installiert -> PATH
# echo -e "\nInstallation ansible via pipx"
# pipx install --include-deps ansible
# pipx inject --include-apps ansible argcomplete

### ---
### Test Ansbile Playbook
### ---
# echo ""
# read -rp "Soll TEST des Ansible-Playbooks durchgeführt werden (j/n)?: " testplay
# if [ "${testplay}" = 'j' ]; then
#    echo "Starte TEST des Playbooks ..."
#    ansible-playbook "/home/${userid}/${playbookdir}/${playbook}" -v --ask-become-pass --check
#    # bei verschlüsselten Daten z.B.:
#    #ansible-playbook "/home/${userid}/${playbookdir}/${playbook}" -v -K -C --vault-password-file "/home/${userid}/.ansibleVaultKey"
# else
#    echo "TEST des Playbooks wird NICHT durchgefürt"
# fi

echo -e "\nAnsible-Playbook starten ..."
echo -e "\e[0;33m### Info\e[39m"
echo -e "\e[0;33m#   - If you encounter a problem/error while executing the playbook (e.g. with pip / python, NVM, ...):\e[39m"
echo -e "\e[0;33m#     Close and reopen terminal and start the script or just the playbook again\e[39m"
echo -e "\e[0;33m#   - If VS Code app opens you can simply close it again or leave it open until script is finished\e[39m"
echo -e "\e[0;33m###\e[39m\n"

# auskommenitert, da vorerst ansible wieder über Paketmanager installiert wird
# echo -e "\e[0;33m'ansible' Befehl evtl. zunächst noch nicht verfügbar\e[39m"
# echo -e "\e[0;33mShell neu starten (oder source der shell config) und dann Script erneut ausführen\e[39m\n"

echo -e "/home/${userid}/${playbookdir}/${playbook}"
ansible-playbook "/home/${userid}/${playbookdir}/${playbook}" -v -K

# ansible-playbook "/home/${userid}/${playbookdir}/${playbook}" -v -K -e 'ansible_python_interpreter=/usr/bin/python3'
# https://docs.ansible.com/ansible/latest/collections/ansible/posix/firewalld_module.html#notes
# - tasks/basic_all/config_workstation-firewall.yml: Firewalld - allow KDE Connect (Archlinux)
# - tasks/basic_all/packages_workstation-pythonPip.yml: /home/userID/dev/Projects/Ansible/ansible_workstation/tasks/basic_all/packages_workstation-pythonPip.yml

# bei verschlüsselten Daten z.B.:
#ansible-playbook "/home/${userid}/${playbookdir}/${playbook}" -v -K --vault-password-file "/home/${userid}/.ansibleVaultKey"

case ${os} in
Arch* | Endeavour*)
    ### ---
    ### Further Installations via paru (Arch Linux, EndeavourOS)
    ### - put at the and to not interfer with / lenthen ansible playbook execution
    ### ---
    read -r -p "Install some additonal software from AUR ? ('y'=yes, other input=no): " installAUR

    if [ "${installAUR}" == "y" ]; then
        echo -e "\nInstall some Gnome Extensions (gsconnect) from AUR ..."
        paru -S --needed --skipreview gnome-shell-extension-gsconnect

        echo -e "\nInstall several Packages (bashdb, gtkhash, units) from AUR..."
        paru -S --needed --skipreview bashdb gtkhash units

        # echo -e "\nInstall several Applications (Vorta) from AUR..."
        # paru -S --needed --skipreview vorta joplin-desktop # -> change: flatpak

        # echo -e "\nInstall Brave Browser from AUR..."
        # paru -S --needed --skipreview brave-bin # -> change: flatpak

        echo -e "\nInstall linux steam integration from AUR..."
        paru -S --needed --skipreview linux-steam-integration

        echo -e "\nInstall ulauncher from AUR..."
        paru -S --needed --skipreview ulauncher
        echo -e "\nStart + enable ulauncher.service for '${userid}'..."
        systemctl --user enable --now ulauncher.service # su -u "${userid}" -c "systemctl --user enable --now ulauncher.service"

        # lsblkBtrfs=$(lsblk -P -o +FSTYPE | grep "btrfs")   # $(blkid | grep btrfs) # $(mount | grep "^/dev" | grep btrfs)  # $(grep btrfs /etc/fstab)
        # if [ -n "${lsblkBtrfs}" ]; then
        if [[ $(stat -f -c %T /) = 'btrfs' ]]; then
            echo -e "\nInstall 'btrfs-assistant' from AUR..."
            paru -S --needed --skipreview btrfs-assistant # && touch "/home/${userid}/.ansible_installScript_AUR-btrfsassistantInstalled"
        fi

        echo -e "\nInstall Citrix Workspace App (icaclient) from AUR..."
        paru -S --needed --skipreview icaclient && touch "/home/${userid}/.ansible_installScript_AUR-icaclientInstalled" && mkdir -p "/home/${userid}/.ICAClient/cache" &&
            sudo rsync -aPhEv /opt/Citrix/ICAClient/config/{All_Regions,Trusted_Region,Unknown_Region,canonicalization,regions}.ini "/home/${userid}/.ICAClient/"

        echo -e "\nInstall 'visual-studio-code-bin' from chaotic-aur..." # instead of flatpak
        sudo pacman -S --needed --noconfirm visual-studio-code-bin       # from chaotic-aur

        echo -e "\nInstall Powershell from chaotic-aur..."
        sudo pacman -S --needed --noconfirm powershell-bin # from chaotic-aur
        #paru -S --needed --skipreview powershell-bin

        echo -e "\nInstall espanso (wayland) from AUR (will takes some time)..."
        paru -S --needed --skipreview espanso-wayland     # espanso-gui

        # echo -e "\nInstall Microsoft TTF Fonts from AUR..." # takes quite some time
        # paru -S --needed --skipreview ttf-ms-fonts && touch "/home/${userid}/.ansible_installScript_AUR-ttfmsfontsInstalled"

        # --- 'autokey' auskommentiert, da nicht mit Wayland funktioniert --- #
        # echo -e "\nInstall 'autokey-gtk' from AUR..."         # da aktuell Gnome verwende
        # paru -S --needed --skipreview autokey-gtk && touch "/home/${userid}/.ansible_installScript_autokeyGtkInstalled"
        # echo -e "\nInstall 'autokey-qt' from AUR (Arch)"      # e.g. when using Plasma
        # paru -S --needed --skipreview autokey-qt # && touch "/home/${userid}/.ansible_installScript_autokeyQtInstalled"

        # echo -e "\nInstall woeusb-ng (Tool to create Windows boot stick) from AUR..."
        # paru -S --needed --skipreview woeusb-ng && touch "/home/${userid}/.ansible_installScript_AUR-woeusbngInstalled"

        # echo -e "\nVM - Download 'virtio-win' image from AUR..."
        # paru -S --needed --skipreview virtio-win && touch "/home/${userid}/.ansible_installScript_AUR-vmVirtioWinInstalled"

        # echo -e "\nCreating flag-file '.ansible_installScript_severalAurPkgInstalled'..."
        # touch "/home/${userid}/.ansible_installScript_severalAurPkgInstalled"
    fi
    ;;

*)
    echo -e "\nNo final additional installations defined --- default switch (case os, final step)"
    ;;
esac

echo -e "\n\e[0;33mScript finished.\e[39m"
