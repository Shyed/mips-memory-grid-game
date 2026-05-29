# LFP3_szd5538.asm
# Sheila Demonteverde
# CMPEN 351 Final Project - Memory Grid Challenge
# Final version
#
# Description:
# Simon-style memory game on a 3x3 grid using the MARS bitmap display.
# The computer highlights a sequence of tiles. The user repeats the
# sequence using keys 1..9. The sequence gets longer each round.
#
# MARS setup:
# Bitmap Display:
# Unit Width = 8
# Unit Height = 8
# Display W = 256
# Display H = 256
# Base Addr = 0x10040000
# Keyboard and Display MMIO Simulator:
# Connect to MIPS
#
# Notes:
# - This version uses MMIO polling for keyboard input as a solid project base.
# - It is organized into procedures so it can be expanded later to interrupts, queue handling, timeouts, extra sounds, and more polish.
# - Valid keys are 1..9 based on the tile layout.
# - Each tile shows numbers to improve usability
#
#-----------------------------------------------------------------------------------
# DATA SECTION
#-----------------------------------------------------------------------------------

.data

# Strings: displayed in Run I/O window for user prompts and messages
msgTitle:	.asciiz "\nMEMORY GRID CHALLENGE\n"
msgHow:        	.asciiz "Watch the pattern, then repeat it using keys 1..9.\n"
msgRound:      	.asciiz "\nRound: "
msgWatch:      	.asciiz "\nWatch...\n"
msgTurn:       	.asciiz "Your turn. Enter the pattern one key at a time.\n"
msgPrompt:     	.asciiz "Key (1-9): "
msgBad:        	.asciiz "Invalid input. Use keys 1 through 9 only.\n"
msgLose:       	.asciiz "\nWrong pattern. Game over.\n"
msgWin:        	.asciiz "\nNice job. You finished all rounds.\n"
msgScore:      	.asciiz "Final round reached: "
msgNL:         	.asciiz "\n"

# Game constants and variables for sequence length, timing, and configuration
SEQ_MAX:       	.word   20
roundLen:      	.word   1
showOnMs:      	.word   350
showGapMs:     	.word   180
maxRounds:     	.word   8
rngID:         	.word   0
seedVal:	.word   0

# Sequence values are stored as tile indices (0-8)
sequence:      	.space  80              # 20 words

# MMIO keyboard control and data addresses
KBD_CTRL:      	.word   0xFFFF0000
KBD_DATA:      	.word   0xFFFF0004

# Base address for bitmap display
DISP_BASE:     	.word   0x10040000

# Colors used for background, tiles, and feedback
colorBG:       	.word   0x000A0A12
colorGrid:     	.word   0x003A3A48
colorText:     	.word   0x00FFFFFF
colorTile:     	.word   0x00205FA8
colorFlash:    	.word   0x00FFE066
colorLose:     	.word   0x00CC3333
colorWin:      	.word   0x0033CC66
colorFrame:    	.word   0x004A4A5E
colorDivider:  	.word   0x00262636

# Table storing position and colors for each tile in the 3x3 grid. 
# Each tile: x position, y position, normal color, flash color
TileTable:
.word  4,  4, 0x002C66B8, 0x007DB7FF   # 1
.word 13,  4, 0x002E8B57, 0x006EE7A0   # 2
.word 22,  4, 0x00995C24, 0x00FFB468   # 3
.word  4, 13, 0x008A3FB0, 0x00D78CFF   # 4
.word 13, 13, 0x00B03A48, 0x00FF8A98   # 5
.word 22, 13, 0x002C7A7B, 0x0066F2F4   # 6
.word  4, 22, 0x006A66C7, 0x00AAA6FF   # 7
.word 13, 22, 0x00A88A1F, 0x00FFE066   # 8
.word 22, 22, 0x00B14C7A, 0x00FF9FD1	# 9

# 3x5 digit patterns, each word is one row, low 3 bits used
# bit 2 = left, bit 1 = middle, bit 0 = right
DigitPatterns:
    
