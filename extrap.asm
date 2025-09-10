* Exception TRAPper from MULTIMON

LF        equ       10
numvecs   equ       19
ex_len    equ       numvecs*4

          include   'dos1_multimon_v3_qdos_in'

* QDOS/SMSQ constants

sv_jbmax  equ       $62             Highest job number in system
sv_jbpnt  equ       $64             Ptr to current job table entry
sv_jbbas  equ       $68             Ptr to base of job table

jb_hold   equ       $0c             Location to be cleared on job release
jb_tag    equ       $10             Job tag
jb_prior  equ       $12             Job current priority
jb_princ  equ       $13             Job priority increment
jb_stat   equ       $14             Job status (0 running, <>0 suspended)
jb_wflag  equ       $17             Set if another job is waiting for this job
jb_wjob   equ       $18             ID of waiting job
jb_trapv  equ       $1c             Ptr to exception table in job header
jb_d0     equ       $20             Job header storage for D0
jb_d1     equ       $24             .. and so on
jb_d2     equ       $28
jb_d3     equ       $2c
jb_a0     equ       $40
jb_a5     equ       $54
jb_a6     equ       $58
jb_a7     equ       $5c
jb_sr     equ       $60
jb_pc     equ       $62
jb_end    equ       $68             End of job header
sv_trapv  equ       $50             System vector for exception table
sv_trapo  equ       $54             Offset from SV.TRAPV vector to

*--------------------------------------------------------------------
* A Macro for generating QDOS strings
*--------------------------------------------------------------------
          
string$   macro a
[.lab]    dc.w      .e.[.l]-.s.[.l]
.s.[.l]   dc.b      [a]
.e.[.l]   equ       *
          endm

          section   extrap
          
          xdef      extrap

extrap    movem.l   d1-d3/a0-a3,-(sp)
          moveq     #ex_len,d1      ; length of exception area
          moveq     #-1,d2          ; current job
          moveq     #mt_alchp,d0    ; allocate space in common heap
          trap      #1
          tst.l     d0              ; error?
          bne.s     start_r         ; oops...
          lea       ex_len(a0),a1   ; end of exception vector table
          moveq     #numvecs-1,d0
          lea       extable,a0
ex_loop   move.w    (a0)+,d2        ; read offset
          lea       -2(a0,d2.w),a2  ; address of handler
          move.l    a2,-(a1)
          dbra      d0,ex_loop
          moveq     #-1,d1          ; set for current job
          moveq     #mt_trapv,d0    ; A1 holds address of exception table
          trap      #1              ; set exception table for this job
start_r   movem.l   (sp)+,d1-d3/a0-a3
          rts

*--------------------------------------------------------------------
* Table of our exception handlers. This holds relative addresses in
* reverse order. The initialisation code will convert these to
* absolute addresses to fill in the exception table.
*--------------------------------------------------------------------
EXTABLE   DC.W      XTRAP-*        ; Trap #5 to #15
          DC.W      XTRAP-*
          DC.W      XTRAP-*
          DC.W      XTRAP-*
          DC.W      XTRAP-*
          DC.W      XTRAP-*
          DC.W      XTRAP-*
          DC.W      XTRAP-*
          DC.W      XTRAP-*
          DC.W      XTRAP-*
          DC.W      XTRAP-*
          DC.W      EXINTL7-*        ; Interrupt level 7
          DC.W      EXTRACE-*        ; Trace exception
          DC.W      EXPRIVV-*        ; Privilege violation
          DC.W      EXTRAPV-*         ; TRAPV exception
          DC.W      EXCHK-*           ; CHK exception
          DC.W      EXDIVZER-*        ; Division by zero
          DC.W      EXILLINST-*       ; Illegal instruction (or breakpoint)
          DC.W      EXADDERR-*       ; Address error

EXINTL7   MOVE.L    A3,-(A7)        ; Save A3 for a bit
          LEA       $18020,A3       ; Microdrive/IPC control/status
          SF        -$1E(A3)        ; $18002 Transmit control ???? -> TODO
          MOVE.L    #$061F0000,(A3) ; $18020-$18023           ???? -> TODO
          MOVE.B    #$1F,1(A3)      ; Hasn't this just been done?
          MOVE.B    #1,-$1D(A3)     ; $18003 PC_IPCWR - ???? -> TODO
          MOVE.L    (A7)+,A3        ; Restore A3
          JSR       SAVREGS         ; Save monitored job's registers
          STRING$   {'Interrupt Level 7',LF}

