# Peripheral Overview

## Architecture Summary

NovumOS-16bit communicates with hardware peripherals through a simple I/O port address space using dedicated `IN` and `OUT` instructions. Each peripheral is assigned a fixed I/O port address.

## I/O Port Address Map

| Port | Peripheral | Direction | Description |
|------|-----------|-----------|-------------|
| `0x00` | UART | R/W | Terminal I/O (IN = read char, OUT = write char) |
| `0x01` | Timer | Read | Cycle counter (low 16 bits) |
| `0x02` | Keyboard | Read | Scan code (0 if empty) |

## IN and OUT Instructions

The CPU provides two instructions for accessing I/O ports:

### IN Instruction — Reading from a Peripheral

The `IN` instruction reads a 16-bit value from an I/O port address into a register.

**Syntax:** `IN AX, port`

**Examples:**
```asm
IN AX, 0x00    ; Read character from UART (0 = no data)
IN AX, 0x01    ; Read timer tick count
IN AX, 0x02    ; Read keyboard scan code (0 = empty)
```

### OUT Instruction — Writing to a Peripheral

The `OUT` instruction writes a 16-bit value from a register to an I/O port address.

**Syntax:** `OUT port, AX`

**Examples:**
```asm
OUT 0x00, AX   ; Write character to UART terminal
```

## UART (Port 0x00)

Simple terminal I/O port. No status registers, no baud rate configuration.

- **OUT 0x00, char** — Sends a character to the terminal output buffer
- **IN AX, 0x00** — Reads a character from the terminal input buffer (returns 0 if empty)

## Timer (Port 0x01)

Simple cycle counter that increments each CPU step.

- **IN AX, 0x01** — Returns the low 16 bits of the cycle counter

## Keyboard (Port 0x02)

Scan code buffer from keyboard input.

- **IN AX, 0x02** — Reads next scan code from buffer (returns 0 if empty)