.word 2, 6, 2, 2, 7	# 1
.word 7, 1, 7, 4, 7	# 2
.word 7, 1, 7, 1, 7	# 3
.word 5, 5, 7, 1, 1	# 4
.word 7, 4, 7, 1, 7	# 5
.word 7, 4, 7, 5, 7	# 6
.word 7, 1, 1, 1, 1	# 7
.word 7, 5, 7, 5, 7	# 8
.word 7, 5, 7, 1, 7	# 9

.text
.globl main

#-----------------------------------------------------------------------------------
# MAIN
#-----------------------------------------------------------------------------------
main:
	jal InitRNG
	jal PrintIntro
	jal ClearScreen
	jal DrawBoard

	li $t0, 1
	sw $t0, roundLen

# Main game loop for running rounds and handling user input
GameLoop:
	jal PrintRound
	jal AppendRandomTile
	jal ShowSequence
	jal GetUserSequence
	beq $v0, $zero, LoseGame

	lw $t0, roundLen
	lw $t1, maxRounds
	beq $t0, $t1, WinGame

	addiu $t0, $t0, 1
	sw $t0, roundLen
	j GameLoop

# Ends the game and shows "lose" message
LoseGame:
	li $v0, 4
	la $a0, msgLose
	syscall

	li $a0, 220
	li $a1, 200
	jal Beep

	li $v0, 4
	la $a0, msgScore
	syscall

    	lw $a0, roundLen
	li $v0, 1
	syscall

	li $v0, 4
	la $a0, msgNL
	syscall
	j ExitProgram

# Ends the game and shows win message
WinGame:
	li $v0, 4
	la $a0, msgWin
	syscall

	li $a0, 880
	li $a1, 160
	jal Beep
	
	li $a0, 988
	li $a1, 160
	jal Beep

ExitProgram:
	li $v0, 10
	syscall

#-----------------------------------------------------------------------------------
# PrintIntro
# Displays game title and instructions to the user.
#-----------------------------------------------------------------------------------
PrintIntro:
	li $v0, 4
	la $a0, msgTitle
	syscall

    	li $v0, 4
	la $a0, msgHow
	syscall
	jr $ra

#-----------------------------------------------------------------------------------
# PrintRound
# Prints the current round number.
#-----------------------------------------------------------------------------------
PrintRound:
	li $v0, 4
	la $a0, msgRound
	syscall

	lw $a0, roundLen
	li $v0, 1
	syscall

	li $v0, 4
	la $a0, msgNL
	syscall
	jr $ra

#-----------------------------------------------------------------------------------
# InitRNG
# Seeds the MARS random number generator using syscall 30 + 40.
#-----------------------------------------------------------------------------------
InitRNG:
	li $v0, 30
	syscall
	sw $a0, seedVal

	lw $a0, rngID
	lw $a1, seedVal
	li $v0, 40
	syscall
	jr $ra

#-----------------------------------------------------------------------------------
# AppendRandomTile
# Adds one random tile index 0..8 to the sequence.
#-----------------------------------------------------------------------------------
AppendRandomTile:
	addiu $sp, $sp, -8
	sw $ra, 4($sp)
	sw $s0, 0($sp)
	
	lw $s0, roundLen
	addiu $s0, $s0, -1           	# store at sequence[roundLen-1]

	lw $a0, rngID
	li $a1, 9                  	# 0..8
	li $v0, 42
	syscall                       	# result returned in a0 in MARS

	la $t0, sequence
	sll $t1, $s0, 2
	addu $t0, $t0, $t1
	sw $a0, 0($t0)

	lw $s0, 0($sp)
	lw $ra, 4($sp)
	addiu $sp, $sp, 8
	jr $ra

#-----------------------------------------------------------------------------------
# ShowSequence
# Flashes the stored sequence from 0 to roundLen-1.
#-----------------------------------------------------------------------------------
ShowSequence:
	addiu $sp, $sp, -12
	sw $ra, 8($sp)
	sw $s0, 4($sp)
	sw $s1, 0($sp)

	li $v0, 4
	la $a0, msgWatch
	syscall

	li $s0, 0
	lw $s1, roundLen