*--------------------------------------------------------------------
* Address Error handler.
* Tidy the additional data off the SSP.
* Save the registers - so you can hopefully see which one caused the
* exception - then print an address error message before hitting the
* main loop again.
*--------------------------------------------------------------------
EXADDERR  ADDQ.W    #8,A7           ; Point at the SR on the SSP
          JSR       SAVREGS         ; Save REGS and reschedule
          STRING$   {'Address Error',LF}

*--------------------------------------------------------------------
* Illegal Instruction handler.
* Save the registers.
* Print an address error message before hitting the main loop again.
*--------------------------------------------------------------------

; 20210329: Obsolete now, handled by Breakpoint handler!

EXILLINST JSR       SAVREGS         ; Save REGS and reschedule
ILLINSMSG STRING$   {'Illegal Instruction',LF}

*--------------------------------------------------------------------
* Divide by Zero handler.
* Save the registers.
* Print an address error message before hitting the main loop again.
*--------------------------------------------------------------------
EXDIVZER  JSR       SAVREGS         ; Save REGS and reschedule
          STRING$   {'Division by zero',LF}

*--------------------------------------------------------------------
* CHK handler.
* Save the registers.
* Print an address error message before hitting the main loop again.
*--------------------------------------------------------------------
EXCHK     JSR       SAVREGS         ; Save REGS and reschedule
          STRING$   {'CHK Exception',LF}

*--------------------------------------------------------------------
* TRAPV handler.
* Save the registers.
* Print an address error message before hitting the main loop again.
*--------------------------------------------------------------------
EXTRAPV   JSR       SAVREGS         ; Save REGS and reschedule
          STRING$   {'TRAPV Exception',LF}

*--------------------------------------------------------------------
* Privilege Violation handler.
* Save the registers.
* Print an address error message before hitting the main loop again.
*--------------------------------------------------------------------
EXPRIVV   JSR       SAVREGS         ; Save REGS and reschedule
          STRING$   {'Privilege Violation',LF}

EXBRKPNT  JSR       SAVREGS         ; Save REGS and reschedule
EXTRACE   STRING$   {'Trace Exception',LF}

*----------------------------------------------------------------------
* TRAP #5 to #15 are now NOT used anymore for Breakpoints!
* They only come here if they are not redirected by the job's exception
* table (when the original vector pointed to just an RTE instruction)
*----------------------------------------------------------------------

XTRAP     JSR       SAVREGS
          STRING$   {'Undefined TRAP',LF}

savregs   movem.l   d0-d7/a0-a6,-(a7) ; save all regs

; at this point the stack contains:
; $00(a7) - $1c(a7) D0-D7
; $20(a7) - $38(a7) A0-A6
; $3c(a7)           return address (exception message)
; $40(a7)           saved SR
; $42(a7)           saved PC
; USP               saved user SP

; Now display a message on channel 0/1 followed by register values
; (it would be nicer to use the register window display routine here but since
; we don't have the data area set up and channel #0 has room for only about 5
; lines of text the information should be as concise as possible).

          lea       excptmsg,a1
          bsr       srd_out         ; print 'Exception at PC='
          move.l    $42(a7),d1
          bsr       srd_hexl        ; print offending pc value
          lea       colonmsg,a1
          bsr       srd_out
          move.l    $3c(a7),a1
          bsr       srd_out         ; print exception message
          lea       d0msg,a1
          bsr       srd_out         ; 'D0-D7:'
          move.l    a7,a3
          moveq     #7,d7
srd_dlp   move.l    (a3)+,d1
          bsr       srd_hexl        ; print each data register
          dbf       d7,srd_dlp
          lea       a0msg,a1
          bsr       srd_out         ; 'A0-A7:'
          lea       $20(a7),a3
          moveq     #6,d7
