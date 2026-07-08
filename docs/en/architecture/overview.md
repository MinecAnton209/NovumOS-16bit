# CPU Architecture Overview

[← Back to Main](../README.md) | [Registers](registers.md) | [Execution Cycle](execution-cycle.md) | [Memory Map](memory-map.md)

---

## Block Diagram

```mermaid
graph TB
    subgraph ClockGen["Clock Generator"]
        OSC["Crystal Oscillator<br/>(TTL)"]
        CLK["Clock Signal<br/>(CLK)"]
        OSC --> CLK
    end

    subgraph ControlUnit["Control Unit"]
        CU_INSTR["Instruction Register<br/>(IR)"]
        CU_DEC["Instruction Decoder<br/>(Combinational Logic)"]
        CU_SEQ["Sequencer<br/>(State Machine)"]
        CU_INSTR --> CU_DEC
        CU_DEC --> CU_SEQ
    end

    subgraph ALU_System["ALU Subsystem"]
        ALU_A["Operand A<br/>(from Reg File)"]
        ALU_B["Operand B<br/>(from MUX)"]
        ALU_MOD["4-bit NAND ALU<br/>× 4 modules"]
        ALU_OUT["Result Bus"]
        ALU_FLAGS["Flag Latch"]
        ALU_A --> ALU_MOD
        ALU_B --> ALU_MOD
        ALU_MOD --> ALU_OUT
        ALU_MOD --> ALU_FLAGS
    end

    subgraph RegisterFile["Register File"]
        AX["AX (Accumulator)"]
        BX["BX (Base)"]
        CX["CX (Counter)"]
        DX["DX (Data)"]
        IP["IP / PC<br/>(Program Counter)"]
        SP["SP<br/>(Stack Pointer)"]
        FLAGS["FLAGS<br/>(Z, C, S)"]
    end

    subgraph BusInterface["Bus Interface Unit"]
        ADDR_MUX["Address MUX"]
        DATA_BUS["Data Bus<br/>(16-bit)"]
        ADDR_BUS["Address Bus<br/>(16-bit)"]
        CONTROL_BUS["Control Bus<br/>(RD, WR, MIO)"]
    end

    subgraph I/OController["I/O Controller"]
        IO_MUX["I/O Port MUX"]
        IO_DECODE["Port Decoder"]
    end

    subgraph Memory["Memory (64 KB)"]
        MEM["RAM / ROM<br/>(65536 bytes)"]
    end

    subgraph Peripherals["Peripheral Devices"]
        PIC["PIC 8259"]
        PIT["PIT 8254"]
        UART["UART 16550"]
        VGA["VGA Text Adapter"]
    end

    CLK --> CU_SEQ
    CU_SEQ -->|"instruction select"| CU_INSTR
    CU_SEQ -->|"reg read/write"| RegisterFile
    CU_SEQ -->|"ALU op select"| ALU_MOD
    CU_SEQ -->|"bus control"| BusInterface
    CU_SEQ -->|"I/O control"| I/OController

    AX --> ALU_A
    BX --> ALU_A
    CX --> ALU_A
    DX --> ALU_A

    ALU_OUT --> AX
    ALU_OUT --> BX
    ALU_OUT --> CX
    ALU_OUT --> DX
    ALU_FLAGS --> FLAGS

    IP --> ADDR_MUX
    SP --> ADDR_MUX
    AX --> ADDR_MUX
    BX --> ADDR_MUX
    ADDR_MUX --> ADDR_BUS
    AX --> DATA_BUS
    BX --> DATA_BUS
    CX --> DATA_BUS
    DX --> DATA_BUS

    DATA_BUS <--> MEM
    ADDR_BUS --> MEM
    CONTROL_BUS --> MEM

    IO_MUX <-->|I/O ports| Peripherals
    CONTROL_BUS --> IO_MUX
    IO_DECODE --> IO_MUX
```

---

## Component Descriptions

### 1. Clock Generator

The clock signal drives all sequential logic in the CPU. Built from a TTL crystal oscillator circuit, it provides a stable clock to synchronize all operations.

| Parameter | Description |
|-----------|-------------|
| Source | Crystal oscillator (quartz) |
| Distribution | Global clock line to all flip-flops |
| Timing | All operations are edge-triggered (rising edge) |
| Duty cycle | 50% (symmetric) |

Every instruction cycle and memory access is synchronized to this clock. The clock period determines the minimum execution time for any single operation.

---

