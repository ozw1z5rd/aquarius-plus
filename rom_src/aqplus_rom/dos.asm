; Based on V1.0 of micro-expander ROM

; File types
FT_NONE:  equ $01    ; no file extension (type determined from file header)
FT_TXT:   equ $20    ; .TXT ASCII text file (no header)
FT_OTHER: equ $80    ; .??? unknown file type (raw binary, no header)
FT_BIN:   equ $BF    ; .BIN binary (starts with $BF,$DA,load_addr if executable)
FT_BAS:   equ $FE    ; .BAS tokenized BASIC (has CAQ header same as .CAQ)
FT_CAQ:   equ $FF    ; .CAQ BASIC program or numeric array

; Bits in dosflags
DF_ADDR:  equ 0       ; set = address specified
DF_ARRAY: equ 7       ; set = numeric array

;-----------------------------------------------------------------------------
; Print hex byte
; in: A = byte
;-----------------------------------------------------------------------------
printhex:
    push    bc

    ; Print high nibble
    ld      b, a
    and     $F0
    rra
    rra
    rra
    rra
    cp      10
    jr      c, .hi_nib
    add     7
.hi_nib:
    add     '0'
    call    TTYOUT

    ; Print low nibble
    ld      a, b
    and     $0F
    cp      10
    jr      c, .low_nib
    add     7
.low_nib:
    add     '0'
    pop     bc
    jp      TTYOUT

;-----------------------------------------------------------------------------
; strlen - String length
;  in: HL = string (null-terminated)
; out:  A = number of characters in string
;-----------------------------------------------------------------------------
strlen:
    ; Save DE/HL
    push  de
    ld    d, h
    ld    e, l

    ; Find null-character in string
    xor   a
    dec   hl
.loop:
    inc   hl
    cp    (hl)
    jr    nz, .loop

    ; Calculate length of string
    sbc   hl, de
    ld    a, l

    ; Restore DE/HL
    ex    de, hl
    pop   de
    ret

;-----------------------------------------------------------------------------
; strcmp - Compare strings
;  in: HL = string 1 (null terminated)
;      DE = string 2 (null terminated)
; out: Z  = strings equal
;      NZ = not equal
;-----------------------------------------------------------------------------
strcmp:
    ld      a, (de)         ; Get char from string 2
    inc     de
    cp      (hl)            ; Compare to char in string 1
    inc     hl
    ret     nz              ; Return NZ if not equal
    or      a
    jr      nz, strcmp      ; Loop until end of strings
    ret                     ; Return Z

;-----------------------------------------------------------------------------
; Check for argument in current statement
;  in: HL = text pointer
; out: NZ = argument present
;       Z = end of statement
;-----------------------------------------------------------------------------
chkarg:
    push    hl              ; Save BASIC text pointer
.next_char:
    ld      a, (hl)         ; Get char
    inc     hl
    cp      ' '             ; Skip spaces
    jr      z, .next_char
    cp      ':'             ; Z if end of statement
    jr      z, .chkarg_done ; Return Z if end of statement
    or      a               ; Z if end of line
.chkarg_done:
    pop     hl              ; Restore BASIC text pointer
    ret

;-----------------------------------------------------------------------------
; Get next character, skipping spaces
;  in: HL = text pointer
; out: NZ, A = next non-space char, HL = address of char in text
;      Z,  A = 0, HL = end of text
;-----------------------------------------------------------------------------
get_next:                   ; Starting at next location
    inc     hl
get_arg:                    ; Starting at current location
    ld      a, (hl)
    or      a
    ret     z               ; Return Z if NULL
    cp      ' '
    ret     nz              ; Return NZ if not SPACE
    jr      get_next