srd_alp   move.l    (a3)+,d1
          bsr.s     srd_hexl        ; print each address register
          dbf       d7,srd_alp
          move      usp,a1
          move.l    a1,d1
          bsr.s     srd_hexl        ; print USP
          lea       spmsg,a1        ; SSP:
          bsr       srd_out
          lea       $46(a7),a3      ; stack after saved regs
          moveq     #7,d7           ; eight locations
srd_slp   move.l    (a3)+,d1
          bsr.s     srd_hexl
          dbf       d7,srd_slp
          lea       srmsg,a1
          bsr.s     srd_out         ; print 'SR:'
          lea       $40(a7),a1
          suba.w    #18,a7
          move.l    a7,a0
          move.w    #16,(a0)+
          suba.l    a6,a0
          suba.l    a6,a1
          move.w    cn_itobw,a2     ; convert to binary
          jsr       (a2)
          lea       -18(a6,a0.l),a1
          bsr.s     srd_out         ; print SR
          adda.w    #18,a7
          lea       jobmsg,a1       ; print 'Job ID:'
          bsr.s     srd_out
          moveq     #mt_inf,d0
          trap      #1
          move.l    a0,a6
          bsr.s     srd_hexl        ; print Job ID
          lea       brktmsg,a1
          bsr.s     srd_out
          move.l    sv_jbpnt(a6),a1
          move.l    (a1),a1
          lea       jb_end+6(a1),a1
          cmpi.w    #$4afb,(a1)+    ; Name marker (if any)
          bne.s     srd_lf
          bsr.s     srd_out
srd_lf    lea       lfmsg,a1        ; followed by LF
          bsr.s     srd_out

halt      bra.s     *               ; keep looping around

; print value of d1.l in hex followed by space
          
srd_hexl  suba.w    #12,a7
          move.l    a7,a0
          move.w    #9,(a0)+
          bsr.s     cn_hexl
          move.b    #' ',(a0)+
          move.l    a7,a1
          bsr.s     srd_out
          adda.w    #12,a7
          rts

; print string at (a1)

srd_out   suba.l    a0,a0           ; use channel 0 or 1
          move.w    ut_mtext,a2
          jmp       (a2)

*--------------------------------------------------------------------
* Positive long word to Hexadecimal.
*--------------------------------------------------------------------
cn_hexl   moveq     #8,d0           ; There are 8 hex digits in a long

*--------------------------------------------------------------------
* Routine to convert D1.B.W.L to D0 Hexadecimal characters. For byte,
* word or long this is 2, 4 or 8 characters. For an address, only the
* lower 5 digits are converted. See the readme file & CN_ADDR above.
* The converted digits are stored in a buffer at (A0).
*--------------------------------------------------------------------
cn_hex    movem.l   d1-d3,-(a7)     ; Save workers
          move.b    d0,d3           ; Counter of digits in D3.B
          adda.w    d0,a0           ; Point to END of buffer

*--------------------------------------------------------------------
* Work backwards in the buffer, converting the lowest byte of D1 as
* we go. Only D3.B characters are converted, or D3.B/2 bytes of the
* value in D1.B.W.L.
*--------------------------------------------------------------------
cn_loop   moveq     #$0f,d2         ; Mask of one nibble
          and.b     d1,d2           ; D2.B = Lowest nibble
          cmpi.b    #10,d2          ; Still a digit?
          blt.s     cn_store        ; Yes, store the digit
          addq.b    #7,d2           ; No, add offset to letters

cn_store  addi.b    #'0',d2         ; ASCIIfy the digit/letter
          move.b    d2,-(a0)        ; And store in the buffer
          lsr.l     #4,d1           ; Ready the next highest nibble
          subq.b    #1,d3           ; One less digit to convert
          bne.s     cn_loop         ; Do another if more to do
          adda.w    d0,a0           ; A0 points to the final hex char
          movem.l   (a7)+,d1-d3     ; Restore the workers
          rts                       ; Done

excptmsg  string$   {LF,'*** Exception at PC='}
colonmsg  string$   {': '}
d0msg     string$   {'D0-D7: '}
a0msg     string$   {LF,'A0-A7: '}
spmsg     string$   {LF,'SSP  : '}
srmsg     string$   {LF,'SR: '}
jobmsg    string$   {' Job: '}
brktmsg   string$   {' ('}
lfmsg     string$   {')',LF}

          end
