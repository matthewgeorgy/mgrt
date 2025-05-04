@echo off

odin build . -out:main_dbg.exe -debug
odin build . -out:main.exe -o:speed

