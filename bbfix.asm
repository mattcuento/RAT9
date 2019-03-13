.EQU DX = 0x02
.EQU DY = 0x04


.EQU movLeft = 0x35
.EQU movRight = 0x36
.EQU brickCnt = 0x37
.EQU brickxID = 0x38
.EQU brickyID = 0x39
.EQU ballxID = 0x51
.EQU ballyID = 0x52
.EQU paddlexID = 0x53
.EQU scoreID = 0x81
.EQU bufferID = 0x55

.CSEG
.ORG 0x01

;row 15
;15 bricks (each 16x4 [LxW])
;x value is determined by values from 0x10 to 0x1E
;y value is determined by value in 0x1F
field:
	CALL row15
main:
	CALL ball_init
	CALL paddle_init
check:
	;CALL input
	CALL wall_check
	CALL paddle_ball_check
	CALL floor_check
	CALL bb_next_init	;bb MAKE THE NESTED LOOPS
	CALL ceil_check
	CALL ball_dir_check
	CALL outBrick
	CALL outBall
	CALL outPaddle
	CALL outScore
	;CALL delaytenth ;wait til current screen being drawing
	BRN check

ball_dir_check:
	CMP R2,0x01
	BREQ ball2
	BRCS ball1
	CMP R2,0x04
	BREQ ball4
	BRCS ball3
	RET
	
row15:
row15pos_init:
MOV R0,0x10

row15posx:
	ADD R1,0x10
	ST R1,(R0)
	ADD R0,0x01
	ADD R1,0x01
	CMP R0,0x1F
	BRNE row15posx
row15posy:
	MOV R1,0xC0
	ST R1,(R0)
row15dmg_init:
	MOV R0,0x20
	MOV R1,0x01
row15_dmg:
	ST R1,(R0)
	ADD R0,0x01
	CMP R0,0x2F
	BRNE row15_dmg
	RET
paddle_init:
	MOV R3,0x80
	RET

;ball movement
;R0 is ball curr X
;R1 is ball curr Y
;R31 is lives

ball_init:
	MOV R0,0x04
	MOV R1,0x60
	MOV R2,0x01;MOV R2,0x04
	RET
	
ball1:
	ADD R0,DX
	ADD R1,DY
	MOV R2,0x00
	RET
ball2:
	SUB R0,DX
	ADD R1,DY
	MOV R2,0x01
	RET
ball3:
	SUB R0,DX
	SUB R1,DY
	MOV R2,0x03
	RET
ball4:
	ADD R0,DX
	SUB R1,DY
	MOV R2,0x04
	RET

wall_check:
	CMP R0,0xFB
	BRCC wall_check_R
	CMP R0,0x04
	BREQ wall_check_L
	RET
wall_check_R:
	CMP R2,0x02
	BRCS Rup
	Rdown:
		MOV R2,0x03	;-y collison
		RET
	Rup:			;+y collision
		MOV R2,0x01
		RET
wall_check_L:
	CMP R2,0x02
	BRCS Lup
	Ldown:
		MOV R2,0x04	;-y collsion
		RET
	Lup:			;+y collsion
		MOV R2,0x00
		RET
		
ceil_check:
	CMP R1,0xC0
	BRCS ceil_done
top_surf_exit:
	CMP R2,0x00
	BREQ ceil_check_R
	CMP R2,0x01
	BRNE ceil_done
	ceil_check_L:	;-x collison
		MOV R2,0x03
		RET
	ceil_check_R:	;+x collsion
		MOV R2,0x04
		RET
	ceil_done:
		RET
		
floor_check:
	CMP R1,0x04
	BRNE floor_no
	SUB R31,0x01
	CALL ball_init
	floor_no:
		RET
;paddle x = R3
;paddle y = 0x03
paddle_ball_check:
	CMP R1,0x08
	BREQ pb_x_check
	RET
pb_x_check:
	;R4 is lower x bound
	MOV R4,R3
	SUB R4,0x1D
	;R5 is uppper x bound
	MOV R5,R3
	ADD R5,0x01
	CMP R0,R4
	BRCS dead
	CMP R5,R0
	BRCS dead
	BRCC bot_surf_exit
dead:
	RET
bot_surf_exit:
	CMP R2,0x04
	BRCS bp_L
bp_R:
	MOV R2,0x00
	RET
bp_L:
	MOV R2,0x01
	RET
;curr brick x = R6
;curr brick y = R7
;curr side = R8 starting at bottom, CW, 0,1,2,3
;curr x brick pos = R9 right to left
;curr y brick pos = R10 bottom to top

	;is brick dead
	;call each side (0,1,2,3)
bb_next_init:
	MOV R15,0x0F
	MOV R9,0x1E
	MOV R17,0x2F
	MOV R10,0x1F
	
bb_next:
	SUB R17,0x01
	LD R16,(R17)
	CMP R16,0x00;check if brick is dead
	BREQ bb_skip
	CALL bb_loop
bb_skip:
	SUB R9,0x01
	;SUB R10,0x01
	SUB R15,0x01
	CMP R15,0x00;check if all bricks have been scanned
	BRNE bb_next
	RET
	;R6=currBrickX second phase modify
	;R7=currBrickY second phase modify
	;R11=currBrickX first phase modify
	;R12=currBrickY first phase modify
	;R0=ball x
	;R1=ball y
	;R2=velocity vector, math quadrants
	
