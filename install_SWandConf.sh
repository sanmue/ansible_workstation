#!/usr/bin/env bash

# set -x # enable debug mode

### ---------------------------------------------------------------------------
### Installation initial benötigter Pakete / Config (e.g. firewall, git, ...)
### Start automatisierte Installation (Ansible)
### Archlinux(-Derivate): Installationen (aus AUR) separat außerhalb playbook
### - um Ausführung playbook nicht wg. evtl. manueller Eingaben zu unterbrechen
### ---------------------------------------------------------------------------

### ---
### prepare sudo privileges
### ---
sudo true

### ---
### Funktionen
### ---
# shellcheck source=install_SWandConf.shlib
source install_SWandConf.shlib

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
bootloaderId='GRUB'                     # or 'endeavouros', ... # only relevant if grub bootloader is used

# if [ -d "/efi" ]; then # Uefi - EFI path
if [ "$(sudo ls "/efi")" ]; then # Uefi - EFI path
    efiDir="/efi"
elif [ "$(sudo ls "/boot/efi")" ]; then # Uefi - EFI path (deprecated location)
    efiDir="/boot/efi"
else # Bios boot mode
    efiDir="/no/efi/dir/available"
fi

zramGeneratorConfFilePath="/etc/systemd/zram-generator.conf"
zramSize=2 # e.g.: 2 -> 1/2 = 50 % of RAM size # 1.25 -> 1/1.25 = 80% of RAM size
zramParameterConfFilePath="/etc/sysctl.d/99-vm-zram-parameters.conf"

snapperRollbackFolderName=".btrfsroot"
snapperRollbackConfig="/etc/snapper-rollback.conf"

snapperConfigName_root="root"
snapperSnapshotFolder="/.snapshots"
snapperSnapshotsSubvolName='@snapshots'