;-----------------------------------------------------------------------------
; LOAD
;-----------------------------------------------------------------------------
; LOAD "filename"        load BASIC program, binary executable
; LOAD "filename",12345  load file as raw binary to address 12345
; LOAD "filename",*a     load data into numeric array a
;
;  in: hl = BASIC text pointer
;
; out: hl = BASIC text pointer
;       z = loaded OK, a = filetype
;
; file type detection
; -------------------
; BAS:   file starts with CAQ BASIC header (32 bytes)
; CAQ:   file starts with CAQ ARRAY header (19 bytes)
; BIN:   file starts with BINARY header (4 bytes $C9,$C3,nnnn = ret, jp nnnn)
; TXT:   file starts with 7 bit ASCII character
; else:  unknown type (raw binary)
;-----------------------------------------------------------------------------
ST_LOAD:
    call    dos__getfilename        ; Filename -> FileName
    jp      z, ST_LOADFILE          ; Good filename?
    push    hl                      ; Push BASIC text pointer
    ld      e, a
    cp      FC_ERR                  ; If Function Call error then show DOS error
    jp      nz, _stl_do_error       ; Else show BASIC error code
    ld      a, ERROR_BAD_NAME
    jp      _stl_show_error         ; Break with bad filename error

    ; load file with filename in FileName
ST_LOADFILE:
    xor     a
    ld      (FILETYPE), a           ; Filetype unknown
    ld      (DOSFLAGS), a           ; Clear all DOS flags
.getarg:
    call    get_arg                 ; Get next non-space character
    cp      ','
    jr      nz, .start              ; If not ',' then no arg
    call    get_next
    cp      $AA                     ; Token for '*'
    jr      nz, .addr
.arg_array:
    inc     hl                      ; Skip '*' token
    ld      a, 1
    ld      (SUBFLG), a             ; Set array flag
    call    PTRGET                  ; Get array (out: bc = address, de = length)
    ld      (SUBFLG), a             ; Clear array flag
    jp      nz, FCERR               ; FC Error if array not found
    call    CHKNUM                  ; TM error if not numeric
.array_parms:
    push    hl                      ; Push BASIC text pointer
    ld      h, b
    ld      l, c                    ; HL = address
    ld      c, (hl)
    ld      b, 0                    ; BC = index
    add     hl, bc
    add     hl, bc
    inc     hl                      ; HL = array data
    ld      (BINSTART), hl
    dec     de
    dec     de                      ; Subtract array header to get data length
    dec     de
    ld      (BINLEN), de
    ld      a, 1<<DF_ARRAY
    ld      (DOSFLAGS), a           ; Set 'loading to array' flag
    pop     hl                      ; Pop text pointer
    jr      .start
.addr:
    call    FRMNUM                  ; Get number
    call    FRCINT                  ; Convert to 16 bit integer
    ld      (BINSTART), de
    ld      a, 1<<DF_ADDR
    ld      (DOSFLAGS), a           ; Load address specified
.start:
    push    hl                      ; >>>> push BASIC text pointer
    ld      hl, FileName
    call    usb__open_read          ; Try to open file
    jp      nz, .no_file
    ld      de, 1                   ; 1 byte to read
    ld      hl, FILETYPE
    call    usb__read_bytes         ; Read 1st byte from file into FILETYPE
    jp      nz, _stl_show_error
    ld      de, 0                   ; Rewind back to start of file
    call    usb__seek
    call    dos__getfiletype        ; Get filetype from extn  (eg. "name.BAS")
    or      a
    jp      nz, .type
    ld      a, ERROR_BAD_FILE       ; 0 = bad name
    jp      _stl_show_error
.type:
    cp      FT_NONE                 ; File type in extn?
    jr      nz, .parse_type
    ld      a, (FILETYPE)           ; No, use type from file
    cp      $80                     ; ASCII text?
    jr      nc, .parse_type
    ld      a, FT_TXT               ; Yes, type is TXT
.parse_type:
    ld      (FILETYPE),a
    cp      FT_TXT                  ; TXT ?
    jr      z, .txt
    cp      FT_CAQ                  ; CAQ ?
    jr      z, .caq
    cp      FT_BAS                  ; BAS ?
    jr      z, .bas
    cp      FT_BIN                  ; BIN ?
    jr      z, .bin

    ; Unknown filetype
    ld      a, (DOSFLAGS)
    bit     DF_ADDR, a              ; Address specified?
    jr      nz, .load_bin
    bit     DF_ARRAY, a             ; No, loading to array?
    jr      nz, .bas
    jp      .no_addr

    ; TXT
.txt:
    ld      a, (DOSFLAGS)
    bit     DF_ADDR, a              ; Address specified?
    jr      nz, .load_bin           ; Yes, load text to address
    ; View text here ???
    jp      .no_addr                ; No, error

    ; BIN
