﻿#!/bin/bash

#set -x   # for debugging

### ############################
### Update starship shell prompt
### (via systemd timer+service)
### ############################

### -------------------
### Parameter/Variablen
### -------------------
path="$HOME"     # default-Wert
if [ $# -gt 0 ]; then
    path="${1}"    # 1. Übergabe-Parameter an Script
fi

### ----
### main
### ----

# --- Update:
curl -sS https://starship.rs/install.sh > "$path/starship_install.sh" && chmod 755 "$path/starship_install.sh" && "$path/starship_install.sh --yes" && rm "$path/starship_install.sh"