declare -A btrfsSubvolLayout=(
    ["@"]="/"
    ["${snapperSnapshotsSubvolName}"]="${snapperSnapshotFolder}"
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

updbconf="/etc/updatedb.conf"
pngrep="PRUNENAMES"
snapshotFolder=$(gettext "${snapperSnapshotFolder}" | sed 's/^.//') # ohne führendes '/' in '/.snapshots' -> .snapshots
#                gettext: damit nicht Pfad '/.snapshots' aufruft, sondern nur String nimmt

downloadFolder="${HOME}/Downloads"

### ---
### Initial settings
### ---
echo -e "\n\e[0;35mInitial settings\e[0m"

### Check Operating System (OS)
os=$(grep -e "^NAME=" /etc/os-release | cut -d '"' -f 2 | xargs)
echo -e "\e[0;33mCurrent OS:\e[39m ${os}"

supportedOS="false"
for osname in "${oslist[@]}"; do
    if [ "${os}" = "${osname}" ]; then
        supportedOS="true"
    fi
done
if [ "${supportedOS}" = "false" ]; then
    echo -e "\e[0;31mSorry, your OS '${os}' is not supported. Script/Playbook won't work for you.\e[0m"
    echo "Skript will exit here :-("
    exit 1
fi

### Hostname
# https://en.wikipedia.org/wiki/Hostname
# TODO: error handling, validy check
echo -e "\e[0;33mCurrent hostname (including domain of set):\e[39m '${currentHostname}'"
read -r -p "  |_ Change hostname? ('y'=yes, other input=no): " changeHostname
if [ "${changeHostname}" = 'y' ]; then
    read -r -p "     Enter new hostname (without domain): " newHostname
    newHostname="${newHostname// /}"           # remove any spaces
    newHostname="${newHostname,,}"             # change uppercase to lowercase letters
    echo "     -> newHostname: ${newHostname}" # no validy check if starts or ends with '-' or contains any other invalid characters

    if [[ ! $(grep sudo /etc/group) = *"${userid}"* ]]; then # if user not in sudo group
        echo "     Changing hostname (hostnamectl)..."
        su -l root --command "hostnamectl hostname ${newHostname}"
        echo "     Changing hostname (/etc/hosts)..."
        su -l root --command "sed -i 's/${currentHostname}/${newHostname}/g' /etc/hosts"
    else
        echo "     Changing hostname (hostnamectl)..."
        sudo hostnamectl hostname "${newHostname}"
        echo "     Changing hostname (/etc/hosts)..."
        sudo sed -i "s/${currentHostname}/${newHostname}/g" /etc/hosts
    fi
    echo "     Hostname set to '${newHostname}'"
fi

### ---
### lts-kernel
### ---
# vorgelagert, damit bei snapper conf bei boot-/efibackup schon vorhanden
echo -e "\n\e[0;35mInstalling lts-kernel\e[0m"
sudo pacman -S --needed --noconfirm linux-lts linux-lts-headers

### ---
### zram
### ---
# - https://wiki.archlinux.org/title/Zram#Using_zram-generator
echo -e "\n\e[0;35mZram\e[0m"
if [[ ! -e "/etc/archinstall_autoBash" ]] && [[ $(cat /sys/module/zswap/parameters/enabled) = "N" ]] && [[ ! $(swapon --noheadings --show=NAME) = *zram* ]]; then
    config-zram
else
    echo -e "\e[0;33m'/etc/archinstall_autoBash' vorhanden oder Zswap (noch) enabled oder Zram bereits eingerichtet.\nZram wird nicht (erneut) eingerichtet.\e[0m\n"
    swapon
fi

### ---
### Snapper + snapper-rollback
### ---
echo -e "\n\e[0;35mSystem snapshots\e[0m"
if [[ ! -e "/etc/archinstall_autoBash" ]]; then # if installed via 'archinstall_autoBash': snapper install + config already finished
    # check filesystem type + aks if snapper should be installed:
    if [[ $(stat -f -c %T /) = 'btrfs' ]] && [[ ! -e "${HOME}/.ansible_installScript_snapper" ]]; then # prüfe '/' auf btrfs filesystem;  -f, --file-system; -c, --format; %T - Type in human readable form (e.g. 'btrfs', 'ext4', ...)
        read -r -p "Install + configure 'snapper'? ('y' = yes, other input = no): " doSnapper
        if [ "${doSnapper}" = "y" ]; then
            install-aur-helper # installs AUR helper, e.g. paru # needed for install of 'snapper-rollback' from AUR
            config-snapper
        fi
    fi
else
    echo "- Skipped install + conf since installed via archinstall_autoBash"
fi

### ---
### updatedb.conf anpassen: keine Indexierung des (Snapper) snapshotFolder
### ---
if [ "$(sudo ls "${snapperSnapshotFolder}")" ] && [ -e "${updbconf}" ]; then
    echo -e "\n\e[0;33mUpdatedb - '${snapshotFolder}' von Indexierung ausnehmen\e[0m"
    config-updatedb
fi

### ---
### Install / config initial benötigter Pakete, Services, Mirrorlists abhängig von Betriebssystem
### ---
echo -e "\n\e[0;35mDistributionsspezifische initiale Installationen und Konfigurationen\e[0m"
case "${os}" in
    Arch* | Endeavour*)
        # ### Repo Mirrors / reflector
        if [[ ! -f "${HOME}/.ansible_installScript_MirrorPool" ]]; then
            echo -e "\e[0;33mMirrorlist (Arch)\e[0m"
            config-mirrorlist # Repo Mirrors / reflector
            touch "${HOME}/.ansible_installScript_MirrorPool" # create 'flag'-file (for if condition)
        else
            echo "Mirror List (Arch) bereits abgearbeitet."
        fi

        # ### Installs
        if [[ ! -f "${HOME}/.ansible_installScript_initalSofware" ]]; then
            echo -e "\n\e[0;33mInitial installs (Arch)\e[0m"
            install-initialSw-Arch
            touch "${HOME}/.ansible_installScript_initalSofware"
        else
            echo "Initial installs (Arch) bereits abgearbeitet."
        fi
        ;;

    Debian*)
        # ### groups
        if [[ ! $(grep sudo /etc/group) = *"${userid}"* ]]; then
            echo -e "\e[0;33mAnpassung Gruppenzugehörigkeit (Debian)\e[0m"
            echo "Füge User '${userid}' der sudo-Gruppe hinzu"
            su -l root --command "usermod -aG sudo ${userid}"

            echo "Erzwinge ausloggen des aktuellen Users, sudo-Gruppeneintrag greift nach Neuanmeldung."
            echo "Anschließend Skript neu starten."
            read -rp "Bitte Eingabe-Taste drücken, um fortzufahren."
            pkill -KILL -u "${userid}"
        fi

        # ### Installs
        echo -e "\n\e[0;33mInitial installs (Debian)\e[0m"
        install-initialSw-Debian

        # ### Repos - ppa
        echo -e "\n\e[0;33mAdd repos/ppa (Debian)\e[0m"
        if [ -e "${HOME}/.ansible_ppaAdded" ]; then
            echo "Repos (ppa) wurden bereits hinzugefügt, Schritt wird übersprungen"
        else
            add-repo-Debian # currently only for ulauncher # TODO: check move to config_workstations-addrepos
            touch "${HOME}/.ansible_ppaAdded"
        fi
        ;;

    *)
        echo -e "\e[0;33mUnbehandelter Fall: switch os - default case (distributionsspezifische Anpassungen)\e[0m"
        read -r -p "Eingabe-Taste drücken zum Beenden"
        exit 0
        ;;
esac

