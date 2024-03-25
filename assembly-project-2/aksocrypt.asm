global _start

SYS_READ        equ 0
SYS_WRITE       equ 1
SYS_OPEN        equ 2
SYS_CLOSE       equ 3
SYS_LSEEK   	equ 8
SYS_EXIT        equ 60

O_RDWR          equ 2

section .bss
read_buffer     resb 1024               ; Bufory odczytu i zapisu - rozmiar jest wygodną potęgą
write_buffer    resb 1024               ; dwójki, dostatecznie duży by zoptymalizować czas działania
                                        ; przy przeciętnych plikach, jednak znacznie mniejszy
                                        ; niż wolna pamięć wirtualna użytkownika na maszynie students
                                        ; (31824B), przez co program nie spowalnia znacząco innych procesów.

section .rodata
parameters      equ 3                   ; Parametry: nazwa programu, nazwa pliku, klucz.
buffer_size     equ 1024
letter_distance equ 0x0020
error_code      equ 1
ten             equ 0x000A

section .text

_start:
    mov     rcx, [rsp]                  ; * TEST LICZBY PARAMETRÓW *
    cmp     rcx, parameters             ; Jeśli liczba parametrów jest różna od oczekiwanej,
    jne     .parameters_error           ; program się kończy.

    mov     rdi, [rsp + 16]             ; Pobranie ze stosu wskaźnika na nazwę pliku do otwarcia.
    mov     rsi, O_RDWR                 ; Tryb do odczytu i zapisu.
    mov     rax, SYS_OPEN               ; Otwarcie pliku.
    syscall

    cmp	    rax, 0                      ; Sprawdzenie poprawności wywołania systemowego.
    jl	    .parameters_error           ; Jeśli w rax jest kod błędu, program się kończy.
    mov	    r8, rax                     ; Jeśli się udało, deskryptor pliku jest zapisywany w r8.

    mov     rsi, [rsp + 24]             ; * TEST POPRAWNOŚCI KLUCZA *
    xor     rbx, rbx                    ; rbx - aktualnie badany znak,
    xor     rcx, rcx                    ; rcx - pozycja aktualnie badanego znaku.

.key_test_loop:
    movzx   rbx, byte [rsi + rcx]       ; Przeniesienie jednego znaku klucza do rbx.
    cmp     rbx, 0                      ; 0 - koniec ciągu znaków.
    je      .key_length_test

    cmp     rbx, '0'                    ; Sprawdzenie, czy znak jest w zakresie '0' - '9'.
    jl      .error
    cmp     rbx, '9'
    jle     .good_digit

    cmp     rbx, 'A'                    ; Sprawdzenie, czy znak jest w zakresie 'A' - 'F'.
    jl      .error
    cmp     rbx, 'F'
    jle     .good_digit

    cmp     rbx, 'a'                    ; Sprawdzenie, czy znak jest w zakresie 'a' - 'f'.
    jl      .error
    cmp     rbx, 'f'
    jle     .good_digit

    jmp     .error

.good_digit:
    inc     rcx
    jmp     .key_test_loop

.key_length_test:
    mov     r12, rcx                    ; r12 - długość klucza szyfrowania.
    and     rcx, 1                      ; Koniunkcja bitowa z 1 da 0, gdy napis jest parzystej długości.
    cmp     rcx, 0                      ; Jeśli tak jest, klucz jest dobry - przejście do szyfrowania.
    jne     .error                      ; Jeśli nie - zakończenie programu.

                                        ; * ROZPOCZĘCIE SZYFROWANIA PLIKU *
    mov     r13, [rsp + 24]             ; r13 - wskaźnik na klucz szyfrowania,
    xor     r15, r15                    ; r15 - liczba do tej pory zaszyfrowanych bajtów pliku,
    xor     r9, r9                      ; r9 - indeks znaku klucza.

.read_from_buffer:
    mov     rdx, buffer_size            ; Odczyt z pliku do bufora.
    mov     rsi, read_buffer
    mov     rdi, r8
    mov     rax, SYS_READ
    syscall

    cmp     rax, 0                      ; Sprawdzenie poprawności wywołania systemowego.
    jl      .error                      ; Zakończenie programu, jeśli w rax jest kod błędu.
    je      .end_of_file                ; Skok do zamknięcia pliku, jeśli się skończył.
    mov     r14, rax                    ; W przeciwnym przypadku w rax jest liczba odczytanych bajtów.

    xor     rdx, rdx                    ; Ustawienie pozycji odczytu/zapisu odpowiednio względem początku pliku.
    mov     rsi, r15
    mov     rdi, r8
    mov     rax, SYS_LSEEK
    syscall

    cmp     rax, 0                      ; Sprawdzenie poprawności wywołania systemowego.
    jl      .error
                                        ; Przygotowanie liczników:
    add     r15, r14                    ; Zwiększenie licznika obsłużonych bajtów o liczbę odczytanych.
    xor     rcx, rcx                    ; rcx - licznik zaszyfrowanych bajtów w buforze zapisu,
    mov     rsi, read_buffer            ; rsi - wskaźnik na aktualny znak w buforze odczytu,
    mov     rdi, write_buffer           ; rdi - wskaźnik na aktualną pozycję w buforze zapisu.

