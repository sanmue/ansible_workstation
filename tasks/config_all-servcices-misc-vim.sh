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

done
