MIPS Memory Grid Challenge
Simon-style memory game written in MIPS assembly for the MARS simulator. The program displays a 3x3 grid using the MARS Bitmap Display, flashes a random tile sequence, and asks the user to repeat the pattern with keys 1 through 9.

Features
3x3 numbered memory grid rendered with the MARS Bitmap Display
Random sequence generation that increases each round
MMIO keyboard polling for user input
Visual feedback when tiles flash
Sound feedback using MARS MIDI syscalls
Win and lose states with final round reporting
Procedure-based organization for drawing, input, timing, and game logic
Technologies
MIPS assembly
MARS MIPS simulator
Bitmap Display tool
Keyboard and Display MMIO Simulator
How to Run
Open LFP3_szd5538.asm in MARS.
Open Tools > Bitmap Display and use these settings:
Unit Width: 8
Unit Height: 8
Display Width: 256
Display Height: 256
Base Address: 0x10040000
Click Connect to MIPS in the Bitmap Display.
Open Tools > Keyboard and Display MMIO Simulator.
Click Connect to MIPS in the MMIO Simulator.
Assemble and run the program.
Use keys 1 through 9 to repeat the displayed sequence.
Controls
1 2 3
4 5 6
7 8 9
What I Learned
This project helped me practice low-level programming concepts, including memory-mapped I/O, bitmap display addressing, procedure calls, stack usage, random number syscalls, timing delays, and interactive program flow in assembly.
