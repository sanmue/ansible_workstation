#!/bin/bash

# Grund-Konfiguration für vim
echo "Erstelle Config-Datei für vim (.vimrc) in '$HOME' ..."

touch "$HOME/.vimrc"

cat > "$HOME/.vimrc" << EOF
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
