# ansible_workstation
- Lab automatisierte Installation Home-Workstation

# Zusätzliche Infos
## VS Code - Extension "Sync Settings"
### Config git-repo
- `STRG + SHIFT + P`
- `>Sync Settings: open the repository Settings`
- Pfad im Dateisystem:
  - Path: `/home/{{ env_user }}/.config/Code/User/globalStorage/zokugun.sync-settings`
  - File: `settings.yml`
- verwendete settings: `files/VSCode_Extension_Sync-Settings_settings.yml`
### git-Verzeichnis
- git-Verzeichnis, in dem die Extension seine Daten ablegt: `profiles/main`
### Config importieren
- `STRG + SHIFT + P`
- `>Sync Settings: Download (repository -> user)`
### Config exportieren
- `STRG + SHIFT + P`
- `>Sync Settings: Upload (user -> repository)`
