/// NovumOS-16bit Configuration
///
/// Central debug and build settings.

pub const Debug = struct {
    /// Enable CPU instruction trace in interactive mode
    pub const trace_instructions = false;

    /// Print poll counters every N cycles (0 = disabled)
    pub const poll_interval: u32 = 0;

    /// Print UART RX/TX activity
    pub const uart_debug = false;

    /// Print key events as they arrive
    pub const key_debug = false;
};

pub const Build = struct {
    /// Firmware file path (relative to project root)
    pub const firmware_path = "build/kernel.bin";

    /// Kernel binary path
    pub const kernel_path = "build/kernel.bin";
};