.bin:
    call    usb__read_byte          ; Read 1st byte from file
    jp      nz, .read_error
    cp      $BF                     ; Cp a instruction?
    jp      nz, .raw
    call    usb__read_byte          ; Yes, read 2nd byte from file
    jp      nz, .read_error
    cp      $DA                     ; Jp c instruction?
    jp      nz, .raw

    ; Binary with header
    ld      a, (DOSFLAGS)
    bit     DF_ADDR, a              ; Yes, address specified by user?
    jr      nz, .load_bin
    ld      hl, BINSTART
    ld      de, 2
    call    usb__read_bytes         ; No, read load address
    jp      nz, .read_error
    dec     e
    dec     e                       ; Got 2 bytes?
    jr      z, .load_bin            ; Yes,
    jp      .no_addr                ; No, error

    ; Raw binary (no header)
.raw:
    ld      a, (DOSFLAGS)
    bit     DF_ADDR, a              ; Address specified by user?
    jp      z, .no_addr             ; No, error

    ; Load binary file to address
.load_bin:
    ld      de, 0
    call    usb__seek               ; Rewind to start of file
    ld      a, FT_BIN
    ld      (FILETYPE), a           ; Force type to BIN
    ld      hl, (BINSTART)          ; HL = address
    jr      .read                   ; Read file into RAM

    ; BASIC program or array, has CAQ header
.caq:
.bas:
    ld      a, (DOSFLAGS)
    bit     DF_ADDR, a              ; Address specified?
    jr      nz, .load_bin           ; Yes, load as raw binary
    call    st_read_sync            ; No, read 1st CAQ sync sequence
    jr      nz, .bad_file
    ld      hl, FileName
    ld      de, 6                   ; Read internal tape name
    call    usb__read_bytes
    jr      nz, .bad_file
    ld      a, (DOSFLAGS)
    bit     DF_ARRAY, a             ; Loading into array?
    jr      z, .basprog

    ; Loading array
    ld      hl, FileName
    ld      b, 6                    ; 6 chars in name
    ld      a, '#'                  ; All chars should be '#'
.array_id:
    cp      (hl)
    jr      nz, .bad_file           ; If not '#' then bad tape name
    djnz    .array_id
    ld      hl, (BINSTART)          ; HL = array data address
    ld      de, (BINLEN)            ; DE = array data length
    jr      .read_len               ; Read file into array

    ; Loading BASIC program
.basprog:
    call    st_read_sync            ; Read 2nd CAQ sync sequence
    jr      nz, .bad_file
    ld      hl, (TXTTAB)            ; HL = start of BASIC program
    ld      de, $FFFF               ; DE = read to end of file
    call    usb__read_bytes         ; Read BASIC program into RAM
    jr      nz, .read_error
.bas_end:
    dec     hl
    xor     a
    cp      (hl)                    ; Back up to last line of BASIC program
    jr      z, .bas_end
    inc     hl
    inc     hl
    inc     hl                      ; Forward past 3 zeros = end of BASIC program
    inc     hl
    ld      (VARTAB), hl            ; Set end of BASIC program
    call    Init_BASIC              ; Clear variables etc. and update line addresses
    ld      a, FT_BAS
    ld      (FILETYPE), a           ; Filetype is BASIC
    jr      _stl_done

    ; Read file into RAM
    ; HL = load address
.read:
    ld      de, $FFFF               ; Set length to max (will read to end of file)
.read_len:
    call    usb__read_bytes         ; Read file into RAM
    jr      z, _stl_done            ; If good load then done
.read_error:
    ld      a, ERROR_READ_FAIL      ; Disk error while reading
    jr     _stl_show_error
.no_file:
    ld      a, ERROR_NO_FILE        ; File not found
    jr      _stl_show_error
.bad_file:
    ld      a, ERROR_BAD_FILE       ; File type incompatible with load method
    jr      _stl_show_error
.no_addr:
    ld      a, ERROR_NO_ADDR        ; No load address specified

_stl_show_error:
    call    _show_error             ; Print DOS error message (a = error code)
    call    usb__close_file         ; Close file (if opened)
    ld      e, FC_ERR               ; Function Call error
_stl_do_error:
    pop     hl                      ; Restore BASIC text pointer
    jp      ERROR                   ; Return to BASIC with error code in e
