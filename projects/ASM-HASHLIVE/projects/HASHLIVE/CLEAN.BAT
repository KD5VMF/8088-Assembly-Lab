@echo off
rem Remove local build products only.

if exist HASHLIVE.OBJ del HASHLIVE.OBJ
if exist HASHLIVE.MAP del HASHLIVE.MAP
if exist HASHLIVE.EXE del HASHLIVE.EXE

echo Clean complete.
