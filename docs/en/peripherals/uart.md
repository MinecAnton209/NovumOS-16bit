# Simple UART

## Overview

NovumOS uses a simplified UART implementation for terminal I/O. It is not a 16550 or any standard UART chip. There are no status registers, no FIFO, no baud rate configuration, and no interrupts. Character I/O is entirely polled, character by character.

## Port Address

| Port | Direction | Description          |
|------|-----------|----------------------|
| 0x00 | OUT       | Send character       |
| 0x00 | IN        | Receive character    |

## OUT 0x00 — Send Character

Write a character to port 0x00 to send it to the terminal.

```asm
mov al, 'A'
out 0x00, al
```

The character is placed into a transmit buffer in the emulator. The buffer is flushed to the terminal automatically. You do not need to wait for any status flag.

## IN AX, 0x00 — Receive Character

Read a character from port 0x00. If a character is available it is returned in `AL`. If no character is waiting, `0` is returned.

```asm
in al, 0x00
cmp al, 0
je no_input
; process character in AL
```

### Polling Loop

To wait for input, poll in a loop:

```asm
wait_for_input:
    in al, 0x00
    cmp al, 0
    je wait_for_input
; AL now contains the pressed character
```

## Emulator Behavior

- **TX buffer**: Characters written to port 0x00 are buffered by the emulator and displayed in the terminal window. The buffer is flushed after each write.
- **RX polling**: The emulator captures keyboard input. If the user has pressed a key since the last read, that key is returned. Otherwise `0` is returned.
- **No blocking**: Reads never block the CPU. If nothing is available, the read returns immediately with `0`.
- **No interrupts**: All input must be polled. There is no IRQ line for keyboard or serial input.

## Limitations

- No flow control (XON/XOFF or RTS/CTS).
- No break detection.
- No error status (framing, overrun, parity).
- One character at a time. No bulk transfer mechanism.
