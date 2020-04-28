CC=		gcc
CFLAGS=		-g -Wall -Werror -std=gnu99 -Iinclude # -Werror
LD=		gcc
LDFLAGS=	-Llib
AR=		ar
ARFLAGS=	rcs
TARGETS=	bin/spidey
SOURCES=   src/forking.o \
			src/handler.o \
			src/request.o \
			src/single.o \
			src/socket.o \
			src/utils.o 

all:		$(TARGETS)

clean:
	@echo Cleaning...
	@rm -f $(TARGETS) lib/*.a src/*.o *.log *.input

.PHONY:		all test clean

# TODO: Add rules for bin/spidey, lib/libspidey.a, and any intermediate objects

src/%.o: src/%.c
	$(CC) $(CFLAGS) -c -o $@ $^

bin/spidey: src/spidey.o lib/libspidey.a
	$(LD) $(LDFLAGS) -o $@ $^

lib/libspidey.a: $(SOURCES)
	$(AR) $(ARFLAGS) $@ $^