_stl_done:
    call    usb__close_file         ; Close file
    ld      a, (FILETYPE)
    cp      a                       ; Z = OK
    pop     hl                      ; Restore BASIC text pointer
    ret

;-----------------------------------------------------------------------------
; Print DOS error message
;
;  in: a = error code
;-----------------------------------------------------------------------------
ERROR_NO_CH376:    equ   1 ; CH376 not responding
ERROR_NO_USB:      equ   2 ; not in USB mode
ERROR_MOUNT_FAIL:  equ   3 ; drive mount failed
ERROR_BAD_NAME:    equ   4 ; bad name
ERROR_NO_FILE:     equ   5 ; no file
ERROR_FILE_EMPTY:  equ   6 ; file empty
ERROR_BAD_FILE:    equ   7 ; file header mismatch
ERROR_NO_ADDR:     equ   8 ; no load address in binary file
ERROR_READ_FAIL:   equ   9 ; read error
ERROR_WRITE_FAIL:  equ  10 ; write error
ERROR_CREATE_FAIL: equ  11 ; can't create file
ERROR_NO_DIR:      equ  12 ; can't open directory
ERROR_PATH_LEN:    equ  13 ; path too long
ERROR_UNKNOWN:     equ  14 ; other disk error

_show_error:
    cp      ERROR_UNKNOWN           ; Known error?
    jr      c, .index               ; Yes,
    push    af                      ; No, push error code
    ld      hl, .unknown_error_msg
    call    STROUT                  ; Print "disk error $"
    pop     af                      ; Pop error code
    call    printhex
    jp      CRDO
.index:
    ld      hl, _error_messages
    dec     a
    add     a, a
    add     l
    ld      l, a
    ld      a, h
    adc     a, 0
    ld      h, a                    ; Index into error message list
    ld      a, (hl)
    inc     hl
    ld      h, (hl)                 ; HL = error message
    ld      l, a
    call    STROUT                  ; Print error message
    jp      CRDO

.unknown_error_msg:  db "Disk error $", 0

_error_messages:
    dw .no_376_msg           ;  1
    dw .no_disk_msg          ;  2
    dw .no_mount_msg         ;  3
    dw .bad_name_msg         ;  4
    dw .no_file_msg          ;  5
    dw .file_empty_msg       ;  6
    dw .bad_file_msg         ;  7
    dw .no_addr_msg          ;  8
    dw .read_error_msg       ;  9
    dw .write_error_msg      ; 10
    dw .create_error_msg     ; 11
    dw .open_dir_error_msg   ; 12
    dw .path_too_long_msg    ; 13

.no_376_msg:         db "No CH376", 0
.no_disk_msg:        db "No USB", 0
.no_mount_msg:       db "No disk", 0
.bad_name_msg:       db "Invalid name", 0
.no_file_msg:        db "File not found", 0
.file_empty_msg:     db "File empty", 0
.bad_file_msg:       db "Filetype mismatch", 0
.no_addr_msg:        db "No load address", 0
.read_error_msg:     db "Read error", 0
.write_error_msg:    db "Write error", 0
.create_error_msg:   db "File create error", 0
.open_dir_error_msg: db "Directory not found", 0
.path_too_long_msg:  db "Path too long", 0

;-----------------------------------------------------------------------------
; Read CAQ Sync Sequence
;
; CAQ BASIC header is 12x$FF, $00, 6 bytes filename, 12x$FF, $00.
; This subroutine reads and checks the sync sequence 12x$FF, $00.
;
; out: z = OK
;     nz = bad header
;
; uses: a, b
;-----------------------------------------------------------------------------
st_read_sync:
    ld      b, 12
_st_read_caq_lp1:
    call    usb__read_byte
    ret     nz
    inc     a
    ret     nz                      ; nz if not $FF
    djnz    _st_read_caq_lp1
    call    usb__read_byte
    ret     nz
    and     a                       ; z if $00
    ret