# Displays the sequence by looping through the tiles
ShowLoop:
	beq $s0, $s1, ShowDone

	la $t0, sequence
	sll $t1, $s0, 2
	addu $t0, $t0, $t1
	lw $a0, 0($t0)             	# tile index 0..8
	jal FlashTile

	lw $a0, showGapMs
	jal SleepMs

	addiu $s0, $s0, 1
	j ShowLoop

ShowDone:
	lw $s1, 0($sp)
	lw $s0, 4($sp)
	lw $ra, 8($sp)
	addiu $sp, $sp, 12
	jr $ra

#-----------------------------------------------------------------------------------
# GetUserSequence
# Reads roundLen user keys and checks them against the sequence.
# Returns: v0 = 1 if correct, 0 if wrong
#-----------------------------------------------------------------------------------
GetUserSequence:
	addiu $sp, $sp, -16
	sw $ra, 12($sp)
	sw $s0, 8($sp)
	sw $s1, 4($sp)
	sw $s2, 0($sp)

	li $v0, 4
	la $a0, msgTurn
	syscall

	li $s0, 0
	lw $s1, roundLen

# Handles user input for the sequence
InputLoop:
	beq $s0, $s1, InputCorrect

	li $v0, 4
	la $a0, msgPrompt
	syscall

# Waits for the next key press if no valid input is detected
ReadAgain:
	jal ReadKeyMMIO 	        # v0 = ascii char

	move $a0, $v0
	jal AsciiToTileIndex    	# v0 = 0..8, or -1 if invalid
	bltz $v0, BadInput

	move $s2, $v0                	# user tile index

	# flash the user's chosen tile for feedback
	move $a0, $s2
	jal FlashTileShort

	# compare to expected sequence value
	la $t0, sequence
	sll $t1, $s0, 2
	addu $t0, $t0, $t1
	lw $t2, 0($t0)
	bne $s2, $t2, InputWrong

	addiu $s0, $s0, 1
	j InputLoop

# Invalid key input
BadInput:
	li $v0, 4
	la $a0, msgBad
	syscall
	j ReadAgain

# Wrong  input in sequence
InputWrong:
	move $v0, $zero
	j InputDone

# Correct input, continue
InputCorrect:
	li $v0, 1

InputDone:
	lw $s2, 0($sp)
	lw $s1, 4($sp)
	lw $s0, 8($sp)
	lw $ra, 12($sp)
	addiu $sp, $sp, 16
	jr $ra

#-----------------------------------------------------------------------------------
# ReadKeyMMIO
# Polls the MMIO keyboard until a key is available.
# Returns:v0 = ASCII code of key pressed
#-----------------------------------------------------------------------------------
ReadKeyMMIO:
	lw $t0, KBD_CTRL

# Waits for user key input
WaitKey:
	lw $t1, 0($t0)
	andi $t1, $t1, 1
	beq $t1, $zero, WaitKey

	lw $t2, KBD_DATA
	lbu $v0, 0($t2)
	jr $ra

#-----------------------------------------------------------------------------------
# AsciiToTileIndex
# Converts ASCII '1'..'9' to tile index 0..8.
# Input: a0 = ASCII code
# Returns: #   v0 = 0..8 if valid, -1 if invalid
#-----------------------------------------------------------------------------------
AsciiToTileIndex:
	li $t0, '1'
	li $t1, '9'
	blt $a0, $t0, AsciiBad
	bgt $a0, $t1, AsciiBad
	addiu $v0, $a0, -49
	jr $ra

# Invalid ASCII Input
AsciiBad:
	li $v0, -1
	jr $ra

#-----------------------------------------------------------------------------------
# FlashTile
# Highlights a tile, pauses, redraws it normal, and plays a tone.
# Input: a0 = tile index 0..8
#-----------------------------------------------------------------------------------
FlashTile:
	addiu $sp, $sp, -8
	sw $ra, 4($sp)
	sw $a0, 0($sp)

	jal DrawTileFlash

	li $a0, 600
	li $a1, 120
	jal Beep

	lw $a0, showOnMs
	jal SleepMs

	lw $a0, 0($sp)
	jal DrawTileNormal

	lw $ra, 4($sp)
	addiu $sp, $sp, 8
	jr $ra

