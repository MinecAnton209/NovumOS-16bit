# Peripheral Overview

## Architecture Summary

NovumOS-16bit communicates with hardware peripherals through a simple I/O port address space using dedicated `IN` and `OUT` instructions. Each peripheral is assigned a fixed I/O port address. The CPU uses a flat 64 KB memory model with no memory-mapped I/O — all peripheral interaction is through port I/O.

## I/O Port Address Map

| Port | Peripheral | Direction | Description |
|------|-----------|-----------|-------------|
| `0x00` | UART | R/W | Terminal I/O (OUT=send character, IN=read character) |
| `0x01` | Timer | Read | Cycle counter (low 16 bits of `cycle_count`) |
| `0x02` | Keyboard | Read | Scancode from ring buffer (0 if empty) |
| `0x03` | Line cmd_id | Read | Shell command ID (clears on read) |
| `0x04` | Line buffer | Read | Next byte from line buffer (0 if empty) |
| `0x10` | VGA char | Write | Character to VGA text buffer at cursor position |
| `0x11` | VGA control | Write | Control commands: 0x0001=clear, 0x0002=flush |
| `0x05`–`0xFF` | Generic | R/W | Generic I/O ports (storage, no attached device) |

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
IN AX, 0x03    ; Read command ID (0=none, 1=help, ...), clears on read
IN AX, 0x04    ; Read next byte from line buffer (0 = empty)
```

### OUT Instruction — Writing to a Peripheral

The `OUT` instruction writes a 16-bit value from a register to an I/O port address.

**Syntax:** `OUT port, AX`

**Examples:**
```asm
OUT 0x00, AX   ; Write character to UART terminal
OUT 0x10, AX   ; Write character to VGA text buffer at cursor
OUT 0x11, AX   ; Send control command to VGA (clear or flush)
```

## UART (Port 0x00)

Simple terminal I/O port. No status registers, no baud rate configuration, no interrupts.

- **OUT 0x00, AL** — Sends a character to the terminal output
- **IN AX, 0x00** — Reads a character from the terminal input (returns 0 if empty)

## Timer (Port 0x01)

Simple cycle counter that increments each CPU step.

- **IN AX, 0x01** — Returns the low 16 bits of the cycle counter (`cycle_count & 0xFFFF`)

## Keyboard (Port 0x02)

Scan code buffer from keyboard input. The emulator writes scancodes to a ring buffer in a non-blocking manner.

- **IN AX, 0x02** — Reads next scancode from buffer (returns 0 if empty)

## Line Interface (Ports 0x03 and 0x04)

The line interface provides shell command data to firmware. When the user types a line and presses Enter in interactive mode, the emulator parses the input, sets a command ID at port 0x03, and copies the argument bytes into the line buffer at port 0x04.

### Port 0x03 — Command ID

Read returns the current command ID, then clears it to 0. The following values are defined:

| Value | Command | Description |
|-------|---------|-------------|
| 0 | None | No pending command (idle) |
| 1 | help | Print help text |
| 2 | clear | Clear the screen |
| 3 | reboot | Warm reboot (jump to firmware start) |
| 4 | info | Print system information |
| 5 | dump | Dump memory contents |
| 6 | halt | Halt the CPU |
| 7 | unknown | Unrecognized command |

### Port 0x04 — Line Buffer

Read returns the next byte from the argument line buffer, advancing the internal read position. Returns 0 if the buffer is exhausted or empty. The firmware typically reads cmd_id first, then drains the line buffer byte by byte to obtain the command argument string.

## VGA (Ports 0x10 and 0x11)

The VGA peripheral provides text-mode output via I/O ports. There is no memory-mapped VGA buffer — all character output is done by writing to port 0x10, which places the character in an internal 80×25 text buffer at the current cursor position. The cursor advances automatically after each character write.

- **OUT 0x10, AL** — Write character to VGA buffer at cursor, cursor advances
- **OUT 0x11, AX** — Control command:
  - `0x0001` — Clear screen (reset cursor to top-left, fill with spaces)
  - `0x0002` — Flush / mark dirty (trigger terminal re-render)

## Generic Ports (0x05–0xFF)

Ports 0x05 through 0xFF are general-purpose read/write storage locations (256 × 16-bit). No device is attached to these ports — they serve as scratch storage accessible via IN/OUT. The emulator maintains an array of 16-bit values that can be freely read and written.
