# Computer-architecture
All programs are written for x86 DOS machines using Turbo Assembler and DosBox.

There is a handy little script `run.bat` which builds and runs a specified program.

## HW1_*
Simple example programs

## HW2
Creates a MD2 chesksum of a specified file

❗️ Doesn't provide a way to update checksum i.e. it reads the whole file into memory, might run out of memory 

## HW3
Provides hex output of a given file 

## HW4 - a partial disassembler
Only disassembles COM files

Example program for disassembly `com0.asm`

`runcom.bat` - a simple script to build `.asm` files into `.com` executables and run them

### List of opcodes implemented:

#### PUSH
- [x] 2nd varaint

#### POP
- [x] 1st variant
- [x] 2nd variant
- [x] 3rd variant
 
#### AND
- [X] 1st variant
- [x] 2nd variant
- [x] 3rd variant

#### DEC
- [x] 1st variant
- [x] 2nd variant
- [x] 3rd variant

#### LOOPS
- [x] LOOP
- [x] LOOPE
- [x] LOOPNE

#### Other
- [x] NOP
- [x] LDS
- [x] LEA