#-----------------------------------------------------------------------------------
# FlashTileShort
# Shorter user-feedback flash.
# Input: a0 = tile index 0..8
#-----------------------------------------------------------------------------------
FlashTileShort:
	addiu $sp, $sp, -8
	sw $ra, 4($sp)
	sw $a0, 0($sp)

	jal DrawTileFlash
	li $a0, 700
	li $a1, 80
	jal Beep
	li $a0, 120
	jal SleepMs
	lw $a0, 0($sp)
	jal DrawTileNormal

	lw $ra, 4($sp)
	addiu $sp, $sp, 8
	jr $ra

#-----------------------------------------------------------------------------------
# DrawBoard
# Clears the screen and draws all 9 tiles in normal color.
#-----------------------------------------------------------------------------------
DrawBoard:
	addiu $sp, $sp, -8
	sw $ra, 4($sp)
	sw $s0, 0($sp)

	jal ClearScreen
	jal DrawFrame
	jal DrawDividers
	li $s0, 0

# Loops through tiles to draw board
BoardLoop:
	li $t0, 9
	beq $s0, $t0, BoardDone
	move $a0, $s0
	jal DrawTileNormal
	addiu $s0, $s0, 1
	j BoardLoop

BoardDone:
	lw $s0, 0($sp)
	lw $ra, 4($sp)
	addiu $sp, $sp, 8
	jr $ra

#-----------------------------------------------------------------------------------
# DrawFrame
# Draws a simple border around the play area.
#-----------------------------------------------------------------------------------
DrawFrame:
	addiu $sp, $sp, -4
	sw $ra, 0($sp)

	lw $a2, colorFrame

	# top
	li $a0, 1
	li $a1, 1
	jal FillRectWide

	# bottom
	li $a0, 1
	li $a1, 30
	jal FillRectWide

	# left
	li $a0, 1
	li $a1, 2
	jal FillRectTall

	# right
	li $a0, 30
	li $a1, 2
	jal FillRectTall

	lw $ra, 0($sp)
	addiu $sp, $sp, 4
	jr $ra

#-----------------------------------------------------------------------------------
# DrawDividers
# Draws horizontal and vertical divider bars through the center.
#-----------------------------------------------------------------------------------
DrawDividers:
	addiu $sp, $sp, -4
	sw $ra, 0($sp)

	lw $a2, colorDivider

	# vertical divider
	li $a0, 15
	li $a1, 3
	jal FillRectTallWide

	# horizontal divider
	li $a0, 3
	li $a1, 15
	jal FillRectWideTall

	lw $ra, 0($sp)
	addiu $sp, $sp, 4
	jr $ra

#-----------------------------------------------------------------------------------
# DrawTileNormal
# Draws one tile using its normal color.
# Input: a0 = tile index 0..8
#-----------------------------------------------------------------------------------
DrawTileNormal:
	addiu $sp, $sp, -8
	sw $ra, 4($sp)
	sw $a0, 0($sp)

	jal GetTileAddr
	move $t0, $v0
	lw $a0, 0($t0)             # x
	lw $a1, 4($t0)             # y
	lw $a2, 8($t0)             # normal color
	jal FillRect

	lw $a0, 0($sp)
	jal DrawTileNumber

	lw $ra, 4($sp)
	addiu $sp, $sp, 8
	jr $ra

#-----------------------------------------------------------------------------------
# DrawTileFlash
# Draws one tile using its flash color.
# Input: a0 = tile index 0..8
#-----------------------------------------------------------------------------------
DrawTileFlash:
	addiu $sp, $sp, -8
	sw $ra, 4($sp)
	sw $a0, 0($sp)

	jal GetTileAddr
	move $t0, $v0
	lw $a0, 0($t0)             # x
	lw $a1, 4($t0)             # y
	lw $a2, 12($t0)            # flash color
	jal FillRect

	lw $a0, 0($sp)
	jal DrawTileNumber

	lw $ra, 4($sp)
	addiu $sp, $sp, 8
	jr $ra