### 2. Control Unit

The Control Unit is the "brain" of the CPU. It fetches instructions from memory, decodes them, and generates all control signals to orchestrate the rest of the CPU.

```mermaid
graph LR
    subgraph ControlUnit["Control Unit"]
        IR["Instruction Register<br/>(IR)"]
        DEC["Instruction Decoder<br/>(Combinational Logic)"]
        SEQ["Micro-sequencer<br/>(Finite State Machine)"]
        CTRL_OUT["Control Signal Bus"]
    end

    IP -->|"fetch address"| IR
    IR -->|"instruction bits"| DEC
    DEC -->|"microcode/FSM"| SEQ
    SEQ -->|"16+ control lines"| CTRL_OUT
```

#### Instruction Register (IR)

- Latches the current instruction word (16 or 32 bits) from the data bus
- Holds the instruction stable during the decode and execute phases
- For 32-bit instructions, performs a second fetch to load the upper 16 bits

#### Instruction Decoder

- Pure combinational logic (NAND gates)
- Decodes opcode field from IR into control signals
- Determines: operation type, source/destination registers, addressing mode, immediate value
- Outputs: ALU operation select, register read/write enables, bus direction, memory/IO select

#### Micro-Sequencer

- Finite state machine that sequences through the phases of each instruction
- Generates timing signals for: FETCH → DECODE → EXECUTE → WRITEBACK
- Handles multi-cycle instructions (e.g., memory indirect addressing requires additional cycles)
- Manages interrupts: checks INT line after each instruction completes

---

### 3. ALU (Arithmetic Logic Unit)

The ALU is the computational core. It is built entirely from NAND gates (К155ЛА3 / 7400 series) and operates on 16-bit operands through four cascaded 4-bit modules.

#### NAND-Based ALU Design

The fundamental building block is the NAND gate (7400 quad NAND IC). From NAND gates, all other logic functions can be derived:

| Function | NAND Implementation |
|----------|---------------------|
| AND | NAND → NOT (inverted NAND output) |
| OR | De Morgan: A OR B = NOT(NOT(A) AND NOT(B)) |
| XOR | Combination of NAND gates |
| NOT | Single NAND input tied together |
| Full Adder | XOR + AND + OR from NAND gates |

#### 4-bit Module Structure

Each 4-bit ALU module contains:

```mermaid
graph TB
    subgraph Module["4-bit ALU Module (×4)"]
        subgraph BitSlice["Per-bit logic (×4)"]
            FA["Full Adder<br/>(NAND-based)"]
            LOGIC["Logic Unit<br/>(NAND-based)"]
            MUX["Result MUX"]
        end
        CARRY_IN["Carry In"]
        CARRY_OUT["Carry Out"]
    end

    A_IN["A[3:0]"] --> FA
    B_IN["B[3:0]"] --> FA
    A_IN --> LOGIC
    B_IN --> LOGIC
    CARRY_IN --> FA
    FA --> MUX
    LOGIC --> MUX
    MUX --> RESULT["Result[3:0]"]
    FA --> CARRY_OUT
```

Each bit slice computes:
- **Arithmetic**: Full adder sum and carry
- **Logic**: AND, OR, XOR operations
- **Selection**: MUX selects between arithmetic and logic result based on ALU operation code

#### Chaining 4-bit Modules to 16-bit

```mermaid
graph LR
    MOD0["Module 0<br/>(bits 0-3)"]
    MOD1["Module 1<br/>(bits 4-7)"]
    MOD2["Module 2<br/>(bits 8-11)"]
    MOD3["Module 3<br/>(bits 12-15)"]

    CIN["Carry In (0)"]
    COUT["Carry Out"]

    CIN --> MOD0
    MOD0 -->|"Cout→Cin"| MOD1
    MOD1 -->|"Cout→Cin"| MOD2
    MOD2 -->|"Cout→Cin"| MOD3
    MOD3 --> COUT

    A_BUS["A[15:0]"] -->|"A[3:0]"| MOD0
    A_BUS -->|"A[7:4]"| MOD1
    A_BUS -->|"A[11:8]"| MOD2
    A_BUS -->|"A[15:12]"| MOD3

    B_BUS["B[15:0]"] -->|"B[3:0]"| MOD0
    B_BUS -->|"B[7:4]"| MOD1
    B_BUS -->|"B[11:8]"| MOD2
    B_BUS -->|"B[15:12]"| MOD3
```

