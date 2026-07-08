# Programmable Interrupt Controller (8259)

## Overview

The Intel 8259 Programmable Interrupt Controller (PIC) manages hardware interrupt requests from peripherals. It arbitrates multiple IRQ lines, determines priority, and presents a single interrupt signal to the CPU. NovumOS-16bit uses one master 8259 in a simplified configuration with only IRQ0 (PIT timer) and IRQ4 (UART serial) enabled.

## Block Diagram

```mermaid
graph TB
    subgraph PIC_8259["Intel 8259 PIC"]
        IRR["Interrupt Request Register\nIRR\n(8-bit latch)"]
        ISR["In-Service Register\nISR\n(8-bit shift register)"]
        IMR["Interrupt Mask Register\nIMR\n(8-bit mask)"]
        PR["Priority Resolver\n(Combinational Logic)"]
        CMD["Command Logic\n(ICW/OCW Decoder)"]
        BUF["Data Bus Buffer\n(D0–D7)"]
        INTA["Interrupt Acknowledge\nLogic"]
        CAS["Cascade Lines\n(CAS0–CAS2)"]
    end

    IRQ0["IRQ0: PIT Timer"]
    IRQ1["IRQ1: Keyboard (reserved)"]
    IRQ2["IRQ2: Cascade"]
    IRQ3["IRQ3: Reserved"]
    IRQ4["IRQ4: UART COM1"]
    IRQ5["IRQ5: Reserved"]
    IRQ6["IRQ6: Reserved"]
    IRQ7["IRQ7: Reserved"]

    CPU_INT["CPU INTR Pin"]
    CPU_INTA["CPU INTA# Pin"]
    CPU_DATA["Data Bus (D0–D7)"]

    IRQ0 --> IRR
    IRQ1 --> IRR
    IRQ2 --> IRR
    IRQ3 --> IRR
    IRQ4 --> IRR
    IRQ5 --> IRR
    IRQ6 --> IRR
    IRQ7 --> IRR

    IRR --> PR
    IMR --> PR
    PR --> ISR
    ISR --> INTA
    INTA --> CPU_INT

    CMD <--> BUF
    BUF <--> CPU_DATA

    INTA <--> CPU_INTA

    CMD --> CAS

    style PIC_8259 fill:#1a1a2e,stroke:#e94560,color:#fff
    style CPU_INT fill:#0f3460,stroke:#e94560,color:#fff
    style CPU_INTA fill:#0f3460,stroke:#e94560,color:#fff
    style CPU_DATA fill:#0f3460,stroke:#e94560,color:#fff
```

## Register Table

### Initialization Command Words (ICW)

| Register | Port | Bits | Description |
|---|---|---|---|
| ICW1 | 0x20 | D7–D0 | Initialization command. Bit 4 must be 1. Specifies ICW4 needed, single/cascade mode, interval size, edge/level trigger. |
| ICW2 | 0x21 | D7–D0 | Vector base address. Upper 5 bits (D7–D3) define the interrupt vector number for IRQ0. Lower 3 bits (D2–D0) are overwritten by IRQ number. |
| ICW3 | 0x21 | D7–D0 | Slave program register. Not used in single 8259 mode. Present in initialization sequence for protocol compliance. |
| ICW4 | 0x21 | D7–D0 | Additional control. Bit 0 selects 8086 mode (must be 1 for NovumOS). Bit 1 enables automatic EOI. |

### Operation Command Words (OCW)

| Register | Port | Bits | Description |
|---|---|---|---|
| OCW1 | 0x21 | D7–D0 | Interrupt Mask Register (IMR). Each bit masks (disables) the corresponding IRQ. Bit 0 = IRQ0, Bit 4 = IRQ4. |
| OCW2 | 0x20 | D7–D0 | End of Interrupt (EOI) command. Bits D7–D5 encode the EOI type: non-specific EOI (001), specific EOI (011), rotate-on-non-specific (101), rotate-on-specific (111). |
| OCW3 | 0x20 | D7–D0 | Read register command. Selects which register (IRR or ISR) is read through port 0x20. Also controls poll mode and special mask mode. |

### Internal Registers

| Register | Size | Description |
|---|---|---|
| IRR (Interrupt Request Register) | 8 bits | Latches incoming IRQ signals. Bit N corresponds to IRQN. Set when an IRQ line goes active. |
| ISR (In-Service Register) | 8 bits | Tracks which IRQ is currently being serviced. Set when the CPU acknowledges the interrupt. |
| IMR (Interrupt Mask Register) | 8 bits | Masks IRQ lines. When a bit is set, the corresponding IRQ is blocked from reaching the priority resolver. |

## I/O Port Addresses

| Port Address | Read | Write |
|---|---|---|
| `0x20` | Read IRR or ISR (selected by OCW3) | Write ICW1 or OCW2/OCW3 |
| `0x21` | Read IMR | Write ICW2, ICW3, ICW4, or OCW1 |

**Note:** The PIC determines whether a read or write is ICW or OCW based on a state machine that progresses through initialization stages. Once initialized, all writes to port 0x20 are interpreted as OCW2/OCW3, and all writes to port 0x21 are interpreted as OCW1.

## Initialization Sequence

The 8259 must receive ICW1 through ICW4 in strict order during initialization. The sequence is triggered by writing ICW1 to port 0x20.

### Step-by-Step Process