#-----------------------------------------------------------------------------------
# GetTileAddr
# Returns the address of the tile table entry.
# Input: a0 = tile index 0..8
# Returns: v0 = address of TileTable entry
#-----------------------------------------------------------------------------------
GetTileAddr:
	li $t0, 16                 # 4 words per entry
	mul $t1, $a0, $t0
	la $v0, TileTable
	addu $v0, $v0, $t1
	jr $ra

#-----------------------------------------------------------------------------------
# DrawTileNumber
# Draws the tile number 1..9 inside the tile.
# Input: a0 = tile index 0..8
#-----------------------------------------------------------------------------------
DrawTileNumber:
	addiu $sp, $sp, -36
	sw $ra, 32($sp)
	sw $s0, 28($sp)
	sw $s1, 24($sp)
	sw $s2, 20($sp)
	sw $s3, 16($sp)
	sw $s4, 12($sp)
	sw $s5, 8($sp)
	sw $s6, 4($sp)
	sw $s7, 0($sp)

	move $s5, $a0               	# tile index 0..8

	jal GetTileAddr
	move $s6, $v0               	# tile table pointer

	lw $s0, 0($s6)              	# tile x
	lw $s1, 4($s6)              	# tile y

	# center 3x5 digit inside 6x6 tile
	addiu $s0, $s0, 1
	addiu $s1, $s1, 1

	la $t0, DigitPatterns
	li $t1, 20                 	# 5 rows * 4 bytes
	mul $t2, $s5, $t1
	addu $s2, $t0, $t2         	# pointer to selected digit

	lw $s3, colorText
	li $s4, 0                  	# row index

DigitRowLoop:
	li $t0, 5
	beq $s4, $t0, DigitDone

	sll $t1, $s4, 2
	addu $t2, $s2, $t1
	lw $s7, 0($t2)             	# row pattern

    	# left pixel
    	andi $t3, $s7, 4
    	beq $t3, $zero, SkipLeft
    	move $a0, $s0
    	addu $a1, $s1, $s4
    	move $a2, $s3
    	jal DrawCell

SkipLeft:
    	# middle pixel
    	andi $t3, $s7, 2
    	beq $t3, $zero, SkipMid
    	addiu $a0, $s0, 1
    	addu $a1, $s1, $s4
    	move $a2, $s3
    	jal DrawCell

SkipMid:
    	# right pixel
    	andi $t3, $s7, 1
    	beq $t3, $zero, SkipRight
    	addiu $a0, $s0, 2
    	addu $a1, $s1, $s4
    	move $a2, $s3
    	jal DrawCell

SkipRight:
    	addiu $s4, $s4, 1
    	j DigitRowLoop
	
DigitDone:
    	lw $s7, 0($sp)
    	lw $s6, 4($sp)
    	lw $s5, 8($sp)
    	lw $s4, 12($sp)
    	lw $s3, 16($sp)
    	lw $s2, 20($sp)
    	lw $s1, 24($sp)
    	lw $s0, 28($sp)
    	lw $ra, 32($sp)
    	addiu $sp, $sp, 36
    	jr $ra

#-----------------------------------------------------------------------------------
# FillRect
# Draws one filled tile rectangle. Uses fixed tile size 6x6 logical cells.
# Inputs: a0 = x start, a1 = y start, a2 = color
#-----------------------------------------------------------------------------------
FillRect:
    	addiu $sp, $sp, -24
	sw $ra, 20($sp)
    	sw $s0, 16($sp)
    	sw $s1, 12($sp)
    	sw $s2, 8($sp)
    	sw $s3, 4($sp)
    	sw $s4, 0($sp)

    	move $s0, $a0                # start x
    	move $s1, $a1                # start y
    	move $s2, $a2                # color
    	li $s3, 0                  # row

