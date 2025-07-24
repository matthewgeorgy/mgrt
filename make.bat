@echo off

odin build source\ -out:build\mgrt_dbg.exe -debug
odin build source\ -out:build\mgrt.exe -o:speed

