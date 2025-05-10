@echo off

odin build source\ -out:main_dbg.exe -debug
odin build source\ -out:main.exe -o:speed

