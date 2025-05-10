@echo off

odin build source\ -out:build\main_dbg.exe -debug
odin build source\ -out:build\main.exe -o:speed

