# Serial Wiring Notes

## Basic null-modem wiring

For the simplest polled 3-wire setup:

```text
XT/8088 DB9 pin 3 TXD  -> PC DB9 pin 2 RXD
XT/8088 DB9 pin 2 RXD  <- PC DB9 pin 3 TXD
XT/8088 DB9 pin 5 GND  -- PC DB9 pin 5 GND
```

For DB25 serial ports, common pins are:

```text
DB25 pin 2 TXD
DB25 pin 3 RXD
DB25 pin 7 GND
```

The program uses no hardware flow control, so RTS/CTS are not required for the basic setup.

## COM base addresses

Typical DOS COM addresses:

```text
COM1  03F8h
COM2  02F8h
COM3  03E8h
COM4  02E8h
```

The ASM program lets you choose COM1 through COM4 at startup.

## Recommended first test

Use:

```text
9600 baud
8N1
No parity
No flow control
```

Start the PC app first, then start the XT program.
