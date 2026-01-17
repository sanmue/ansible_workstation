# ansible_workstation - automated post-installation of my workstation

## Infos

- executes further installation and configuration of additionally defined software and services after successful basic installation (including desktop environment)
  - currently only tested for my Gnome desktop environment + settings
  - (Plasma: not up to date / re-tested, therefore commented out)
- initial bash script (works for Arch Linux, Endeavour OS and Debian):
  - installs some initially required packages
  - optionally installs + configures 'snapper' for system snapshots and additional btrfs subvolumes if needed (only if filesystem is btrfs + OS is Arch Linux or Endeavour OS)
    - at least a basic btrfs subvolume layout must exist
  - starts the ansible playbook (local.yml)
  - Arch Linux / Endeavour OS: optionally installs some packages from AUR after completing ansible playbook
  - Arch Linux / Endeavour OS (with 'systemd-boot' bootloader): optionally installs [(Rescue) System on ESP](https://wiki.archlinux.org/title/Systemd-boot#Archiso_on_ESP)
    - minimum free disk space on EFI Partition needed:
      - ~3 GB for EndeavourOS
      - ~1 GB for Archlinux or grml (full)
      - and add 300MB reserve disk space

## Usage

### Start initial bash script

- boot to desktop environment + login
- clone the repo to the home directory of the current user
  - `git clone https://gitlab.com/sanmue/ansible_workstation.git`
- cd into the repo folder
  - `cd ansible_workstation`
- execute the initial bash script
  - `./install_SWandConf.sh`
  - check if script is executable first
    - make executable: `chmod +x install_SWandConf.sh`

### Ansible Tags

Some tasks have tags that are executed when they are called via an alias in the command line.
The aliases are set via Ansible tasks (in ~/.bashrc and ~/.zshrc).
The corresponding bash script is also provided via an Ansible task and called via the aliases (with tag as a parameter).

Tags Overview:

- 'always' (Special tag / reserved name): Gather Facts and Variables
- 'upnnnplugs': create / update 'nnn' plugins + xterm conf for nnn-preview-tui
- 'upnvm': create / update 'nvm' + 'node'
- 'upshellrc': create / update shell conf (~/.bashrc, ~/.zshrc) + 'Starship' cross shell prompt + direnv etc
- 'upvic': install / update vicinae desktop launcher + conf + extensions
- 'upvimrc': create / update vim conf + plugins

Example alias: alias upshellrc='${HOME}/.local/bin/ansible_update-by-tag.sh shellrc'
Just write "upshellrc" in terminal to start the tagged tasks of the Ansible playpook.

## Known Issues

### Error Message in ansible playbook regarding Python/pip, NVM

- when ansible playbook stops because of an error referring to python/pip or NVM:
  - close + reopen terminal and start install script or just the ansible playbook again

## Further notes for myself

### 'Visual Studio Code' with extension "Sync Settings"

#### Config git-repo as storage target of the settings of VS Code

- in VS Code:
  - `STRG + SHIFT + P`
  - `>Sync Settings: open the repository Settings`
- Path in the file system:
  - Path: `/home/{{ env_user }}/.config/Code/User/globalStorage/zokugun.sync-settings`
  - File: `settings.yml`
- settings used: `files/VSCode_Extension_Sync-Settings_settings.yml`

#### Folder with VS Code-settings in git-repo

- directory where the extension stores the VS Code settings: `profiles/main`

#### Import config from git-repo

- in VS Code:
  - `STRG + SHIFT + P`
  - `>Sync Settings: Download (repository -> user)`

#### Export config to git-repo

- in VS Code:
  - `STRG + SHIFT + P`
  - `>Sync Settings: Upload (user -> repository)`
