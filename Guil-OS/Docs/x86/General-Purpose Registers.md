General-Purpose Registers
These are 16-bit registers that can be used for a wide range of operations. They can also be accessed as two separate 8-bit registers.

AX (Accumulator): Used for arithmetic operations and I/O.

AH (High 8 bits)

AL (Low 8 bits)

BX (Base): Often used for addressing memory.

BH (High 8 bits)

BL (Low 8 bits)

CX (Counter): Serves as a loop counter.

CH (High 8 bits)

CL (Low 8 bits)

DX (Data): Used for I/O, multiplication, and division.

DH (High 8 bits)

DL (Low 8 bits)

Segment Registers
These registers define the location of different segments in memory. In 16-bit real mode, the physical address is calculated as (Segment << 4) + Offset.

CS (Code Segment): Points to the current code being executed.

DS (Data Segment): Points to the data used by the program.

SS (Stack Segment): Points to the base of the stack.

ES (Extra Segment): An additional data segment register.

Pointer & Index Registers
Used for addressing data within a segment.

SP (Stack Pointer): Points to the top of the stack.

BP (Base Pointer): Used to access data on the stack, especially function parameters and local variables.

SI (Source Index): Used as an index for source data in string operations.

DI (Destination Index): Used as an index for destination data in string operations.

Common Instructions
Data Movement
MOV dest, src: Copies data from src to dest.

PUSH src: Pushes the value of src onto the stack.

POP dest: Pops the top value from the stack into dest.

XCHG dest, src: Exchanges the values of dest and src.

Arithmetic & Logic
ADD dest, src: Adds src to dest.

SUB dest, src: Subtracts src from dest.

INC dest: Increments dest by 1.

DEC dest: Decrements dest by 1.

MUL src: Multiplies AL by src (8-bit) or AX by src (16-bit).

DIV src: Divides AX by src.

AND dest, src: Performs a bitwise AND.

OR dest, src: Performs a bitwise OR.

XOR dest, src: Performs a bitwise XOR.

NOT dest: Flips all bits in dest.

Control Flow
JMP label: Unconditional jump to label.

CMP dest, src: Compares dest and src and sets status flags.

Conditional Jumps:

JE/JZ (Jump if Equal/Zero)

JNE/JNZ (Jump if Not Equal/Not Zero)

JG/JNLE (Jump if Greater/Not Less or Equal)

JL/JNGE (Jump if Less/Not Greater or Equal)

CALL procedure: Jumps to procedure and pushes the return address onto the stack.

RET: Returns from a procedure by popping the return address from the stack.

String Operations
These instructions work with DS:SI (source) and ES:DI (destination) and are often used with the REP prefix.

MOVSB/MOVSW: Moves a byte/word from DS:SI to ES:DI.

LODSB/LODSW: Loads a byte/word from DS:SI into AL/AX.

STOSB/STOSW: Stores a byte/word from AL/AX into ES:DI.

CMPSB/CMPSW: Compares the byte/word at DS:SI with the one at ES:DI.

SCASB/SCASW: Scans a string for a value in AL/AX.

Key Concepts
Flags Register: A 16-bit register where each bit represents a status flag. The Zero Flag (ZF), Carry Flag (CF), and Sign Flag (SF) are particularly important for conditional jumps.

Real Mode: The operating mode of 16-bit x86 processors where memory is addressed using the segment:offset scheme, providing access to up to 1 MB of RAM.