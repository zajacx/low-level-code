global _start

SYS_READ	equ 0
SYS_WRITE	equ 1
SYS_OPEN	equ 2
SYS_CLOSE	equ 3
SYS_EXIT	equ 60

O_RDONLY	equ 0x0000				; Tryb tylko do odczytu.
O_WRONLY	equ 0x0001				; Tryb tylko do zapisu.
O_CREAT		equ 0x00040				; Jeśli plik nie istnieje, tworzy nowy, wpp jest otwierany.
O_EXCL		equ 0x0080				; Wywołuje błąd sys_open przy próbie nadpisania pliku.

section .bss

read_buffer: resb 8192
write_buffer: resb 8192

section .rodata

mode			equ 0o644			; Uprawnienia -rw-r--r--.
parameters		equ 3				; Parametry: nazwa programu, nazwa pliku wejściowego i wyjściowego.
read_size		equ 1024			; Liczba bajtów w buforze odczytu.
length_size		equ 2				; Długość segmentu bez 's' i 'S' zapisujemy na dwóch bajtach.
char_size		equ 1				; Kopiowany znak 's' lub 'S' ma rozmiar 1 bajta.
modulo			equ 65536
error_code		equ 1
non_error_code	equ 0

section .text

_start:
									; Test liczby parametrów:
	mov     rcx, [rsp]  			; Ładuje do rcx liczbę parametrów.
	cmp     rcx, parameters			; Jeśli liczba parametrów jest różna od oczekiwanej (2),
	jne     partial_error_exit		; program się kończy.

									; Otwarcie pliku do odczytu:
	mov		rdi, [rsp + 16]			; Nazwa pliku do otwarcia (zdejmujemy ze stosu).
	mov		rsi, O_RDONLY			; Tryb tylko do odczytu.
	mov		rax, SYS_OPEN
	syscall

	cmp		rax, 0					; Sprawdzenie, czy syscall się powiódł.
	jl		partial_error_exit		; Jeśli w rax jest kod błędu, program się kończy.
	mov 	r8, rax					; Jeśli się udało, zapamiętuje deskryptor pliku wejściowego w r8.

									; Tworzenie pliku do zapisu:
	mov		rdi, [rsp + 24]			; Nazwa tworzonego pliku (zdejmujemy ze stosu).
	mov		rsi, O_WRONLY | O_CREAT | O_EXCL
	mov		rdx, mode				; Uprawnienia: -rw-r--r--.
	mov		rax, SYS_OPEN
	syscall

	cmp 	rax, 0					; Sprawdzenie, czy syscall się powiódł.
	jl		error_exit				; Jeśli w rax jest kod błędu, program się kończy.
	mov 	r9, rax					; Jeśli się udało, zapamiętuje deskryptor pliku wyjściowego w r9.

	xor 	r10, r10				; Licznik długości spójnego segmentu bez 's' i 'S'

file_to_buffer:
									; Odczyt z pliku źródłowego do bufora:
	mov 	rdx, read_size
	mov		rsi, read_buffer
	mov		rdi, r8
	mov		rax, SYS_READ
	syscall

	cmp 	rax, 0					; W rax jest liczba odczytanych bajtów / kod błędu.
	jl		error_exit				; Jeśli nastąpił błąd odczytu, program się kończy.
	mov		r12, rax				; r12 - licznik bajtów pozostałych do odczytania z bufora.
	je		end_of_file				; Wczytano zero znaków <=> skończył się plik źródłowy.
									; (Gdy program nie napotka błędów, kończy się właśnie tu.)

	mov		r13, [read_buffer]		; Do r13 przenosi pierwsze 8 bajtów bufora odczytu.
	xor		rbx, rbx				; rbx - licznik iteracji po buforze.

buffer_loop:						; Przejście po buforze:
	mov		rax, rbx
	and		rax, 7					; Sprawdzenie, czy skończył się rejestr r13.
	cmp		rax, 0					; Jeśli tak, koniunkcja bitowa iteratora z zerem daje 0.

	cmove	r13, [read_buffer + rbx]; W rbx jest pozycja, od której zaczyna się kolejny
									; ośmiobajtowy kawałek do zbadania - przenosi do r13.

	cmp		r13b, 's'				; Porównuje ostatni bajt w r13 z 's'.
	je		write_non_s
	cmp		r13b, 'S'

	jne		count_non_s				; Jeśli ten bajt nie jest kodem 's' ani 'S', inkrementuj rcx.

write_non_s:
	mov		[write_buffer], r10
	cmp		r10, 0
	mov		r10, 0

	je		write_s

	mov		rdx, length_size		; Jeśli przed znalezionym 's' lub 'S' były inne znaki,
	mov		rsi, write_buffer		; wypisuje ich liczbę przechowywaną w r10.
	mov		rdi, r9
	mov		rax, SYS_WRITE
	syscall

	cmp		rax, 0
	jl		error_exit

write_s:
	mov		[write_buffer], r13b 	; Ostatni bajt rejestru r13 przechowuje znak do wypisania ('s' lub 'S').
	mov		rdx, char_size
	mov		rsi, write_buffer
	mov		rdi, r9
	mov		rax, SYS_WRITE
	syscall

	cmp		rax, 0
	jl		error_exit

	jmp		continue

count_non_s:						; Inkrementuje licznik znaków różnych od 's' i 'S'.
	inc		r10
	xor		rax, rax
	cmp		r10, modulo
	cmove	r10, rax				; Jeśli r10 osiąga 65536, jest on zerowany aby uniknąć przepełnienia.

continue:
	shr		r13, 8
	dec		r12						; Dekrementacja licznika bajtów, które pozostały do odczytania z bufora.
	inc		rbx
	cmp		r12, 0
	jg		buffer_loop
	jmp		file_to_buffer

end_of_file:
	cmp		r10, 0					; Sprawdza, czy długość ew. ostatniego ciągu bez 's' i 'S' została wypisana.
	mov		r13d, 0
	je		good_exit

	mov		[write_buffer], r10		; Wypisuje ostatnią długość.
	mov		rdx, length_size
	mov		rsi, write_buffer
	mov		rdi, r9
	mov		rax, SYS_WRITE
	syscall

	cmp		rax, 0
	jl		error_exit

	jmp		good_exit

partial_error_exit:
	mov		r13d, 1
	jmp		final_exit

error_exit:
	mov		r13d, 1

good_exit:
	mov		rdi, r9					; Zamyka plik wyjściowy.
	mov		rax, SYS_CLOSE
	syscall

	mov		r10d, 1
	cmp		rax, 0					; Jeśli zamknięcie się nie udało, w r13d umieszcza kod błędu.
	cmovl	r13d, r10d

final_exit:
	mov		rdi, r8					; Zamyka plik wejściowy.
	mov		rax, SYS_CLOSE
	syscall

	mov		r10d, 1
	cmp		rax, 0
	cmovl	r13d, r10d

	mov		edi, r13d
	mov		rax, SYS_EXIT
	syscall