bb_loop:
	LD R6,(R9)
	LD R7,(R10)
	LD R11,(R9)
	LD R12,(R10)
	;check which side of brick ball is 
	;PHASE 1
	ADD R12,0x04
	CMP R12,R1
	BREQ bb_top;if bottom of ball at top of brick (y axis only)
	SUB R12,0x08
	CMP R12,R1
	BREQ bb_bot;if top of ball at bottom of brick (y axis only)
	;right edge check
	ADD R11,0x04
	CMP R6,0xFE
	BREQ noRight
	CMP R11,R0
	BREQ bb_right;if left of ball at right of brick (x axis only)
noRight:
	SUB R11,0x14
	CMP R6,0x10
	BREQ noLeft
	CMP R11,R0
	BREQ bb_left;if right of ball at left of brick (x axis only)
noLeft:
	RET	;one of the corner areas, not along either the "column" or "row" of x/y bounds
bb_x_range:
	MOV R13,R6
	CMP R6,0x10
	BREQ leftEdge
	SUB R6,0x0E
	;lower bound
	CMP R13,0xFE
	BREQ rightEdge
	ADD R13,0x02
	;upper bound
	RET
rightEdge:
	ADD R13,0x01
	RET
leftEdge:
	SUB R6,0x0C
	RET
bb_y_range:
	MOV R14,R7
	SUB R7,0x02
	;lower bound
	ADD R14,0x02
	;upper bound
	RET
	;PHASE 2
bb_bot:
	CALL bb_x_range;check x axis now
	CMP R0,R6
	BRCS noInt
	CMP R13,R0
	BRCS noInt
	ADD R26,0x01
	SUB R16,0x01
	ST R16,(R17)
	BRCC bb_e_bot
	RET	
bb_left:
	CALL bb_y_range
	CMP R1,R7
	BRCS noInt
	CMP R14,R1
	BRCS noInt
	ADD R26,0x01
	SUB R16,0x01
	ST R16,(R17)
	BRCC bb_e_left
	RET
bb_top:
	CALL bb_x_range;check x axis now
	CMP R0,R6
	BRCS noInt
	CMP R13,R0
	BRCS noInt
	ADD R26,0x01
	SUB R16,0x01
	ST R16,(R17)
	BRCC bb_e_top
	RET
bb_right:
	CALL bb_y_range
	CMP R1,R7
	BRCS noInt
	CMP R14,R1
	BRCS noInt
	ADD R26,0x01
	SUB R16,0x01
	ST R16,(R17)
	BRCC bb_e_right
	RET
noInt:
	RET
bb_e_bot:
	CMP R2,0x01
	BRCS quad4
	quad3:
		MOV R2,0x03
		RET
	quad4:
		MOV R2,0x04
		RET
bb_e_top:
	CMP R2,0x04
	BRCS quad2
	quad1:
		MOV R2,0x00
		RET
	quad2:
		MOV R2,0x01
		RET
bb_e_left:
	CMP R2,0x02
	BRCS quad2
	BRCC quad3
bb_e_right:
	CMP R2,0x02
	BRCS quad1
	BRCC quad4
outBrick:
	MOV R30,0x1F
	MOV R29,R30
	ADD R29,0x10
	LD R28,(R30)
	OUT R28,brickyID
	SUB R30,0x01
outBrickLoop:
	LD R28,(R30)
	SUB R30,0x01
	SUB R29,0x01
	LD R27,(R29)
	CMP R27,0x00
	BREQ outBrickNone
	OUT R28,brickxID
outJumpIn:
	OUT R30,brickCnt
	CMP R30,0x10
	BRCC outBrickLoop
	OUT R0,brickxID
	RET
outBrickNone:
	MOV R28,0x00
	OUT R28,brickxID
	BRN outJumpIn
outBall:
	OUT R0,ballxID
	OUT R1,ballyID
	RET
outPaddle:
	OUT R3,paddlexID
	RET
outScore:
	OUT R26,scoreID
	RET
input:
	IN R18,movLeft
	IN R19,movRight
	CMP R18,R19
	BRCS paddleR
	BREQ noIn
paddleL:
	SUB R3,0x06
	RET
paddleR:
	ADD R3,0x06
	RET
noIn:
	RET
	
delay:
	IN R25,bufferID
	CMP R25,0x00
	BREQ delay
	RET
delaytenth:
	MOV R19,0x10		;counter for loop I
	MOV R20,0xDD		;counter for loop J
	MOV R21,0xB0		;counter for loop K
	MOV R21,0xB0		;offset
	MOV R21,0xB0		;offset

;inner loop
LoopK:
	ADD R22,0x00		;offset
	ADD R22,0x00		;offset
	SUB R21,0x01		;subtract from counter K
	BRNE LoopK		;check if counter K == 0

;middle loop
LoopJ:
	MOV R21,0xB0		;reset counter K
	SUB R20,0x01		;subtract from counter J
	BRNE LoopK		;check if counter J == 0

;top loop
LoopI:
	MOV R20,0xDD		;reset counter J
	SUB R19,0x01		;subtract from counter I
	BRNE LoopK		;check if counter I == 0
doneHalf:
	RET
done:
	AND R0,R0
	BRN done
