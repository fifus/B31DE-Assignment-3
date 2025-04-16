; asm file for use with interrupt timer in C
; 2024 version

; simple stack and heap specification shown here
; assumes that microlib is not used
; use of microlib can be controlled via target options in uVision

; specify block of memory for stack with label Stack_Mem for
; lowest address
; label __initial_sp is equal to label Stack_Mem plus Stack_Size
; actual values for these labels will be determined by linker
Stack_Size      EQU     0x00000400				; 1kB of STACK
                AREA    STACK, NOINIT, READWRITE, ALIGN=4
Stack_Mem       SPACE   Stack_Size
__initial_sp

; specify block of memory for stack with label Heap_Mem for
; lowest address
; actual value for this label will be determined by linker
Heap_Size       EQU     0x00000400 				; 1kB of HEAP
                AREA    HEAP, NOINIT, READWRITE, ALIGN=4
Heap_Mem        SPACE   Heap_Size

; __user_initial_stackheap label is consistent with call from C startup
; code to legacy function __user_initial_stackheap()
; there are alternative methods of setting up the stack and heap
                AREA |.text|, CODE, READONLY, ALIGN=4
				EXPORT  __user_initial_stackheap
; function __user_initial_stackheap() is called during C start up
; and returns addresses of top and bottom of stack and heap in
; registers R0 thru R3
__user_initial_stackheap
                LDR     R0, =  Heap_Mem
                LDR     R1, =(Stack_Mem + Stack_Size)
                LDR     R2, = (Heap_Mem +  Heap_Size)
                LDR     R3, = Stack_Mem
                BX      LR

			IMPORT Timer_Handler

; exception vector table
; label __Vectors is passed to linker as parameter to option --first
; in other words linker will place __Vectors at address 0x00000000
		ALIGN 4
		PRESERVE8
                THUMB
        	AREA	RESET, DATA, READONLY
        	EXPORT 	__Vectors
				
__Vectors	DCD	__initial_sp
        	DCD	  Reset_Handler
        	DCD	0  			
        	DCD	0
        	DCD	0
        	DCD	0
        	DCD	0
        	DCD	0
        	DCD	0
        	DCD	0
        	DCD	0
        	DCD 	0
        	DCD	0
        	DCD	0
        	DCD 	0
        	DCD	0
; External Interrupts						        				
        	DCD	Timer_Handler
        	DCD	0
        	DCD	0
        	DCD	0
        	DCD	0
        	DCD	0
        	DCD	0
        	DCD	0
        	DCD	0
        	DCD	0
        	DCD	0
        	DCD	0
        	DCD	0
        	DCD	0
        	DCD	0
        	DCD	0
              
		AREA |.text|, CODE, READONLY, ALIGN=4

; C startup code takes the form of function __main()
; label Reset_Handler is passed to linker as parameter to option --entry
; in target options

Reset_Handler   PROC
                EXPORT  Reset_Handler
				IMPORT  __main

				LDR     R0, =__main                
                BX      R0                        
                ENDP


		END                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    
   