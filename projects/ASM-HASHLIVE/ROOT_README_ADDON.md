## Add this row to the Current projects table

```markdown
| HASHLIVE | `projects/HASHLIVE/` | Live 8088/8086 custom HASH32 benchmark. Green-on-black direct text output with hashes/sec, bytes/sec, totals, elapsed time, live hash value, and activity bar. |
```

## Add this section if you want a project highlight

```markdown
## HASHLIVE

`HASHLIVE` is a live DOS hash-style benchmark for 8088/8086 systems. It uses a custom 32-bit rolling HASH32 mixer over a 256-byte internal data block and shows live hashes/sec, bytes/sec, total hashes, total bytes, elapsed time, and the current hash value.

It writes directly to `B800h` text video memory for a clean green-on-black display and performs no disk writes while running.

Build it with the same classic workflow used by the rest of this repository:

```bat
tasm HASHLIVE
tlink HASHLIVE
```

Run:

```bat
HASHLIVE
```
```
