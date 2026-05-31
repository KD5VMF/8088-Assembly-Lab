# Tools folder

This folder is intentionally empty except for this note.

Do not commit proprietary or third-party executables here unless their license allows redistribution.

Recommended local-only tools:

```text
TASM.EXE      Borland/Turbo Assembler, user-supplied
TLINK.EXE     Borland/Turbo Linker, user-supplied
KERMIT.EXE    MS-DOS Kermit for the DOS machine
Tera Term     Terminal emulator on the modern PC
```

Suggested local-only layout after cloning:

```text
tools/
├── local-only/
│   ├── TASM.EXE
│   ├── TLINK.EXE
│   └── KERMIT.EXE
└── README.md
```

The `.gitignore` file excludes common executable/build outputs so they do not accidentally get committed.
