all:	vcasm  ld

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
	#gcc -std=c90 -I /home/paul/tt10/vc16/bsd/usr/include -I /home/paul/tt10/vc16/bsd/usr//sys -I /home/paul/tt10/vc16/bsd/usr//sys/h -I /home/paul/tt10/vc16/bsd/usr/bin/ar/  -o ld ld.c -g
	gcc -D_VC_ -std=c90 -I /home/paul/tt10/vc16/bsd/usr/bin/ar/  -o ld ld.c -g

install:	vcasm ld
	cp vcasm /usr/local/bin/vc16-bsd-as
	cp ld /usr/local/bin/vc16-bsd-ld
