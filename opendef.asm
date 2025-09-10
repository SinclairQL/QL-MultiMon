* MULTIMON
* QL MONITOR/DISASSEMBLER
* Copyright (C) 1986-1987 by Jan Bredenbeek
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

         include  ch_inc
         include  io_inc
         include  mt_inc
         include  sv_inc
         include  err_inc

         section  openfile

* Open file with optional default directory
* Entry: D3 access key, (A0) filename, A1 ptr to default directory name
* Exit : D0 error code, A0 channel ID if successful, all other regs preserved
* Default directory may be prepended to file name
* Assumes file name buffer is at least 44 bytes!

         xdef     open_def,openfile

od_regs  reg      d1-d3/a0-a2
od_d3    equ      2*4               ; original d1 on stack
od_a0    equ      3*4               ; original a0 on stack
od_a1    equ      4*4               ; original a1 on stack

open_def movem.l  od_regs,-(a7)
         moveq    #-1,d1
         moveq    #io.open,d0       ; try opening filename 'as is'
         trap     #2
         tst.l    d0
         beq      of_ok             ; succeeded, exit
         cmpi.l   #err.nf,d0        ; 'not found'?
         bne      of_end            ; exit with other error
         move.l   d0,-(a7)          ; save error code
         moveq    #mt.inf,d0
         trap     #1

; check if file name starts with valid device name

         lea      sv_ddlst(a0),a2   ; start of directory driver list
         move.l   (a7)+,d0          ; restore error code
         move.l   od_a0(a7),a0      ; original file name
         cmpi.w   #5,(a0)           ; must be at least 5 chars
         blt.s    no_drv            ; if not, skip device name test
         cmpi.b   #'_',6(a0)        ; an underscore must follow dev + drive nr
         bne.s    no_drv
         move.l   2(a0),d1          ; get device name
         andi.l   #$dfdfdf00,d1     ; make it uppercase
chk_drv  move.l   (a2),d2           ; next entry in dd list
         beq.s    no_drv            ; end of list
         move.l   d2,a2
         move.l   ch_drnam+2(a2),d2 ; name of device
         andi.l   #$dfdfdf00,d2     ; only test first 3 chars
         cmp.l    d1,d2             ; does it match?
         bne      chk_drv           ; no, try next
         bra.s    of_end            ; valid device name, return error

; no device specified; let's prepend default dir and try again

no_drv   move.l   od_a1(a7),a1      ; get pointer to default dir
         move.l   a1,d1             ; is there a default?
         beq.s    of_end            ; exit with error code if no default
         move.l   (a1),a1           ; a1 points to dir string
         move.w   (a0),d0           ; length of file name
         move.w   (a1)+,d1          ; length of default dir
         move.w   d0,d2
         add.w    d1,d2             ; form total length in d2
         cmpi.w   #42,d2            ; assume max of 42 (36+5+padding)
         bgt.s    od_badnm          ; reject name if going to be too long
         move.w   d2,(a0)+          ; new length
         lea      (a0,d1.w),a2      ; new position of file name
         bra.s    od_mov1n
od_mov1l move.b   (a0,d0.w),(a2,d0.w) ; move up filename in buffer
od_mov1n dbf      d0,od_mov1l
         bra.s    od_mov2n
od_mov2l move.b   (a1)+,(a0)+       ; prepend default directory
od_mov2n dbf      d1,od_mov2l
         bra.s    of_again          ; retry open with default dir
od_badnm moveq    #err.bn,d0        ; 'bad name' if too long
         bra.s    of_end

* Open channel; D3 access key, A0 channel name
* Exit: D0 error code, A0 channel ID, other regs preserved

openfile movem.l  od_regs,-(a7)
of_again moveq    #-1,d1
         move.b   od_d3+3(a7),d3    ; get original name and key
         move.l   od_a0(a7),a0
         moveq    #io.open,d0
         trap     #2
         tst.l    d0
         beq.s    of_ok             ; exit if ok
         cmpi.l   #err.ex,d0        ; "already exists"?
         bne.s    of_end            ; exit if not
         cmpi.b   #io.overw,d3      ; return an error if we didn't
         bne.s    of_end            ; request an overwrite
of_delet moveq    #-1,d1            ; this code handles drivers which don't
         move.l   od_a0(a7),a0      ; support overwrite (old mdv etc)
         moveq    #io.delet,d0      ; delete old version
         trap     #2
         bra      of_again          ; loop back to open new
of_ok    move.l   a0,od_a0(a7)      ; return channel ID on exit
of_end   movem.l  (a7)+,d1-d3/a0-a2
         tst.l    d0
         rts

         end