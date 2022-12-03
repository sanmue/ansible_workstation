# VSCode Settings
## Extension: Sync Settings
- "Sync Settings" - Settings
  - Aufruf in VSCode:
    - `STRG + SHIFT + P`
    - `>Sync Settings: open the repository Settings'`
  - Pfad im Dateisystem:
    - Path: /home/sandro/.config/Code/User/globalStorage/zokugun.sync-settings
    - File: settings.yml:

```
# # sync on remote git
repository:
  type: git
#   # url of the remote git repository to sync with, required
  url: git@github.com:sanmue/ansible_test.git
#   # branch to sync on, optional (set to `master` by default)
  branch: main
#   # how to personalize the commit messages at https://github.com/zokugun/vscode-sync-settings/blob/master/docs/commit-messages.md
```