```mermaid
sequenceDiagram
    participant CPU as CPU
    participant PIC as 8259 PIC

    Note over PIC: Power-On / Reset State

    CPU->>PIC: Write ICW1 to port 0x20<br/>Bit 4 = 1 (ICW4 needed)<br/>Bit 3 = 0 (single 8259)<br/>Bit 1 = 0 (edge triggered)
    Note over PIC: PIC enters ICW2 expected state

    CPU->>PIC: Write ICW2 to port 0x21<br/>D7–D3 = 0x08 (vector base = 0x08)
    Note over PIC: IRQ0 maps to vector 0x08<br/>IRQ1 maps to vector 0x09<br/>...<br/>IRQ7 maps to vector 0x0F

    PIC-->>PIC: ICW3 skipped (single mode)

    CPU->>PIC: Write ICW4 to port 0x21<br/>Bit 0 = 1 (8086 mode)<br/>Bit 1 = 0 (normal EOI)
    Note over PIC: Initialization complete

    CPU->>PIC: Write OCW1 to port 0x21<br/>Bit 0 = 0 (IRQ0 enabled)<br/>Bit 4 = 0 (IRQ4 enabled)<br/>All others = 1 (masked)
    Note over PIC: Only IRQ0 and IRQ4<br/>are now enabled
```

### Initialization State Machine

The PIC uses a state machine that advances through stages as each ICW is received:

| Stage | Current State | Next Write To | Interpreted As |
|---|---|---|---|
| Reset | A | Port 0x20 with D4=1 | ICW1 |
| Waiting for ICW2 | B | Port 0x21 | ICW2 |
| Waiting for ICW3 | C | Port 0x21 | ICW3 (skipped if single mode) |
| Waiting for ICW4 | D | Port 0x21 | ICW4 |
| Initialized | E | Port 0x20 | OCW2 or OCW3 |
| Initialized | E | Port 0x21 | OCW1 |

## IRQ Handling Flow

When a hardware interrupt occurs, the following sequence executes:

```mermaid
sequenceDiagram
    participant DEV as Peripheral
    participant PIC as 8259 PIC
    participant CPU as CPU
    participant ISR as Interrupt Handler

    DEV->>PIC: IRQ4 goes active (UART data ready)
    Note over PIC: IRR bit 4 is set

    PIC->>PIC: Compare IRQ4 against IMR<br/>Bit 4 of IMR = 0 → not masked
    PIC->>PIC: Priority Resolver checks ISR<br/>No higher-priority IRQ in service<br/>IRQ4 wins arbitration

    PIC->>CPU: INTR pin goes active

    CPU->>CPU: Complete current instruction
    CPU->>CPU: Push FLAGS register onto stack
    CPU->>CPU: Push CS register onto stack
    CPU->>CPU: Push IP register onto stack
    CPU->>CPU: Clear IF flag (disable interrupts)

    CPU->>PIC: INTA# pulse 1 (acknowledge)
    Note over PIC: PIC freezes IRR state

    CPU->>PIC: INTA# pulse 2 (read vector)
    PIC->>CPU: Place vector 0x0C on data bus
    Note over PIC: ISR bit 4 is set<br/>IRR bit 4 is cleared

    CPU->>CPU: Read vector 0x0C from data bus
    CPU->>CPU: Look up IDT entry for vector 0x0C
    CPU->>ISR: Jump to interrupt handler at IDT[0x0C]

    Note over ISR: Handler reads UART data<br/>and processes characters

    ISR->>PIC: Write non-specific EOI<br/>(OCW2 = 0x20) to port 0x20
    Note over PIC: ISR bit 4 is cleared

    ISR->>CPU: IRET instruction
    Note over CPU: Pop IP from stack<br/>Pop CS from stack<br/>Pop FLAGS from stack<br/>IF flag restored
```

## End of Interrupt (EOI) Process

After the interrupt handler completes servicing the device, it must signal the PIC that the interrupt is finished. This is done by writing an EOI command.

### EOI Types

| EOI Type | OCW2 Value | Bit Pattern | Description |
|---|---|---|---|
| Non-Specific EOI | `0x20` | `0 0 1 0 0 0 0 0` | Clears the highest-priority in-service bit. Used when the handler knows it serviced the only active interrupt. |
| Specific EOI | `0x20 + N` | `0 1 1 L2 L1 L0 0 0` | Clears a specific IRQ level (L2–L0 = IRQ number). Used when multiple IRQs may be in service simultaneously. |
| Rotate-on-Non-Specific EOI | `0xA0` | `1 0 1 0 0 0 0 0` | Clears highest-priority ISR bit and rotates priority so the serviced IRQ becomes lowest priority. |
| Rotate-on-Specific EOI | `0xE0 + N` | `1 1 1 L2 L1 L0 0 0` | Clears specific ISR bit and rotates priority. |

### EOI in NovumOS-16bit

NovumOS-16bit uses the non-specific EOI (`0x20`) for simplicity. Since only one IRQ is typically serviced at a time (IRQ0 for timer ticks or IRQ4 for UART data), the non-specific EOI clears the correct ISR bit without needing to specify which IRQ was serviced.

The EOI write sequence:

1. The handler completes its work (e.g., reads UART data, increments tick counter).
2. The handler writes `0x20` to I/O port `0x20`.
3. The PIC clears the highest-priority bit in the ISR.
4. If another IRQ is pending and unmasked, the PIC asserts INTR again.

### Critical Timing Note

The EOI **must** be sent before the `IRET` instruction. If the handler returns without sending EOI, the PIC keeps the ISR bit set, which prevents the same IRQ (and all lower-priority IRQs) from being serviced again. This is a common source of system hangs.
