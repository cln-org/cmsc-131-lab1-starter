;
; encode.asm - build a 20-byte IPv4 header from the field struct.
;
; This is your starting point. It assembles and links as-is, so the build
; works before you write any code. Right now it writes nothing, so the
; twenty bytes driver.c saves are whatever the buffer held. Your job is to
; replace that with the construction described below.
;
; The contract, from driver.c:
;
;       unsigned char *hdr        [ebp+12]
;       struct ipv4_fields *in    [ebp+8]
;
; driver.c documents the struct layout:
;
;   +0 version   +4 ihl    +8 dscp   +12 ecn   +16 total_length
;   +20 identification    +24 flags  +28 fragment_offset
;   +32 ttl      +36 protocol       +40 checksum
;   +44 src[0..3]                   +48 dst[0..3]
;
; You write twenty bytes into hdr. Every multi-byte field goes out
; big-endian: the high byte first. The fragment offset's top five bits share
; byte 6 with the three flag bits. Its bottom eight bits are byte 7.
;
; The checksum is your job too. Bytes 10-11 must read as zero while the
; checksum is computed. Write them as zero, call ip_checksum over the
; finished header, and store its result into the field. The struct's
; checksum member is read on the decode path only. Don't copy it here.
;
; Do not clobber ebx, esi, edi, or ebp. C assumes they survive your call.
; Return in eax (driver.c ignores it here, so returning 0 is fine).
;

; Windows C puts a leading underscore on every exported name. Linux C does
; not. The Makefile passes -d ELF_TYPE on Linux. This block then respells
; the names below to match. asm_io.inc does the same for _asm_main in the
; bootcamp blocks. Leave this block alone.
%ifdef ELF_TYPE
  %define _ip_checksum ip_checksum
  %define _encode_header encode_header
  section .note.GNU-stack noalloc noexec nowrite progbits
%endif

extern _ip_checksum

segment .text
        global  _encode_header
_encode_header:
        ;
        ; TODO: build the header from the struct.
        ;
        ; This is the reverse of decode. Mask each field to its width,
        ; shift it up to where it lives, or the pieces of a shared byte
        ; together, then store the byte. The fields that do not straddle
        ; anything are one store each.
        ;
        ; The checksum comes last, after every other byte is written. Write
        ; bytes 10-11 as zero, call ip_checksum with the header and 20, and
        ; store its result (in ax) into the field big-endian. Computing it
        ; before the rest of the header is in place sums whatever garbage
        ; was in the buffer. ip_checksum preserves ebx, esi, edi, and ebp,
        ; so a pointer kept in one of those survives the call. eax, ecx, and
        ; edx do not.
        ;
        
        enter   0,0
        pusha

        mov     esi, [ebp + 8]          ; in struct pointer
        mov     edi, [ebp + 12]         ; hdr pointer to output buffer

        ; byte 0: version (high nibble), ihl (low nibble)
        mov     eax,  [esi + 0]         ; version from src
        shl     eax, 4                  ; puts version to high nibble of ax's al (bits 4-7)
        mov     ebx, [esi + 4]          ; ihl from src
        and     ebx, 0x0F               ; defensive masking to clear high bits of ebx so only ihl remains
        or      eax, ebx                ; combine version and ihl
        mov     [edi + 0], al           ; moves low 8 bits of eax into byte 0

        ; byte 1: dcsp (high 6 bits), ecn (low 2 bits)
        mov     eax, [esi + 8]          ; dcsp from src
        shl     eax, 2                  ; puts dcsp to high nibble of eax's al (bits 2-7)
        mov     ebx, [esi + 12]         ; ecn from src
        and     ebx, 0x03               ; defensive masking to clear high bits of ebx so only ecn remains
        or      eax, ebx                ; combine dcsp and ecn 
        mov     [edi + 1], al           ; move low 8 bits of eax to byte 1

        ; byte 2-3: total length (16 bits, big-endian)
        mov     eax, [esi + 16]         ; total length from src, contains 32 bits but only low 16 bits matter
        mov     [edi + 2], ah           ; since big-endian, high byte of low 16 bits first (bits 8-15)
        mov     [edi + 3], al           ; low byte of low 16 bits next (bits 0-7)

        ; byte 4-5: identification (16 bits, big-endian)
        mov     eax, [esi + 20]         ; identification from src
        mov     [edi + 4], ah           ; since big-endian, high byte of low 16 bits (ax) first (bits 8-15)
        mov     [edi + 5], al           ; low byte of low 16 bits (ax) next (bits 0-7)

        ; byte 6-7 (six seven!): flags (high 3 bits), fragment offset (low 13 bits)
        mov     eax, [esi + 24]         ; flags from src
        shl     eax, 13                 ; put flags (3 bits) back to high byte of ax  (bits 13-15)
        mov     ebx, [esi + 28]         ; fragment offset from src
        and     ebx, 0x1FFF             ; mask the fragment offset
        or      eax, ebx                ; combine flag and the 13-bit fragment offset
        mov     [edi + 6], ah           ; since big-endian, high byte of low 16 bits first (bits 8-15)
        mov     [edi + 7], al           ; low byte of low 16 bits (ax) next (bits 0-7)

        ; byte 8-9: ttl (byte 8), protocol (byte 9)
        mov     eax, [esi + 32]         ; ttl from src
        mov     [edi + 8], al           ; ttl from low byte (al) of low 16 bits (ax) (bits 0-7)
        mov     eax, [esi + 36]         ; protocol from src
        mov     [edi + 9], al           ; protocol from low byte (al) of low 16 bits (ax) (bits 0-7)

        ; byte 10-11: header checksum (16 bits, big-endian)
        ; must read 0 before ip_checksum runs
        mov     byte [edi + 10], 0
        mov     byte [edi + 11], 0

        ; byte 12-15: source address (32 bits)
        ; src [0]
        mov     al, [esi + 44]          
        mov     [edi + 12], al
        ; src [1]
        mov     al, [esi + 45]
        mov     [edi + 13], al
        ; src [2]
        mov     al, [esi + 46]
        mov     [edi + 14], al
        ; src [3]
        mov     al, [esi + 47]
        mov     [edi + 15], al

        ; byte 16-19: destination address (32 bits)
        ; dest [0]
        mov     al, [esi + 48]
        mov     [edi + 16], al
        ; dest [1]
        mov     al, [esi + 49]
        mov     [edi + 17], al
        ; dest [2]
        mov     al, [esi + 50]
        mov     [edi + 18], al
        ; dest [3]
        mov     al, [esi + 51]
        mov     [edi + 19], al

        ; computing real checksum
        push    20
        push    edi
        call    _ip_checksum
        add     esp, 8          ; caller cleans stack

        ; store computed checksum in its corresponding bytes, big-endian ordering
        mov     [edi + 10], ah
        mov     [edi + 11], al

        popa
        mov     eax, 0
        leave
        ret