RectRowLoop:
    	li $t0, 7
    	beq $s3, $t0, RectDone
    	li $s4, 0                  # col

RectColLoop:
    	li $t1, 6
    	beq $s4, $t1, NextRectRow

    	addu $a0, $s0, $s4
    	addu $a1, $s1, $s3
    	move $a2, $s2
    	jal DrawCell

    	addiu $s4, $s4, 1
    	j RectColLoop

NextRectRow:
    	addiu $s3, $s3, 1
    	j RectRowLoop

RectDone:
    	lw $s4, 0($sp)
    	lw $s3, 4($sp)
    	lw $s2, 8($sp)
    	lw $s1, 12($sp)
    	lw $s0, 16($sp)
    	lw $ra, 20($sp)
    	addiu $sp, $sp, 24
    	jr $ra

#-----------------------------------------------------------------------------------
# FillRectTallWide
# Draws a vertical divider 2x26.
# Inputs: a0 = x start, a1 = y start, a2 = color
#-----------------------------------------------------------------------------------
FillRectTallWide:
    	addiu $sp, $sp, -20
    	sw $ra, 16($sp)
    	sw $s0, 12($sp)
    	sw $s1, 8($sp)
    	sw $s2, 4($sp)
    	sw $s3, 0($sp)

    	move $s0, $a0
    	move $s1, $a1
    	move $s2, $a2
    	li $s3, 0

# Divider row loop
DivTallRow:
    	li $t0, 26
    	beq $s3, $t0, DivTallDone

    	move $a0, $s0
    	addu $a1, $s1, $s3
    	move $a2, $s2
    	jal DrawCell

    	addiu $a0, $s0, 1
    	addu $a1, $s1, $s3
    	move $a2, $s2
    	jal DrawCell

    	addiu $s3, $s3, 1
    	j DivTallRow

DivTallDone:
    	lw $s3, 0($sp)
    	lw $s2, 4($sp)
    	lw $s1, 8($sp)
    	lw $s0, 12($sp)
    	lw $ra, 16($sp)
    	addiu $sp, $sp, 20
    	jr $ra

#-----------------------------------------------------------------------------------
# FillRectWideTall
# Draws a horizontal divider 26x2.
# Inputs: a0 = x start, a1 = y start, a2 = color
#-----------------------------------------------------------------------------------
FillRectWideTall:
    	addiu $sp, $sp, -20
    	sw $ra, 16($sp)
    	sw $s0, 12($sp)
    	sw $s1, 8($sp)
    	sw $s2, 4($sp)
    	sw $s3, 0($sp)

    	move $s0, $a0
    	move $s1, $a1
    	move $s2, $a2
    	li $s3, 0

# Divider column loop
DivWideCol:
    	li $t0, 26
    	beq $s3, $t0, DivWideDone

    	addu $a0, $s0, $s3
    	move $a1, $s1
    	move $a2, $s2
    	jal DrawCell

    	addu $a0, $s0, $s3
    	addiu $a1, $s1, 1
    	move $a2, $s2
    	jal DrawCell

    	addiu $s3, $s3, 1
    	j DivWideCol

DivWideDone:
    	lw $s3, 0($sp)
    	lw $s2, 4($sp)
    	lw $s1, 8($sp)
    	lw $s0, 12($sp)
    	lw $ra, 16($sp)
    	addiu $sp, $sp, 20
    	jr $ra

#-----------------------------------------------------------------------------------
# FillRectWide
# Draws a wide 30x1 border segment.
# Inputs: a0 = x start, a1 = y start, a2 = color
#-----------------------------------------------------------------------------------
FillRectWide:
    	addiu $sp, $sp, -20
    	sw $ra, 16($sp)
    	sw $s0, 12($sp)
    	sw $s1, 8($sp)
    	sw $s2, 4($sp)
    	sw $s3, 0($sp)

    	move $s0, $a0
    	move $s1, $a1
    	move $s2, $a2
    	li $s3, 0

