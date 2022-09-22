#!/bin/bash

# Grund-Konfiguration für vim

touch "$HOME/.vimrc"

echo "Erstelle Konfig für vim gemäß Kurs-StyleGuide ..."
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

EOF