;-----------------------------------------------------------------------------
; Initialize BASIC Program
;
; Resets variables, arrays, string space etc.
; Updates nextline pointers to match location of BASIC program in RAM
;-----------------------------------------------------------------------------
Init_BASIC:
    ld      hl, (TXTTAB)
    dec     hl
    ld      (SAVTXT), hl        ; Set next statement to start of program
    ld      (DATPTR), hl        ; Set DATPTR to start of program
    ld      hl, (MEMSIZ)
    ld      (FRETOP), hl        ; Clear string space
    ld      hl, (VARTAB)
    ld      (ARYTAB), hl        ; Clear simple variables
    ld      (STREND), hl        ; Clear array table
    ld      hl, TEMPPT + 2
    ld      (TEMPPT), hl        ; Clear string buffer
    xor     a
    ld      l, a
    ld      h, a
    ld      (OLDTXT), hl        ; Set CONTinue position to 0
    ld      (SUBFLG), a         ; Clear locator flag
    ld      (VARNAM), hl         ; Clear array pointer???
.link_lines:
    ld      de, (TXTTAB)        ; DE = start of BASIC program
.next_line:
    ld      h, d
    ld      l, e                ; HL = DE
    ld      a, (hl)
    inc     hl                  ; Test nextline address
    or      (hl)
    jr      z, .init_done       ; If $0000 then done
    inc     hl
    inc     hl                  ; Skip line number
    inc     hl
    xor     a                   ; End of line = $00
.find_eol:
    cp      (hl)                ; Search for end of line
    inc     hl
    jr      nz, .find_eol
    ex      de, hl              ; HL = current line, DE = next line
    ld      (hl), e
    inc     hl                  ; Set address of next line
    ld      (hl), d
    jr      .next_line
.init_done:
    ret

;-----------------------------------------------------------------------------
; SAVE "filename" (,address,length)
;
;  SAVE "filename"             save BASIC program
;  SAVE "filename",addr,len    save binary data
;-----------------------------------------------------------------------------
ST_SAVE:
    xor     a
    ld      (DOSFLAGS), a           ; Clear all flags
    call    dos__getfilename        ; Filename -> FileName
    jr      z, ST_SAVEFILE
    push    hl                      ; Push BASIC text pointer
    ld      e, a                    ; E = error code
    cp      FC_ERR
    jp      nz, _sts_error          ; If not FC error then show BASIC error code
    ld      a, ERROR_BAD_NAME
    jp      ERROR                   ; Bad filename, quit to BASIC

    ; Save with filename in FileName
ST_SAVEFILE:
    call    get_arg                 ; Get current char (skipping spaces)
    cp      ','
    jr      nz, .save_open          ; If not ',' then no args so saving BASIC program
    call    get_next
    cp      $AA                     ; '*' token?
    jr      nz, .num                ; No, parse binary address & length
    inc     hl                      ; Yes, skip token
    ld      a, 1
    ld      (SUBFLG), a             ; Flag = array
    call    PTRGET                  ; Bc = array address, de = array length
    ld      (SUBFLG), a             ; Clear flag
    jp      nz, FCERR               ; Report FC Error if array not found
    call    CHKNUM                  ; TM error if not numeric
    call    get_next
    cp      'a'
    jr      c, .array
    inc     hl                      ; Skip 2nd letter of array name ???

.array:
    push    hl
    ld      h, b
    ld      l, c                    ; HL = address
    ld      c, (hl)
    ld      b, 0                    ; BC = index
    add     hl, bc
    add     hl, bc
    inc     hl                      ; HL = array data
    ld      (BINSTART), hl
    dec     de
    dec     de                      ; Subtract array header to get data length
    dec     de
    ld      (BINLEN), de
    ld      a, 1<<DF_ARRAY
    ld      (DOSFLAGS), a           ; Flag saving array
    pop     hl
    jr      .save_open

    ; Parse address, length
.num:
    call    FRMNUM                  ; Get address
    call    FRCINT                  ; Convert to 16 bit integer
    ld      (BINSTART), de          ; Set address
    ld      a, 1<<DF_ADDR
    ld      (DOSFLAGS), a           ; Flag load address present
    call    get_arg                 ; Get next char from text, skipping spaces
    SYNCHK  ','                     ; Check for ',' (otherwise syntax error)
    call    FRMNUM                  ; Get length
    call    FRCINT                  ; Convert to 16 bit integer
    ld      (BINLEN),de             ; Store length

    ; Create new file
