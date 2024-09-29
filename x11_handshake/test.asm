section .data
    display db "/tmp/.X11-unix/X0", 0             ; X11 socket path
    x11_handshake_msg db "X11 Handshake Succeeded!", 10, 0
    x11_failed_msg db "X11 Handshake Failed!", 10, 0
    sock_error_msg db "Error creating socket!", 10, 0
    connect_error_msg db "Error connecting to X server!", 10, 0
    send_error_msg db "Error sending handshake request!", 10, 0
    recv_error_msg db "Error receiving response!", 10, 0

    ; X11 handshake request packet
    byte_order db 'l'                             ; 'l' for little endian
    protocol_major dw 11                          ; X11 Protocol major version
    protocol_minor dw 0                           ; X11 Protocol minor version
    auth_proto_len dw 0                           ; Length of authentication protocol name
    auth_data_len dw 0                            ; Length of authentication data
    padding db 0                                  ; Padding to align to 4-byte boundary

section .bss
    sockfd resd 1                                 ; Socket file descriptor
    sockaddr resb 110                             ; sockaddr structure

section .text
    global _start

_start:
    ; Create the UNIX socket
    mov eax, 41                                   ; syscall: socket
    mov edi, 1                                    ; AF_UNIX
    mov esi, 1                                    ; SOCK_STREAM
    xor edx, edx                                  ; protocol 0
    syscall
    test eax, eax
    js sock_fail                                  ; If the syscall failed, jump to sock_fail
    mov [sockfd], eax                             ; Save socket file descriptor

    ; Set up sockaddr_un
    mov byte [sockaddr], 1                        ; AF_UNIX
    lea rsi, [display]
    lea rdi, [sockaddr + 2]                       ; Leave space for sun_family
    mov rcx, 108                                  ; Copy length
    rep movsb

    ; Connect to the X server
    mov eax, 42                                   ; syscall: connect
    mov edi, [sockfd]
    lea rsi, [sockaddr]
    mov edx, 110                                  ; sizeof(sockaddr_un)
    syscall
    test eax, eax
    js connect_fail                               ; If the syscall failed, jump to connect_fail

    ; Send the X11 handshake request
    mov eax, 44                                   ; syscall: sendto
    mov edi, [sockfd]                             ; Socket descriptor
    lea rsi, [byte_order]                         ; Point to the start of the handshake packet
    mov edx, 12                                   ; Size of the packet
    xor r10d, r10d                                ; flags = 0
    syscall
    test eax, eax
    js send_fail                                  ; If the syscall failed, jump to send_fail

    ; Receive the response from the X server
    mov eax, 45                                   ; syscall: recvfrom
    mov edi, [sockfd]                             ; Socket descriptor
    sub rsp, 256                                  ; Allocate space on the stack for the response
    mov rsi, rsp                                  ; Buffer to receive the response
    mov edx, 256                                  ; Buffer size
    xor r10d, r10d                                ; flags = 0
    syscall
    test eax, eax
    js recv_fail                                  ; If the syscall failed, jump to recv_fail

    ; Check if the response is valid (successful handshake)
    cmp byte [rsp], 1                             ; Check if the first byte (Success) == 1
    jne handshake_fail

    ; Successfully connected to X server
    mov rax, 1                                    ; syscall: write
    mov rdi, 1                                    ; stdout
    lea rsi, [x11_handshake_msg]
    mov rdx, 23                                   ; message length
    syscall

    ; Clean exit
    mov eax, 60                                   ; syscall: exit
    xor edi, edi
    syscall

sock_fail:
    ; Print socket creation failure message
    mov rax, 1
    mov rdi, 1
    lea rsi, [sock_error_msg]
    mov rdx, 23
    syscall
    jmp exit_fail

connect_fail:
    ; Print connection failure message
    mov rax, 1
    mov rdi, 1
    lea rsi, [connect_error_msg]
    mov rdx, 31
    syscall
    jmp exit_fail

send_fail:
    ; Print send failure message
    mov rax, 1
    mov rdi, 1
    lea rsi, [send_error_msg]
    mov rdx, 28
    syscall
    jmp exit_fail

recv_fail:
    ; Print receive failure message
    mov rax, 1
    mov rdi, 1
    lea rsi, [recv_error_msg]
    mov rdx, 27
    syscall
    jmp exit_fail

handshake_fail:
    ; Print general handshake failure message
    mov rax, 1
    mov rdi, 1
    lea rsi, [x11_failed_msg]
    mov rdx, 22
    syscall

exit_fail:
    ; Exit with failure status
    mov eax, 60                                   ; syscall: exit
    mov edi, 1
    syscall
