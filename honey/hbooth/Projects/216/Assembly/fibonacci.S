;;; Implementation that computes the nth fibonacci number. 
	 
	    .global fib                 ; exposes fib as a label for the linker 
	fib:                            ; the label: the next instruction starts fib() function. 
	  
	    cpi r24, 0 ;If the argument it zero, return 0 
	    breq 5f  
	1: 
	    cpi r24, 1 ;If the argument is one, return 1 
	    breq 6f 
	2: 
	    sbiw r24, 1;Reduce n by 1 to prepare for first recursive call 
	    push r24   ;Save the new value of n 
	    push r25 
	    call fib   ;First recursive call of fib(n-1) 
	 
	    mov r22, r24;Move the result of the call to be added later 
	    mov r23, r25 
	    pop r25    ;Place n-1 back into the registers 
	    pop r24 
	 
	    sbiw r24, 1;Subtract 1 from n-1 to prepare for second call 
	 
	    push r22   ;Save values of fib(n-1) 
	    push r23 
	    call fib   ;Call fib(n-2) 
	    pop r23    ;Return fib(n-1) to its registers 
	    pop r22 
	 
	    add r24, r22;Add fib(n-1) and fib(n-2) 
	    adc r25, r23 
	    jmp 3f      ;Return the result of the addition 
	 
	 
	5: 
	    cpi r25, 0  ;Ensure upper byte is 0 before return 
	    breq 3f 
	    jmp 1b 
	 
	6: 
	    cpi r25, 0  ;Ensure upper byte is 0 before return 
	    breq 3f 
	    jmp 2b 
	 
	3: 
	    ret         ; returns.  necessary. 
