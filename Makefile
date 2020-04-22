CC=		gcc
CFLAGS=		-g -Wall -Werror -std=gnu99 -Iinclude
LD=		gcc
LDFLAGS=	-L.
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

src/%.o: src/%.c include/spidey.h
	$(CC) $(CFLAGS) -c -o $@ $<

lib/libspidey.a: $(SOURCES)
	$(AR) $(ARFLAGS) $@ $^

bin/spidey: lib/libspidey.a src/spidey.o
	$(LD) $(LDFLAGS) -o $@ $^

