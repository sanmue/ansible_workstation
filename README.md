# ansible_workstation
- Lab automatisierte Installation Home-Workstation

# Infos
## Login / Startscript
- Login am System mit Standard-User (mit sudo-Rechten) und
- "bootstrap.sh" ausführen (im Verzeichnis: tasks/bootstrapScript)
## VS Code - Extension "Sync Settings"
### Config git-repo als Ablageziel der Einstellungen von VS Code
- in VS Code:
  - `STRG + SHIFT + P`
  - `>Sync Settings: open the repository Settings`
- Pfad im Dateisystem:
  - Path: `/home/{{ env_user }}/.config/Code/User/globalStorage/zokugun.sync-settings`
  - File: `settings.yml`
- verwendete settings: `files/VSCode_Extension_Sync-Settings_settings.yml`
### Verzeichnis mit VS Code-Einstellungen im git-repo
- Verzeichnis, in dem die Extension die VS Code-Einstellungen ablegt: `profiles/main`
### Config importieren aus git-repo
- in VS Code:
  - `STRG + SHIFT + P`
  - `>Sync Settings: Download (repository -> user)`
### Config exportieren von git-repo
- in VS Code:
  - `STRG + SHIFT + P`
  - `>Sync Settings: Upload (user -> repository)`
