CC	= gcc
CFLAGS	= -Wall -Wextra -Wno-implicit-fallthrough -std=gnu17 -fPIC -O2
LDFLAGS	= -shared -Wl,--wrap=malloc -Wl,--wrap=calloc -Wl,--wrap=realloc -Wl,--wrap=reallocarray -Wl,--wrap=free -Wl,--wrap=strdup -Wl,--wrap=strndup

.PHONY: all clean

all: libseq.so

seq.o: seq.c seq.h
	$(CC) $(CFLAGS) -c $<

memory_tests.o: memory_tests.c memory_tests.h
	$(CC) $(CFLAGS) -c $<

libseq.so: seq.o memory_tests.o
	$(CC) $(LDFLAGS) -o $@ $^

clean:
	rm -rf *.o *.so