- The carry output of each module feeds the carry input of the next
- This ripple-carry chain enables 16-bit addition/subtraction
- The final carry out sets the Carry (C) flag
- Zero detection: OR of all 16 result bits (if all zero → Z flag set)
- Sign detection: MSB of result (bit 15 → S flag)

---

### 4. Register File

See [Registers](registers.md) for full details.

```mermaid
graph TB
    subgraph RegFile["Register File (16-bit wide)"]
        AX["AX<br/>(Accumulator)<br/>16 bits"]
        BX["BX<br/>(Base)<br/>16 bits"]
        CX["CX<br/>(Counter)<br/>16 bits"]
        DX["DX<br/>(Data)<br/>16 bits"]
        IP["IP/PC<br/>(Program Counter)<br/>16 bits"]
        SP["SP<br/>(Stack Pointer)<br/>16 bits"]
        FLAGS["FLAGS<br/>(Z, C, S)<br/>16 bits"]
    end

    subgraph RegAccess["Register Access"]
        RD_A["Read Port A"]
        RD_B["Read Port B"]
        WR["Write Port"]
    end

    AX --- RD_A
    BX --- RD_A
    CX --- RD_A
    DX --- RD_A
    AX --- RD_B
    BX --- RD_B
    CX --- RD_B
    DX --- RD_B
    AX --- WR
    BX --- WR
    CX --- WR
    DX --- WR
```

| Feature | Description |
|---------|-------------|
| Ports | 2 read, 1 write (simultaneous) |
| Encoding | 2-bit register select: AX=00, BX=01, CX=10, DX=11 |
| Special | IP, SP, FLAGS not directly encoded in general instructions |
| Write enable | Controlled by decode logic per instruction |

---

### 5. Bus Interface Unit (BIU)

The BIU manages all communication between the CPU and external devices (memory, I/O).

```mermaid
graph TB
    subgraph BIU["Bus Interface Unit"]
        ADDR_REG["Address Register<br/>(16-bit)"]
        DATA_REG["Data Register<br/>(16-bit latch)"]
        MUX_A["Address Source MUX<br/>IP / SP / Reg / Imm"]
        TRISTATE["Tri-state Buffers"]
    end

    IP --> MUX_A
    SP --> MUX_A
    AX --> MUX_A
    BX --> MUX_A
    IMM["Immediate Offset"] --> MUX_A
    MUX_A --> ADDR_REG
    ADDR_REG -->|"16-bit Address Bus"| EXT_ADDR["External Address Bus"]
    TRISTATE <-->|"16-bit Data Bus"| EXT_DATA["External Data Bus"]
    DATA_REG --> TRISTATE
    TRISTATE --> DATA_REG
```

| Signal | Direction | Description |
|--------|-----------|-------------|
| `ADDR[15:0]` | Output | Memory/IO address |
| `DATA[15:0]` | Bidirectional | 16-bit data transfer |
| `RD` | Output | Read strobe (active low) |
| `WR` | Output | Write strobe (active low) |
| `M/IO` | Output | Memory vs I/O select (0=I/O, 1=Memory) |
| `CLK` | Input | System clock |
| `WAIT` | Input | Wait state input (for slow devices) |
| `INT` | Input | Interrupt request |

---

### 6. I/O Controller

Manages communication with peripheral devices through isolated I/O port addressing.

```mermaid
graph TB
    subgraph IOController["I/O Controller"]
        PORT_DEC["Port Address Decoder<br/>(combinational)"]
        IO_RD["I/O Read Logic"]
        IO_WR["I/O Write Logic"]
    end

    ADDR_LOW["ADDR[7:0]"] --> PORT_DEC
    PORT_DEC --> IO_RD
    PORT_DEC --> IO_WR

    subgraph Devices["I/O Ports"]
        PIC_PORT["PIC: 0x20-0x21"]
        PIT_PORT["PIT: 0x40-0x43"]
        UART_PORT["UART: 0x3F8-0x3FF"]
    end

    IO_RD <--> Devices
    IO_WR <--> Devices
```