.save_open:
    push    hl                      ; Push BASIC text pointer
    ld      hl, FileName
    call    usb__open_write         ; Create/open new file
    jr      nz, .open_error
    ld      a, (DOSFLAGS)
    bit     DF_ADDR, a
    jr      nz, .binary

    ; Saving BASIC program or array
    call    st_write_sync           ; Write caq sync 12 x $FF, $00
    jr      nz, .write_error
    ld      a, (DOSFLAGS)
    bit     DF_ARRAY, a             ; Saving array?
    jr      z, .ext_bas

    ; Saving array
    ld      hl, _array_name         ; "######"
    ld      de, 6
    call    usb__write_bytes
    jr      nz, .write_error
    jr      .binary                 ; Write array

    ; Saving BASIC program
.ext_bas:
    ld      hl, FileName
    ld      de, 6                   ; Write 1st 6 chars of filename
    call    usb__write_bytes
    jr      nz, .write_error
    call    st_write_sync           ; Write 2nd caq sync $FFx12,$00
    jr      nz, .write_error
    ld      de, (TXTTAB)            ; DE = start of BASIC program
    ld      hl, (VARTAB)            ; HL = end of BASIC program
    or      a
    sbc     hl, de
    ex      de, hl                  ; HL = start, DE = length of BASIC program
    jr      .write_data

    ; Saving BINARY
.binary:
    ld      a, $C9                  ; Write $c9 = ret
    call    usb__write_byte
    jr      nz, .write_error
    ld      a, $C3                  ; Write $c3 = jp
    call    usb__write_byte
    jr      nz, .write_error
    ld      hl, (BINSTART)          ; HL = binary load address
    ld      a, l
    call    usb__write_byte
    jr      nz, .write_error
    ld      a, h                    ; Write binary load address
    call    usb__write_byte
    jr      nz, .write_error
    ld      de, (BINLEN)

    ; Save data (HL = address, DE = length)
.write_data:
    call    usb__write_bytes        ; Write data block to file
    push    af
    call    usb__close_file         ; Close file
    pop     af
    jr      z, _sts_done            ; If wrote OK then done

    ; Error while writing
.write_error:
    ld      a, ERROR_WRITE_FAIL
    jr      .show_error

    ; Error opening file
.open_error:
    ld      a, ERROR_CREATE_FAIL
.show_error:
    call    _show_error             ; Show DOS error message (a = error code)
    ld      e, FC_ERR
_sts_error:
    pop     hl
    jp      ERROR                   ; Return to BASIC with error code in e
_sts_done:
    pop     hl                      ; Restore BASIC text pointer
    ret

_array_name:
    db      "######"

;-----------------------------------------------------------------------------
; Write CAQ Sync Sequence  12x$FF, $00
; uses: a, b
;-----------------------------------------------------------------------------
st_write_sync:
    ld      b, 12
.write_caq_loop:
    ld      a, $FF
    call    usb__write_byte         ; Write $FF
    ret     nz                      ; Return if error
    djnz    .write_caq_loop
    ld      a, $00
    jp      usb__write_byte         ; Write $00

;-----------------------------------------------------------------------------
; Delete File
;-----------------------------------------------------------------------------
ST_DEL:
    call   dos__getfilename ; Filename -> FileName
    push   hl               ; Push BASIC text pointer
    jr     z, .goodname
    ld     e, a
    ld     a, ERROR_BAD_NAME
    jr     .del_error
.goodname:
    ld     hl, FileName
    call   usb__delete      ; Delete file
    jr     z, .del_done
    ld     e, FC_ERR
    ld     a, ERROR_NO_FILE
.del_error:
    call   _show_error      ; Print error message
    pop    hl               ; Pop BASIC text pointer
    jp     ERROR
.del_done:
    pop    hl               ; Pop BASIC text pointer
    ret

;-----------------------------------------------------------------------------
; Get Filename
;
; Get Filename argument from BASIC text or command line.
; May be literal string, or an expression that evaluates to a string
; eg. LOAD "filename"
;     SAVE left$(a$,11)
;
; in:  hl = BASIC text pointer
;
; out: Uppercase filename in FileName, 1-12 chars null-terminated
;      hl = BASIC text pointer
;       z = OK
;      nz = error, a = $08 null string, $18 not a string
;
; uses: bc, de
;-----------------------------------------------------------------------------
dos__getfilename:
    call    FRMEVL              ; Evaluate expression
    push    hl                  ; Save BASIC text pointer
    ld      a, (VALTYP)         ; Get type
    dec     a
    jr      nz, .type_mismatch
    call    LEN1                ; Get string and its length
    jr      z, .null_str        ; If empty string then return
    cp      12
    jr      c, .string          ; Trim to 12 chars max
    ld      a, 12
