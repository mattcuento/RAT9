.EQU DX = 0x02
.EQU DY = 0x04


.EQU movLeft = 0x35		;left movement port
.EQU movRight = 0x36		;right movement port
.EQU brickCnt = 0x37		;brick count
.EQU brickxID = 0x38		;x coordinate of brick
.EQU brickyID = 0x39		;y coordinate of brick
.EQU ballxID = 0x51		;x coordinate of ball
.EQU ballyID = 0x52		;y coordinate of ball
.EQU paddlexID = 0x53		;x coordinate of paddle
.EQU scoreID = 0x81		;score port
.EQU bufferID = 0x55		;buffer port

.CSEG
.ORG 0x01

;row 15
;15 bricks (each 16x4 [LxW])
;x value is determined by values from 0x10 to 0x1E
;y value is determined by value in 0x1F
field:
	CALL row15		;brick initialization routine
main:
	CALL ball_init		;ball initialization routine
	CALL paddle_init	;paddle initialization routine
check:
	CALL input		;input for movement routine
	CALL wall_check		;checks if ball is at wall
	CALL paddle_ball_check	;checks if ball is at paddle
	CALL floor_check	;checks if ball is at floor
	CALL bb_next_init	;checks if ball is at brick
	CALL ceil_check		;checks if ball is at ceiling
	CALL ball_dir_check	;checks the ball direction based on velocity vector
	CALL outBrick		;outputs brick status
	CALL outBall		;outputs ball status
	CALL outPaddle		;outputs paddle location
	CALL outScore		;outputs score
	CALL delaytenth 	;delays tenth of a second for visuals
	BRN check		;repeat
	
	;r0 = ball x location
	;r1 = ball y direction
	;r2 = velocity vector
	;r3 = paddle location
	;r4 = lower x bound for paddle ball collision
	;r5 = upper x bound for paddle ball collision
	;r6 = brick x location
	;r7 = brick y location
	;r8 = current side being checked of brick
	;r9 = current brick x (being iterated left to right)
	;r10 = current brick y (being iterated bottom to top)
	;r11 = r9 => modified later on, first a reference
	;r12 = r10 => modified later on, first a reference
	;r16 = health of current brick
	;r17 = iterator of health address
	;r26 = score
	;r31 = lives, (infinite)
	
ball_dir_check:
	CMP R2,0x01		;checks if ball is in quadrants 1 or 2
	BREQ ball2
	BRCS ball1
	CMP R2,0x04		;checks if ball is in quadrants 3 or 4
	BREQ ball4
	BRCS ball3
	RET
	
row15:
row15pos_init:			;beginning of brick initialization
MOV R0,0x10			;16 bricks, r0 represents first brick

row15posx:			;stores brick x coordinates to scratch ram
	ADD R1,0x10		
	ST R1,(R0)
	ADD R0,0x01
	ADD R1,0x01
	CMP R0,0x1F
	BRNE row15posx		;repeat until r0 reaches 16 bricks of 32nd reg
row15posy:
	MOV R1,0xC0		;c0 represents y coordinate of all bricks
	ST R1,(R0)		;pushes coordinates to scratch ram
row15dmg_init:
	MOV R0,0x20		;initializes brick health
	MOV R1,0x01		;sets health to 1
row15_dmg:
	ST R1,(R0)		;pushes all brick healths to scratch ram
	ADD R0,0x01
	CMP R0,0x2F
	BRNE row15_dmg
	RET
paddle_init:			;sets starting position of paddle
	MOV R3,0x80
	RET

;ball movement
;R0 is ball curr X
;R1 is ball curr Y
;R31 is lives

ball_init:
	MOV R0,0x04		;starting x position of ball
	MOV R1,0x60		;starting y position of ball
	MOV R2,0x01;		;starting velocity of ball
	RET
	
ball1:				;++ direction
	ADD R0,DX		;add to x
	ADD R1,DY		;add to y
	MOV R2,0x00		;change velocity to quadrant 1
	RET
ball2:				;-+ direction
	SUB R0,DX		;subtract from x
	ADD R1,DY		;add to y
	MOV R2,0x01		;change velocity to quadrant 2
	RET
ball3:				;--direction
	SUB R0,DX		;subtract from x
	SUB R1,DY		;subtract from y
	MOV R2,0x03		;change velocity to quadrant 3
	RET
ball4:				;+- direction
	ADD R0,DX		;add to x
	SUB R1,DY		;subtract from y
	MOV R2,0x04		;change velocity to quadrant 4
	RET

wall_check:			;check if ball is at wal
	CMP R0,0xFB		;ball at right edge?
	BRCC wall_check_R
	CMP R0,0x04		;ball at left edge?
	BREQ wall_check_L
	RET