# Horizontal drawing loop
WideLoop:
    	li $t1, 30
    	beq $s3, $t1, WideDone
    	addu $a0, $s0, $s3
    	move $a1, $s1
    	move $a2, $s2
    	jal DrawCell
    	addiu $s3, $s3, 1
    	j WideLoop

WideDone:
    	lw $s3, 0($sp)
    	lw $s2, 4($sp)
    	lw $s1, 8($sp)
    	lw $s0, 12($sp)
    	lw $ra, 16($sp)
    	addiu $sp, $sp, 20
    	jr $ra

#-----------------------------------------------------------------------------------
# FillRectTall
# Draws a tall 1x28 border segment.
# Inputs: a0 = x start, a1 = y start, a2 = color
#-----------------------------------------------------------------------------------
FillRectTall:
    	addiu $sp, $sp, -20
    	sw $ra, 16($sp)
    	sw $s0, 12($sp)
    	sw $s1, 8($sp)
    	sw $s2, 4($sp)
    	sw $s3, 0($sp)

    	move $s0, $a0
    	move $s1, $a1
    	move $s2, $a2
    	li $s3, 0

# Vertical drawing loop
TallLoop:
    	li $t1, 28
    	beq $s3, $t1, TallDone
    	move $a0, $s0
   	addu $a1, $s1, $s3
    	move $a2, $s2
    	jal DrawCell
    	addiu $s3, $s3, 1
    	j TallLoop

TallDone:
    	lw $s3, 0($sp)
    	lw $s2, 4($sp)
    	lw $s1, 8($sp)
    	lw $s0, 12($sp)
    	lw $ra, 16($sp)
    	addiu $sp, $sp, 20
    	jr $ra

#-----------------------------------------------------------------------------------
# DrawCell
# Draws one logical bitmap cell at (x,y).
# Inputs: a0 = x cell (0..31), a1 = y cell (0..31), a2 = color
#-----------------------------------------------------------------------------------
DrawCell:
    	lw $t0, DISP_BASE
    	sll $t1, $a1, 5             # y * 32
    	addu $t1, $t1, $a0           # y*32 + x
    	sll $t1, $t1, 2             # *4 bytes
    	addu $t0, $t0, $t1
    	sw $a2, 0($t0)
    	jr $ra

#-----------------------------------------------------------------------------------
# ClearScreen
# Fills the whole 32x32 logical display with background color.
#-----------------------------------------------------------------------------------
ClearScreen:
    	addiu $sp, $sp, -16
    	sw $ra, 12($sp)
    	sw $s0, 8($sp)
    	sw $s1, 4($sp)
    	sw $s2, 0($sp)

    	lw $s2, colorBG
    	li $s0, 0

ClearRow:
    	li $t0, 32
    	beq $s0, $t0, ClearDone
    	li $s1, 0

# Clear column pixel
ClearCol:
    	li $t1, 32
    	beq $s1, $t1, NextClearRow

    	move $a0, $s1
    	move $a1, $s0
    	move $a2, $s2
    	jal DrawCell

    	addiu $s1, $s1, 1
    	j ClearCol

# Go to next row when clearing
NextClearRow:
    	addiu $s0, $s0, 1
    	j ClearRow

ClearDone:
    	lw $s2, 0($sp)
    	lw $s1, 4($sp)
    	lw $s0, 8($sp)
    	lw $ra, 12($sp)
    	addiu $sp, $sp, 16
    	jr $ra

#-----------------------------------------------------------------------------------
# SleepMs
# Sleeps for a number of milliseconds.
# Input: a0 = milliseconds
#-----------------------------------------------------------------------------------
SleepMs:
    	li $v0, 32
    	syscall
    	jr $ra

#-----------------------------------------------------------------------------------
# Beep
# Plays a simple tone. Uses MARS MIDI out syscall.
# Inputs: a0 = pitch, a1 = duration  
#-----------------------------------------------------------------------------------
Beep:
    	move $t0, $a0
   	move $t1, $a1
    	li $v0, 31
    	move $a0, $t0
    	move $a1, $t1
    	li $a2, 0
    	li $a3, 100
    	syscall
    	jr $ra
