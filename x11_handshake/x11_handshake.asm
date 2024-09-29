BITS 64
section .data
    ; X11 server path
    sun_path db "/tmp/.X11-unix/X0", 0
    msg_success db "X11 Handshake Success!", 0xA
    len_success equ $ - msg_success
    msg_failure db "X11 Handshake Failed!", 0xA
    len_failure equ $ - msg_failure

section .bss
    fd resq 1   ; file descriptor storage
    buffer resb 32  ; Buffer for the handshake reply

section .text
global _start

%define AF_UNIX 1
%define SOCK_STREAM 1

%define SYSCALL_SOCKET 41
%define SYSCALL_CONNECT 42
%define SYSCALL_WRITE 1
%define SYSCALL_READ 0
%define SYSCALL_EXIT 60

_start:
    ; Create a socket
    mov rax, SYSCALL_SOCKET
    mov rdi, AF_UNIX    ; AF_UNIX socket
    mov rsi, SOCK_STREAM ; Stream type
    xor rdx, rdx        ; Protocol (0 = default)
    syscall
    test rax, rax
    js handshake_fail
    mov [fd], rax       ; Store the socket file descriptor

    ; Set up sockaddr_un structure (stored on the stack)
    sub rsp, 112        ; Reserve space on stack for sockaddr_un
    mov word [rsp], AF_UNIX
    lea rsi, [sun_path]
    lea rdi, [rsp + 2]
    mov rcx, 19         ; Copy length of the sun_path (including null terminator)
    cld                 ; Clear direction flag
    rep movsb           ; Copy sun_path into sockaddr_un.sun_path

    ; Connect to the X server
    mov rdi, [fd]       ; Socket file descriptor
    mov rax, SYSCALL_CONNECT
    lea rsi, [rsp]
    mov rdx, 110        ; Length of sockaddr_un
    syscall
    test rax, rax
    js handshake_fail

    ; Send X11 handshake request
    sub rsp, 12         ; Allocate 12 bytes for handshake message
    mov byte [rsp], 'l' ; Set byte order: 'l' for little-endian
    mov word [rsp + 2], 11 ; Protocol version 11
    mov word [rsp + 4], 0 ; Protocol minor version 0
    mov dword [rsp + 6], 0 ; Authorization data (lengths all zero for now)

    mov rax, SYSCALL_WRITE
    mov rdi, [fd]       ; Socket file descriptor
    mov rsi, rsp        ; Handshake buffer
    mov rdx, 12         ; Length of handshake message
    syscall
    test rax, rax
    jnz handshake_fail

    ; Receive the X11 server response
    mov rax, SYSCALL_READ
    mov rdi, [fd]
    mov rsi, buffer     ; Buffer to read into
    mov rdx, 8          ; Expecting 8 bytes response
    syscall
    test rax, rax
    js handshake_fail

    ; Check if the first byte of the response is '1' (indicating success)
    cmp byte [buffer], 1
    jne handshake_fail

    ; If success, print "X11 Handshake Success!"
    mov rax, SYSCALL_WRITE
    mov rdi, 1          ; File descriptor 1 = stdout
    lea rsi, [msg_success]
    mov rdx, len_success
    syscall
    jmp exit_program

handshake_fail:
    ; Print "X11 Handshake Failed!"
    mov rax, SYSCALL_WRITE
    mov rdi, 1          ; File descriptor 1 = stdout
    lea rsi, [msg_failure]
    mov rdx, len_failure
    syscall

exit_program:
    ; Exit the program
    mov rax, SYSCALL_EXIT
    xor rdi, rdi        ; Exit code 0
    syscall
