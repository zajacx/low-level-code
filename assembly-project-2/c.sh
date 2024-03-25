#!/bin/bash

nasm -f elf64 -w+all -w+error -o aksocrypt.o aksocrypt.asm
ld --fatal-warnings -o aksocrypt aksocrypt.o

if [ $? -eq 0 ]; then
    echo "slay!"
else
    echo "flop..."
fi