wall_check_R:			;right edge wall
	CMP R2,0x02		;ball approaching from top or botom?
	BRCS Rup		
	Rdown:
		MOV R2,0x03	;-y collison
		RET
	Rup:			;+y collision
		MOV R2,0x01
		RET
wall_check_L:			;left edge wall
	CMP R2,0x02		;ball approaching from top or bottom?
	BRCS Lup		
	Ldown:
		MOV R2,0x04	;-y collsion
		RET
	Lup:			;+y collsion
		MOV R2,0x00
		RET
		
ceil_check:			;is ball at ceiling?
	CMP R1,0xC0		;max y coordinate is c0
	BRCS ceil_done
top_surf_exit:			;ball approaching a surface from beloq
	CMP R2,0x00		;ball coming from left?
	BREQ ceil_check_R
	CMP R2,0x01		;ball coming from right?
	BRNE ceil_done		
	ceil_check_L:		;-x collison
		MOV R2,0x03	;reverse direction
		RET
	ceil_check_R:		;+x collsion
		MOV R2,0x04	;reverse direction
		RET
	ceil_done:		;no collision
		RET
		
floor_check:			;ball at floor check
	CMP R1,0x04		;is ball y coordinate equal to floor?
	BRNE floor_no
	SUB R31,0x01		;kill ball
	CALL ball_init		;reinitialize ball
	floor_no:		;ball not at floor
		RET
;paddle x = R3
;paddle y = 0x03
paddle_ball_check:
	CMP R1,0x08		;is y coordinate of ball aligned with paddle?
	BREQ pb_x_check
	RET
pb_x_check:			;is x coordinate in range of paddle?				
	MOV R4,R3		;R4 is lower x bound
	SUB R4,0x1D		
	MOV R5,R3		;R5 is uppper x bound
	ADD R5,0x01
	CMP R0,R4		;if ball x coordinate is over or under bounds, kill it
	BRCS dead
	CMP R5,R0
	BRCS dead
	BRCC bot_surf_exit	;if ball within bounds, reverse direction
dead:				;kill the ball
	RET
bot_surf_exit:			;ball in contact with surface below
	CMP R2,0x04		;is ball coming from left or right?
	BRCS bp_L
bp_R:				;ball from the left
	MOV R2,0x00		;change velocity to quadrant 1
	RET
bp_L:				;ball from right
	MOV R2,0x01		;change velocity to quadrant 2
	RET
;curr brick x = R6
;curr brick y = R7
;curr side = R8 starting at bottom, CW, 0,1,2,3
;curr x brick pos = R9 right to left
;curr y brick pos = R10 bottom to top

	;is brick dead
	;call each side (0,1,2,3)
bb_next_init:
	MOV R15,0x0F		;brick scanning counter
	MOV R9,0x1E		;starting brick x
	MOV R17,0x2F		;health address
	MOV R10,0x1F		;starting brick y
	
bb_next:
	SUB R17,0x01		;iterate health address
	LD R16,(R17)		;load health of current brick
	CMP R16,0x00		;check if brick is dead
	BREQ bb_skip		;skip loop if brick is dead
	CALL bb_loop
bb_skip:
	SUB R9,0x01		;iterate brick x
	;SUB R10,0x01		;iterate brick y
	SUB R15,0x01		;iterate scanned bricks counter
	CMP R15,0x00		;check if all bricks have been scanned
	BRNE bb_next		;continue if not
	RET
	;R6=currBrickX second phase modify
	;R7=currBrickY second phase modify
	;R11=currBrickX first phase modify
	;R12=currBrickY first phase modify
	;R0=ball x
	;R1=ball y
	;R2=velocity vector, math quadrants
	
bb_loop:
	LD R6,(R9)		;load brick x values
	LD R7,(R10)		;load brick y values
	LD R11,(R9)		;repeat x
	LD R12,(R10)		;repeat y
				;check which side of brick ball is 
			;PHASE 1
	ADD R12,0x04
	CMP R12,R1
	BREQ bb_top		;check if bottom of ball at top of brick (y axis only)
	SUB R12,0x08
	CMP R12,R1
	BREQ bb_bot		;check if top of ball at bottom of brick (y axis only)
	ADD R11,0x04		
	CMP R6,0xFE		;right edge check
	BREQ noRight		;no right collision
	CMP R11,R0
	BREQ bb_right		;if left of ball at right of brick (x axis only)
noRight:
	SUB R11,0x14
	CMP R6,0x10		;check for left edge 
	BREQ noLeft		;no collision
	CMP R11,R0
	BREQ bb_left		;if right of ball at left of brick (x axis only)
noLeft:
	RET			;one of the corner areas, not along either the "column" or "row" of x/y bounds