.convert:                               ; * KONWERSJA DWUZNAKOWEJ REPREZENTACJI BAJTU KLUCZA NA WARTOŚĆ LICZBOWĄ *
    mov     al, byte [r13 + r9]         ; Przeniesienie do al pierwszego znaku z kodu bajtu.
    inc     r9
    mov     bl, byte [r13 + r9]         ; Przeniesienie do bl drugiego znaku z kodu bajtu.
    inc     r9
                                        ; * KONWERSJA PIERWSZEGO ZNAKU *
    cmp     al, '9'                     ; Odjęcie kodu znaku '0', jeśli znak reprezentuje cyfrę.
    jbe     .convert_digit_1

    cmp     al, 'a'                     ; Zamiana małej litery na odpowiadającą jej wielką literę -
    jb      .convert_uppercase_1
    sub     al, letter_distance         ; odejmowanie stałej odległości między wielką a małą literą.

.convert_uppercase_1:
    add     al, ten                     ; Konwersja wielkiej litery na wartość liczbową -
    sub     al, 'A'                     ; odejmowanie wartości ('A' - 10).
    jmp     .convert_continue_1

.convert_digit_1:
    sub     al, '0'

.convert_continue_1:
    shl     al, 4                       ; Przesunięcie bitowe w lewo o 4 bity - mnożenie przez 16.
                                        ; * KONWERSJA DRUGIEGO ZNAKU *
    cmp     bl, '9'                     ; Konwersja odbywa się tak samo.
    jbe     .convert_digit_2

    cmp     bl, 'a'
    jb      .convert_uppercase_2
    sub     bl, letter_distance

.convert_uppercase_2:
    add     bl, ten
    sub     bl, 'A'
    jmp     .convert_continue_2

.convert_digit_2:
    sub     bl, '0'

.convert_continue_2:
    add     al, bl                      ; W al znajduje się wartość liczbowa reprezentowana przez dwa znaki klucza.

.xor:
    mov     bl, byte [rsi]              ; Przeniesienie do bl bajtu z bufora odczytu w celu zaszyfrowania.
    xor     al, bl                      ; Szyfrowanie operacją xor.
    mov     [rdi], al                   ; Przeniesienie do bufora zapisu zaszyfrowanego bajtu.
    inc     rsi                         ; Przejście do następnego znaku w buforze odczytu.
    inc     rdi                         ; Przejście do następnej pozycji w buforze zapisu.
    xor     rbx, rbx                    ; Pomocnicze wykorzystanie rbx.
    cmp     r9, r12
    cmove   r9, rbx                     ; Przejście na początek klucza, gdy zostanie osiągnięty jego koniec.
    inc     rcx                         ; Zliczenie zaszyfrowanego znaku.
    cmp     rcx, r14                    ; Sprawdzenie, czy zostały jeszcze znaki do szyfrowania.
    jl      .convert

.write_to_file:
    mov     rdx, r14
    mov     rsi, write_buffer
    mov     rdi, r8
    mov     rax, SYS_WRITE              ; Zapis do pliku zawartości bufora zapisu.
    syscall

    cmp     rax, 0                      ; Sprawdzenie poprawności wywołania systemowego.
    jl      .error

    jmp     .read_from_buffer

.end_of_file:
    xor     r10, r10
    jmp     .close_file                 ; Skok do operacji zamknięcia pliku w przypadku braku błędów.

.parameters_error:
    mov     r10, error_code             ; Umieszczenie kodu błędu w r10.
    jmp     .exit                       ; Skok do zakończenia programu, gdy nie został jeszcze otwarty plik.

.error:
    mov     r10, error_code

.close_file:
    mov	    rdi, r8                     ; Zamknięcie pliku w przypadku wystąpienia dowolnego błędu po jego otwarciu.
    mov	    rax, SYS_CLOSE
    syscall

    cmp     rax, 0                      ; Sprawdzenie poprawności operacji zamknięcia pliku.
    mov     rbx, error_code
    cmovl   r10, rbx                    ; Ręczne umieszczenie kodu błędu.

.exit:
    mov	    rdi, r10
    mov	    rax, SYS_EXIT               ; Zakończenie programu z kodem zapisanym w r10.
    syscall
