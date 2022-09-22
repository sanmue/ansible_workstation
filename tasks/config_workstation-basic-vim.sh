#!/bin/bash

# Grund-Konfiguration für vim

touch "$HOME/.vimrc"

echo "Erstelle Config-Datei für vim (.vimrc) in '$HOME' ..."
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
set colorscheme koehler

EOF
