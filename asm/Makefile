all:	vcasm  ld nm

vcasm:	main.c vc.tab.c
	gcc -o vcasm main.c -g

vc.tab.c: vc.y
	bison vc.y -k

test:	vcasm test.s
	./vcasm -s -m -o ../test/init.v test.s

init.bin:	vcasm init.s
	./vcasm -b -m -o init.bin init.s

boot.bin:	vcasm boot.s
	./vcasm -b -m -o boot.bin boot.s

start.bin:	vcasm start.s
	./vcasm -b -m -o start.bin start.s

ld:	ld.c	
	gcc -D_VC_ -std=c90 -I ar  -o ld ld.c -g

nm:	nm.c	
	gcc -D_VC_ -std=c90 -I ar -o nm nm.c -g ar/nsym.c

ar/ar:	ar/append.c ar/ar.c ar/archive.c ar/contents.c ar/delete.c ar/extract.c ar/misc.c \
        ar/move.c ar/print.c ar/replace.c
	cd ar;make ar

install:	vcasm ld nm ar/ar
	cp vcasm /usr/local/bin/vc16-bsd-as
	cp ld /usr/local/bin/vc16-bsd-ld
	cp nm /usr/local/bin/vc16-bsd-nm
	cp ar/ar /usr/local/bin/vc16-bsd-ar

clean:
	rm -f *.o vcasm ld nm
	cd ar; make clean; 