.string:
    ld      b, a                ; B = string length
    inc     hl
    inc     hl                  ; Skip to string text pointer
    ld      a, (hl)
    inc     hl
    ld      h, (hl)
    ld      l, a                ; HL = string text pointer
    ld      de, FileName        ; DE = filename buffer (13 bytes)
.copy_str:
    ld      a, (hl)             ; Get string char
    call    to_upper            ; 'a-z' -> 'A-Z'
    cp      '='
    jr      nz, .dos_char
    ld      a, '~'              ; Convert '=' to '~'
.dos_char:
    ld      (de), a             ; Copy char to filename
    inc     hl
    inc     de
    djnz    .copy_str           ; Loop back to copy next char
    jr      .got_name           ; Done
.null_str:
    ld      a, $08              ; Function code error
    jr      .get_filename_done
.type_mismatch:
    ld      a, $18              ; Type mismatch error
    jr      .get_filename_done
.got_name:
    xor     a                   ; No error
    ld      (de), a             ; Terminate filename
.get_filename_done:
    pop     hl                  ; Restore BASIC text pointer
    or      a                   ; Test error code
    ret

;-----------------------------------------------------------------------------
; Determine file type from extension
;
; Examines extension to determine filetype eg. "name.BIN" is binary
;
;  out: A = file type:
;             0       bad name
;          FT_NONE    no extension
;          FT_OTHER   unknown extension
;          FT_TXT     ASCII text
;          FT_BIN     binary code/data
;          FT_BAS     BASIC program
;          FT_CAQ     tape file
;-----------------------------------------------------------------------------
dos__getfiletype:
    push  hl
    ld    hl, FileName
    ld    b, -1             ; B = position of '.' in filename
_gft_find_dot:
    inc   b
    ld    a, b
    cp    9                 ; Error if name > 8 charcters long
    jr    nc, _gft_error
    ld    a, (hl)           ; Get next char in filename
    inc   hl
    cp    '.'               ; Is it a '.'?
    jr    z, _gft_got_dot
    or    a                 ; End of string?
    jr    z, _gft_no_extn
    jr    _gft_find_dot     ; Continue searching for '.'
_gft_got_dot:
    ld    a, b
    or    a                 ; Error if no name
    jr    z, _gft_error
    ld    a, (hl)
    or    a                 ; If '.' is last char then no extn
    jr    z, _gft_no_extn
    ld    de, extn_list     ; DE = list of extension names
    jr    _gft_search
_gft_skip:
    or    a
    jr    z, _gft_next
    ld    a, (de)
    inc   de                ; Skip extn name in list
    jr    _gft_skip
_gft_next:
    inc   de                ; Skip filetype in list
_gft_search:
    ld    a, (de)
    or    a                 ; End of filetypes list?
    jr    z, _gft_other
    push  hl
    call  strcmp            ; Compare extn to name in list
    pop   hl
    jr    nz, _gft_skip     ; If no match then keep searching
_gft_got_extn:
    ld    a, (de)           ; Get filetype
    jr    _gft_done
_gft_other:
    ld    a, FT_OTHER       ; Unknown filetype
    jr    _gft_done
_gft_no_extn:
    ld    a, FT_NONE        ; No extn (eg. "name", "name.")
    jr    _gft_done
_gft_error:
    xor   a                 ; 0 = bad name
_gft_done:
    pop   hl
    ret

extn_list:
    db "TXT", 0, FT_TXT     ; ASCII text
    db "BIN", 0, FT_BIN     ; Binary code/data
    db "BAS", 0, FT_BAS     ; BASIC program
    db "CAQ", 0, FT_CAQ     ; Tape file (BASIC, Array, ???)
    db 0

;-----------------------------------------------------------------------------
; Convert character to MSDOS equivalent
;
;  Input:  a = char
; Output:  a = MSDOS compatible char
;
; converts:-
;     lowercase to uppercase
;     '=' -> '~' (in case we cannot type '~' on the keyboard!)
;-----------------------------------------------------------------------------
dos__char:
    call    to_upper
    cp      '='
    ret     nz          ; Convert '=' to '~'
    ld      a, '~'
    ret
