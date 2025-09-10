* MULTIMON
* QL MONITOR/DISASSEMBLER
* Copyright (C) 1986-2025 by Jan Bredenbeek
* Parts of the source code (C) 2017-2018 by Norman Dunbar and Jan Bredenbeek
* Released under the GPL v3 license in 2017
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <https://www.gnu.org/licenses/>.

        include   assert_inc
        include   err.inc
        include   qdos_in             QDOS Constants
        include   multimon_in         Macros and definitions

*--------------------------------------------------------------------
* External definitions

        xdef    lh_init,lh_put,lh_getb,lh_getf

*--------------------------------------------------------------------

        section lhsb

* initialise location history pointers

* - a1 - smashed
      
lh_init
        lea     lh_base(a6),a1
        move.l  a1,lh_curr(a6)
        move.l  a1,lh_lru(a6)
        move.l  a1,lh_mru(a6)
        rts
      
* Put current address in location history buffer

* d1 -ip - address to store
      
lh_put
        movem.l d1/a0-a2,-(sp)
        move.l  memptr(a6),d1
        assert  lh_mru,lh_lru-4
        movem.l lh_mru(a6),a0-a1        ; most recent entry +1
        move.l  d1,(a0)+                ; store it
        lea     lh_end(a6),a2           ; end of buffer
        cmpa.l  a2,a0                   ; end of buffer reached?
        bcs.s   lhp_stor                ; no, store it
        lea     lh_base(a6),a0          ; wrap back to base
lhp_stor
        move.l  a0,lh_curr(a6)          ; set new current
        cmpa.l  a1,a0                   ; hit lru pointer?
        bne.s   lhp_end                 ; no, exit
        addq.l  #4,a1                   ; bump lru
        cmpa.l  a2,a1                   ; end of buffer reached?
        bcs.s   lhp_end                 ; no, exit
        lea     lh_base(a6),a1          ; wrap back to base
lhp_end
        movem.l a0-a1,lh_mru(a6)        ; store new mru, lru
        movem.l (sp)+,d1/a0-a2
        rts
        
* Get address out of the location history buffer

* d0 - o - 0 OK, err_ef nothing left
* d1 - o - address got

lh_getb
        moveq   #-2,d0                  ; get back in history
        bra.s   lh_get1
lh_getf
        moveq   #0,d0                   ; get forward
lh_get1
        movem.l a0-a2,-(sp)
        move.l  lh_curr(a6),a0          ; get current in a0
        lea     lh_base(a6),a1          ; base of buffer
        lea     lh_end(a6),a2           ; end of buffer
        tst.l   d0                      ; back or forward
        bmi.s   lh_get2                 ; back
        cmpa.l  lh_mru(a6),a0           ; already at mru?
        beq.s   lh_eof                  ; yes, report eof
        move.l  (a0),d1                 ; get entry
        bra.s   lhg_adv                 ; move forward
lh_get2                                 ; get back here
        cmpa.l  lh_lru(a6),a0           ; already at lru?
        beq.s   lh_eof                  ; yes, report eof
        cmpa.l  a1,a0                   ; at base?
        bhi.s   lhg_prev                ; no
        move.l  a2,a0                   ; go back to end
lhg_prev
        move.l  -(a0),d1                ; get long word
        addq.l  #1,d0                   ; count until d0=0
        bne     lh_get2
lhg_adv
        addq.l  #4,a0                   ; bump current pointer
        cmpa.l  a2,a0                   ; at end of buffer?
        bcs.s   lhg_stor                ; no, exit
        move.l  a1,a0                   ; go back to base
lhg_stor
        move.l  a0,lh_curr(a6)          ; reset head
        bra.s   lhg_end
lh_eof
        moveq   #err.ef,d0              ; prepare EOF
lhg_end
        movem.l (sp)+,a0-a2
        tst.l   d0
        rts
        
        end
        