### ---
# ### Alle Systeme: install ansible via pipx
### ---
# auskommenitert, da vorerst ansible wieder über Paketmanager installiere
#
# echo -e "\npipx ensurepath..."
# pipx ensurepath # pipx wurde erst (oben) neu installiert -> PATH
# echo -e "\nInstallation ansible via pipx"
# pipx install --include-deps ansible
# pipx inject --include-apps ansible argcomplete

### ----------------
### Ansbile Playbook
### ----------------
echo -e "\n\e[0;35mAnsible Playbook\e[0m"
executePlaybook="y"
if [ -e "${HOME}/.ansible_playbookFinished" ]; then
    read -rp "Playbook wurde bereits durchlaufen. Nochmal starten? (y=yes, sonstige Eingabe: nein): " executePlaybook
fi

if [ "${executePlaybook}" = "y" ]; then
    ### --- Test Ansbile Playbook
    # echo ""
    # read -rp "Soll TEST des Ansible-Playbooks durchgeführt werden (j/n)?: " testplay
    # if [ "${testplay}" = 'j' ]; then
    #    echo "Starte TEST des Playbooks ..."
    #    ansible-playbook "${HOME}/${playbookdir}/${playbook}" -v --ask-become-pass --check
    #    # bei verschlüsselten Daten z.B.:
    #    #ansible-playbook "${HOME}/${playbookdir}/${playbook}" -v -K -C --vault-password-file "${HOME}/.ansibleVaultKey"
    # else
    #    echo "TEST des Playbooks wird NICHT durchgefürt"
    # fi

    ### --- Ansbile Playbook
    echo -e "\e[0;33m### Info\e[0m"
    echo -e "\e[0;33m# If an error occurs in context with pip, pyenv, nvm, ... while executing the playbook:\e[0m"
    echo -e "\e[0;33m# Close and reopen terminal and start the script or just the playbook again\e[0m"
    # echo -e "\e[0;33m#   - If VS Code app opens you can simply close it again or leave it open until script is finished\e[0m"
    echo -e "\e[0;33m###\e[39m\n"

    # auskommenitert, da vorerst ansible wieder über Paketmanager installiert wird
    # echo -e "\e[0;33m'ansible' Befehl evtl. zunächst noch nicht verfügbar\e[0m"
    # echo -e "\e[0;33mShell neu starten (oder source der shell config) und dann Script erneut ausführen\e[39m\n"

    echo -e "Path to playbook: ${HOME}/${playbookdir}/${playbook}"
    # ansible-playbook "${HOME}/${playbookdir}/${playbook}" -v -K
    # if [ $? -eq 0 ]; then
    if ansible-playbook "${HOME}/${playbookdir}/${playbook}" -v -K; then
        echo "No error when executing playbook, setting 'flag file'"
        touch "${HOME}/.ansible_playbookFinished"
    else
        echo "Error when executing playbook."
    fi

    # ansible-playbook "${HOME}/${playbookdir}/${playbook}" -v -K -e 'ansible_python_interpreter=/usr/bin/python3'
    # https://docs.ansible.com/ansible/latest/collections/ansible/posix/firewalld_module.html#notes
    # - tasks/basic_all/config_workstation-firewall.yml: Firewalld - allow KDE Connect (Archlinux)
    # - tasks/basic_all/packages_workstation-pythonPip.yml: /home/userID/dev/Projects/Ansible/ansible_workstation/tasks/basic_all/packages_workstation-pythonPip.yml

    # bei verschlüsselten Daten z.B.:
    # ansible-playbook "${HOME}/${playbookdir}/${playbook}" -v -K --vault-password-file "${HOME}/.ansibleVaultKey"
fi

### ---
### Further Installations
### ---
case ${os} in
Arch* | Endeavour*)
    echo -e "\n\e[0;35mSoftware from AUR (Ach)\e[0m"
    read -r -p "Install 'paru' AUR helper and some additonal software from AUR ? ('y'=yes, other input=no): " installAUR
    if [ "${installAUR}" = "y" ]; then
        install-aur
    fi

    if [ "$(sudo ls ${efiDir}/loader)" ]; then # if systemd-boot
        echo -e "\n\e[0;35mSystem on ESP (rescue system)\e[0m"
        read -r -p "Install System on ESP (rescue system) ? ('y'=yes, other input=no): " installSysOnEsp
        if [ "${installSysOnEsp}" = "y" ]; then
            # (Rescue) System on ESP - you may have to increase the size of the efi partition
            # - https://wiki.archlinux.org/title/Systemd-boot#Grml_on_ESP
            # - https://wiki.archlinux.org/title/Systemd-boot#Archiso_on_ESP
            echo -e "Please make sure you downloaded the installation iso to '${downloadFolder}'\n"
            install-sysOnEsp
        fi
    fi
    ;;

*)
    echo -e "No additional software installations --- default case (Further Installations)"
    ;;
esac

echo -e "\n\e[0;33mScript finished.\e[0m"
