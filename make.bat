@echo off

REM odin build source\ -out:build\main_dbg.exe -debug
odin build source\ -out:build\main.exe -o:speed

REM odin build ply\ -out:build\ply.exe -debug
REM odin build kd_tree\ -out:build\kd.exe -o:speed

