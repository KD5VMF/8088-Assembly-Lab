@ECHO OFF
REM Clean build outputs in the current directory.
IF EXIST *.OBJ DEL *.OBJ
IF EXIST *.MAP DEL *.MAP
IF EXIST *.EXE DEL *.EXE
IF EXIST *.COM DEL *.COM
ECHO Clean complete.
