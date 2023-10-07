# ansible_workstation - automated post-installation of my workstation
- executes further installation and configuration of additionally defined software and services after successful basic installation (including a desktop environment (Gnome or Plasma))
  - currently only tested for my Gnome desktop environment + settings (Plasma: not up to date / re-tested)
- initial bash script (works for Arch Linux, Endeavour OS and Ubuntu):
  - installs some initially required packages
  - optionally installs/creates/configures btrfs subvolumes and 'snapper' for system snapshots (only if filesystem is btrfs)
    - not tested for Ubuntu (will very probably not work, better skip this step when prompted in script)
  - starts the ansible playbook (local.yml)
  - Arch Linux / Endeavour OS: installs some packages from AUR

# Usage
## Start initial bash script
- boot to desktop environment + login
- clone the repo to the home directory of the current user
  - `git clone https://gitlab.com/sanmue/ansible_workstation.git`
- execute the initial bash script
  - `./ansible_workstation/install_SWandConf.sh`
  - check if script is executable first
    - make executable: `chmod +x ./ansible_workstation/install_SWandConf.sh`

# Known Issues
## Installing/updating - pip update (python), ...
- when ansible stops because of an error referring to pip update (python), ...:
  - logout + login and start script/ansible playbook again

# Further notes for myself
## 'Visual Studio Code' respectively 'Code - OSS' with extension "Sync Settings"
### Config git-repo as storage target of the settings of VS Code
- in VS Code:
  - `STRG + SHIFT + P`
  - `>Sync Settings: open the repository Settings`
- Path in the file system:
  - Path: `/home/{{ env_user }}/.config/Code/User/globalStorage/zokugun.sync-settings`
  - File: `settings.yml`
- settings used: `files/VSCode_Extension_Sync-Settings_settings.yml`
### Folder with VS Code-settings in git-repo
- directory where the extension stores the VS Code settings: `profiles/main`
### Import config from git-repo
- in VS Code:
  - `STRG + SHIFT + P`
  - `>Sync Settings: Download (repository -> user)`
### Export config to git-repo
- in VS Code:
  - `STRG + SHIFT + P`
  - `>Sync Settings: Upload (user -> repository)`