See [Memory Map - I/O Port Map](memory-map.md#io-port-map) for the complete port allocation.

---

## Data Paths

### Data Path Diagram

```mermaid
graph TB
    subgraph Internal["Internal CPU Data Paths"]
        REG_OUT_A["Register A Output"]
        REG_OUT_B["Register B Output"]
        ALU_IN_A["ALU Input A"]
        ALU_IN_B["ALU Input B"]
        ALU_RESULT["ALU Result"]
        WRITE_BACK["Write-back Bus"]
        IMM_MUX["Immediate MUX"]
    end

    REGS["Register File"] -->|"Port A"| REG_OUT_A
    REGS["Register File"] -->|"Port B"| REG_OUT_B

    REG_OUT_A --> ALU_IN_A
    REG_OUT_B --> IMM_MUX
    IMM["Immediate Value"] --> IMM_MUX
    IMM_MUX --> ALU_IN_B

    ALU_IN_A --> ALU["ALU"]
    ALU_IN_B --> ALU
    ALU --> ALU_RESULT

    ALU_RESULT --> WRITE_BACK
    MEM["Memory"] <-->|"Data Bus"| WRITE_BACK
    WRITE_BACK -->|"Write data"| REGS
```

### Bus Width Summary

| Bus | Width | Purpose |
|-----|-------|---------|
| Data bus | 16-bit | Instruction/data transfer |
| Address bus | 16-bit | Memory addressing (64 KB) |
| I/O address bus | 8-bit (decoded from 16-bit) | Peripheral port addressing |
| Control bus | 4+ signals | RD, WR, M/IO, interrupt |

---

## Clock and Timing

### Clock Distribution

```mermaid
graph LR
    OSC["Crystal<br/>Oscillator"] -->|"CLK"| CLK_BUF["Clock Buffer<br/>(Fan-out driver)"]
    CLK_BUF --> CU["Control Unit"]
    CLK_BUF --> REGS["Registers"]
    CLK_BUF --> ALU["ALU (latches)"]
    CLK_BUF --> BIU["Bus Interface"]
    CLK_BUF --> IOC["I/O Controller"]
```

### Timing Overview

Each instruction completes in a fixed number of clock cycles, determined by the instruction type:

| Instruction Type | Cycles | Description |
|------------------|--------|-------------|
| Register-register (MOV, ADD, AND, etc.) | 2 | Fetch (1) + Execute (1) |
| Register-immediate | 2 | Fetch (1) + Execute (1) |
| Memory load/store | 3 | Fetch (1) + Address calc (1) + Memory access (1) |
| Jump (unconditional) | 2 | Fetch (1) + Branch (1) |
| Jump (conditional, taken) | 2 | Fetch (1) + Branch (1) |
| Jump (conditional, not taken) | 1 | Fetch (1) — no branch |
| I/O port read/write | 2 | Fetch (1) + I/O access (1) |
| 32-bit instruction | 3 | Fetch 1 (1) + Fetch 2 (1) + Execute (1) |

### Clock Edge Convention

- All registers update on the **rising edge** of CLK
- Combinational logic (ALU, decoder) settles during the clock low phase
- Setup and hold times are met by the rising-edge trigger

---

## Interrupt Handling

When the `INT` line is asserted by the PIC 8259:

1. Current instruction completes (never interrupted mid-cycle)
2. Program Counter (IP) is pushed onto the stack
3. FLAGS are saved on the stack
4. IP is loaded with the interrupt vector address
5. Interrupt service routine executes
6. `RET` (or IRET) restores FLAGS and IP from stack

```mermaid
sequenceDiagram
    participant CPU as CPU
    participant PIC as PIC 8259
    participant ISR as Interrupt Handler

    Note over PIC: Device requests interrupt
    PIC->>CPU: INT signal asserted
    Note over CPU: Current instruction completes
    CPU->>CPU: Push FLAGS to stack
    CPU->>CPU: Push IP to stack
    CPU->>CPU: Load IP from vector table
    CPU->>ISR: Execute ISR
    ISR->>CPU: Send EOI to PIC
    ISR->>CPU: IRET (pop IP, FLAGS)
    Note over CPU: Resume normal execution
```

---

## Summary

The NovumOS-16bit CPU is a complete, working processor built from fundamental TTL logic. The NAND-based ALU, RISC-like ISA, and standard peripheral interfaces create a practical and educational platform for understanding computer architecture from the ground up.

| Block | Key Function |
|-------|-------------|
| Clock Generator | Synchronizes all operations |
| Control Unit | Decodes instructions, sequences operations |
| ALU | Performs arithmetic and logic (NAND-based) |
| Register File | Stores operands and results |
| Bus Interface | Manages memory/IO data transfer |
| I/O Controller | Interfaces with peripheral devices |

---

*See [Registers](registers.md) for detailed register specifications.*
