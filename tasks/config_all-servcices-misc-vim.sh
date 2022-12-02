#!/bin/bash

# Grund-Konfiguration für vim
#echo "Erstelle Config-Datei für vim (.vimrc) in allen vorhandenen User-Homeverzeichnissen..."

#read -rp "Verzeichnispfad (absolut) angeben: " pathToDir
#read -rp "Suchtiefe ab Verzeichnispfad angeben (>= 0): " searchdepth
pathToDir="/home"
searchdepth=1
cfgFile=".vimrc"

#echo "Erstelle Liste der Vereichnisse in ${pathToDir} (Suchtiefe: ${searchdepth})"
arrDir="$(find "${pathToDir}" -maxdepth "${searchdepth}" -mindepth "${searchdepth}" -type d)"
#echo "${arrDir}"

for dir in ${arrDir}; do
    touch "${dir}/${cfgFile}"

    # nächster Teil darf nicht eingerückt werden:
cat > "${dir}/${cfgFile}" << EOF
syntax on
set ruler
set number
" show existing tab with 4 spaces width:
set tabstop=4
" when indentig with '>', use 4 spaces
set shiftwidth=4
" On pressing tab, insert 4 spaces
set expandtab
set nocompatible
colorscheme koehler

EOF


    # Ändern Besitzer der config-datei:
    # ${dir} ist z.B. /home/sandro
    username=$(echo "${dir}" | cut -d '/' -f 3)   # -f 3: das 2. Element (=username); Anmerkung: erstes Element vor /home ist leer, -f 2 = home

    chown "${username}:${username} ${dir}/${cfgFile}"   # aktueller Anwender (id enspricht Name des aktuellen Verzeichnisses); sonst wäre es "root"

done