bb_x_range:			;checks range of x values if the ball brick check qualified for colliding y values
	MOV R13,R6
	CMP R6,0x10		;left edge of brick?
	BREQ leftEdge
	SUB R6,0x0E		;lower bound
	CMP R13,0xFE		;right edge?
	BREQ rightEdge
	ADD R13,0x02		;upper bound
	RET
rightEdge:			
	ADD R13,0x01		;brick and wall collision check (edge case)
	RET
leftEdge:
	SUB R6,0x0C		;brick and wall collision check (edge case)
	RET
bb_y_range:			;checks range of y values if the ball brick check qualified for colliding x values
	MOV R14,R7
	SUB R7,0x02		;lower bound
	ADD R14,0x02		;upper bound
	RET
			;PHASE 2
bb_bot:
	CALL bb_x_range		;check x axis now for bottom brick collision
	CMP R0,R6		;is brick out of lower bound?
	BRCS noInt		;no intersection
	CMP R13,R0		;is brick out of upper bound?
	BRCS noInt		;no intersection
	ADD R26,0x01		;iterate score
	SUB R16,0x01		;kill brick
	ST R16,(R17)		;update health
	BRCC bb_e_bot		;bottom collision physics check
	RET	
bb_left:			;check for left side collision
	CALL bb_y_range		;check y range
	CMP R1,R7		;out of lower bound?
	BRCS noInt		;no intersection
	CMP R14,R1		;out of upper bound?
	BRCS noInt		;no intersection
	ADD R26,0x01		;iterate score
	SUB R16,0x01		;kill health
	ST R16,(R17)		;update health
	BRCC bb_e_left		;left exit physics check
	RET
bb_top:
	CALL bb_x_range		;check x axis now
	CMP R0,R6		;out of lower bound?
	BRCS noInt		;no intersection
	CMP R13,R0		;out of upper bound?
	BRCS noInt		;no intersection
	ADD R26,0x01		;iterate score
	SUB R16,0x01		;kill brick
	ST R16,(R17)		;update health
	BRCC bb_e_top		;top collision physics check
	RET
bb_right:			;right collision
	CALL bb_y_range		;check y range
	CMP R1,R7		;out of lower bound?
	BRCS noInt		;no intersection
	CMP R14,R1		;out of upper bound?
	BRCS noInt		;no intersection
	ADD R26,0x01		;iterate score
	SUB R16,0x01		;kill brick
	ST R16,(R17)		;update health
	BRCC bb_e_right		;right exit ball physics check
	RET
noInt:				;no collision
	RET
bb_e_bot:			;reverse bottom collision ball direction
	CMP R2,0x01		;ball from left or right?
	BRCS quad4		
	quad3:			;ball from left
		MOV R2,0x03
		RET
	quad4:			;ball from right
		MOV R2,0x04
		RET
bb_e_top:			;reverse top collision ball direction
	CMP R2,0x04		;ball from left or right?
	BRCS quad2	
	quad1:			;ball from left
		MOV R2,0x00
		RET
	quad2:			;ball from right
		MOV R2,0x01
		RET
bb_e_left:			;reverse left collision ball direction
	CMP R2,0x02		;ball from up or down?
	BRCS quad2		;ball from down
	BRCC quad3		;ball from up
bb_e_right:			;reverse right collison ball direction
	CMP R2,0x02		;ball from up or down?
	BRCS quad1		;ball from up
	BRCC quad4		;ball from down
outBrick:
	MOV R30,0x1F
	MOV R29,R30
	ADD R29,0x10
	LD R28,(R30)
	OUT R28,brickyID	;output the brick id
	SUB R30,0x01
outBrickLoop:			;output all bricks in a loop
	LD R28,(R30)
	SUB R30,0x01
	SUB R29,0x01
	LD R27,(R29)
	CMP R27,0x00
	BREQ outBrickNone
	OUT R28,brickxID	;output brick x id
outJumpIn:			
	OUT R30,brickCnt	;output brick count
	CMP R30,0x10
	BRCC outBrickLoop	;loop through bricks if count is 16
	OUT R0,brickxID		;output brick x id
	RET
outBrickNone:			;no more bricks to iterate
	MOV R28,0x00
	OUT R28,brickxID
	BRN outJumpIn
outBall:
	OUT R0,ballxID		;output ball x loction
	OUT R1,ballyID		;output ball y location
	RET
outPaddle:
	OUT R3,paddlexID	;output paddle location
	RET
outScore:
	OUT R26,scoreID		;output score
	RET
input:
	IN R18,movLeft		;output left movement
	IN R19,movRight		;output right movement
	CMP R18,R19
	BRCS paddleR		;paddle moving left or right?
	BREQ noIn
paddleL:			;left paddle movement
	SUB R3,0x06
	RET
paddleR:			;right paddle movement
	ADD R3,0x06
	RET
noIn:				;no movement
	RET
	
delay:				;timing delay and buffer
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
