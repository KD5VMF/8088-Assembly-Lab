# TimeSync88 REV8 serial protocol

9600 8N1 recommended. No flow control.

DOS -> Windows once per second:

```text
DYYYYMMDDHHMMSS
```

Windows -> DOS correction packet, REV8 preferred:

```text
TYYYYMMDDHHMMSSD
```

or:

```text
TYYYYMMDDHHMMSSS
```

Meaning:

- `D` = Windows local time is currently daylight-saving time.
- `S` = Windows local time is currently standard time.

Backward-compatible packets without the final flag are still accepted:

```text
TYYYYMMDDHHMMSS
```

DOS -> Windows acknowledgment after successfully setting and verifying DOS date/time:

```text
AOK
```

REV8 remains tolerant of one or more junk characters before `D` or `T`.


## REV8 year handling

The packet still uses `TYYYYMMDDHHMMSS[D|S]`, for example `T20260531150705D`. The DOS receiver splits `2026` into `20` century and `26` two-digit RTC year. DOS gets `2026`; CMOS register `09h` gets `26`; CMOS century register `32h` gets `20` when supported.
