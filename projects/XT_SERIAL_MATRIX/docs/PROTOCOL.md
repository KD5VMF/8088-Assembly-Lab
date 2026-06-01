# Serial Protocol

The protocol is plain ASCII so it can be watched with a terminal program or serial analyzer.

## Request from XT to PC

```text
MAT,SEQ,SIZE,SEEDA,SEEDB*CHK
```

Example:

```text
MAT,00001,04096,12345,54321*XX
```

Fields:

```text
MAT      request type
SEQ      5-digit job sequence number
SIZE     matrix dimension, usually 04096
SEEDA    random seed for matrix A
SEEDB    random seed for matrix B
CHK      XOR checksum over everything before the asterisk
```

## Response from PC to XT

```text
RSP,SEQ,SIZE,SEEDA,SEEDB,SUMMOD,DIAGMOD,C00,CMID,CLAST,MS*CHK
```

Fields:

```text
RSP      response type
SEQ      matching job sequence number
SIZE     matrix dimension
SEEDA    matrix A seed used
SEEDB    matrix B seed used
SUMMOD   rolling checksum/fingerprint of calculated result samples
DIAGMOD  diagonal-style checksum/fingerprint
C00      calculated sample cell near top-left
CMID     calculated sample cell near center
CLAST    calculated sample cell near bottom-right
MS       PC calculation time in milliseconds
CHK      XOR checksum over everything before the asterisk
```

## Checksum

The checksum is a simple XOR of all ASCII characters before the `*`.

Example body:

```text
MAT,00001,04096,12345,54321
```

The sender XORs each character in that body and appends two uppercase hexadecimal digits.
