#if	defined(DOSCCS) && !defined(lint)
static char *sccsid = "@(#)ld.c	4.2 1/2/94";
#endif

static hreset();

/*
 * 4.3 1/14/94 - sms
 *	Make the number of VM segments a compile time option in the Makefile.
 * 4.2 1/2/94 - sms
 *	Fixed a couple serious bugs, one dealing with overlaid programs - the
 *	overlay header wasn't being written out, the second was a typographical
 *	error causing the relocation information to be wrong.
 *
 * 4.1 11/27/93 -sms
 *	Success at reading new style object files and libraries but the
 *	speed was abysmal.  Logic added to attempt to hold string tables
 *	in memory when possible (less than 8kb) and to use a larger buffer
 *	when reading strings.  Also, added a fifth i/o stream area for use
 *	by the library scanning routine 'ldrand' - this prevents the 'thrashing'
 *	between 'load1' and 'ldrand' (each of these was undoing the other's
 *	seek for a string).
 *
 * 4.0 11/1/93 - sms
 *	Previous versions not released.  With 'ar' and 'ranlib' ported it
 *	is now 'ld's turn to be modified to support the new object file
 *	format.  Major changes (and unfortunately another slip in speed).
 *
 * 3.0 9/15/93 - sms
 *	Implement a VM tmp file for the symbol table.
 *
 * 2.x 9/3/93 - sms@wlv.iipo.gtegsc.com
 *	Couple of major changes made in preparation for supporting long
 *	symbol names.  'ld' was approximately 1kb away from not running
 *	at all (due to data+bss exceeding 56kb).  The first change
 *	made 'syshash' a bitmap saving 3.75kb.  The next change involved
 *	modifying 'ldrand' so that the entire table of contents from a
 *	library did not have to fit in memory at once - this saved about
 *	8kb.  The last major change was a rewrite of the input subsystem
 *	making it faster and simpler.
*/

#include <sys/param.h>
#include <sys/dir.h>
#include <stdio.h>
#include <signal.h>
#include <sys/stat.h>
#include <sys/file.h>
#include <string.h>

FILE *fdopen(int fd, const char *mode);
#define HAVE_VMF
#ifdef HAVE_VMF

typedef u_int32_t u_long;
typedef unsigned short u_int;
typedef unsigned short u_short;
typedef unsigned char u_car;

/*#include <sys/exec.h> */
#ifndef _EXEC_
#define _EXEC_
/*
 * Header prepended to each a.out file.
 */
struct  exec {
        short     a_magic;        /* magic number */
unsigned short    a_text;         /* size of text segment */
unsigned short    a_data;         /* size of initialized data */
unsigned short    a_bss;          /* size of uninitialized data */
unsigned short    a_syms;         /* size of symbol table */
unsigned short    a_entry;        /* entry point */
unsigned short    a_unused;       /* not used */
unsigned short    a_flag;         /* relocation info stripped */
};

#define NOVL    15              /* number of overlays */
struct  ovlhdr {
        short     max_ovl;        /* maximum overlay size */
unsigned short    ov_siz[NOVL];   /* size of i'th overlay */
};
/*
 * eXtended header definition for use with the new macros in a.out.h
*/
struct  xexec {
        struct  exec    e;
        struct  ovlhdr  o;
        };

#define A_MAGIC1        0407    /* normal */
#define A_MAGIC2        0410    /* read-only text */
#define A_MAGIC3        0411    /* separated I&D */
#define A_MAGIC4        0405    /* overlay */
#define A_MAGIC5        0430    /* auto-overlay (nonseparate) */
#define A_MAGIC6        0431    /* auto-overlay (separate) */

#endif


#ifndef _RANLIB_H_
#define _RANLIB_H_

#define RANLIBMAG       "__.SYMDEF"     /* archive file name */
#define RANLIBSKEW      3               /* creation time offset */

struct ranlib {
        union {
                unsigned short ran_strx;         /* string table index */
                char *ran_name;         /* in memory symbol name */
        } ran_un;
        unsigned short ran_off;                  /* archive file offset */
};

#endif /* !_RANLIB_H_ */

#ifndef _AR_H_
#define _AR_H_

/* Pre-4BSD archives had these magic numbers in them. */
#define OARMAG1 0177555
#define OARMAG2 0177545

#define ARMAG           "!<arch>\n"     /* ar "magic number" */
#define SARMAG          8               /* strlen(ARMAG); */

#define AR_EFMT1        "#1/"           /* extended format #1 */

struct ar_hdr {
        char ar_name[16];               /* name */
        char ar_date[12];               /* modification time */
        char ar_uid[6];                 /* user id */
        char ar_gid[6];                 /* group id */
        char ar_mode[8];                /* octal file permissions */
        char ar_size[10];               /* size in bytes */
#define ARFMAG  "`\n"
        char ar_fmag[2];                /* consistency check */
};

#endif /* !_AR_H_ */

#ifndef MAXNAMLEN
#define MAXNAMLEN       63
#endif


#ifndef _AOUT_H_
#define _AOUT_H_


#define N_BADMAG(x) \
        (((x).a_magic)!=A_MAGIC1 && ((x).a_magic)!=A_MAGIC2 && \
        ((x).a_magic)!=A_MAGIC3 && ((x).a_magic)!=A_MAGIC4 && \
        ((x).a_magic)!=A_MAGIC5 && ((x).a_magic)!=A_MAGIC6)

#define N_TXTOFF(x) \
        ((x).a_magic==A_MAGIC5 || (x).a_magic==A_MAGIC6 ? \
        sizeof(struct ovlhdr) + sizeof(struct exec) : sizeof(struct exec))

/*
 * The following were added as part of the new object file format.  They
 * call functions because calculating the sums of overlay sizes was too
 * messy (and verbose) to do 'inline'.
 *
 * NOTE: if the magic number is that of an overlaid object the program
 * must pass an extended header ('xexec') as the argument.
*/

/*#include <sys/types.h> */

off_t   n_stroff(), n_symoff(), n_datoff(), n_dreloc(), n_treloc();

#define N_STROFF(e) (n_stroff(&e))
#define N_SYMOFF(e) (n_symoff(&e))
#define N_DATOFF(e) (n_datoff(&e))
#define N_DRELOC(e) (n_dreloc(&e))
#define N_TRELOC(e) (n_treloc(&e))

off_t
n_stroff(ep)
        register struct xexec *ep;
        {
        off_t   l;

        l = n_symoff(ep);
        l += ep->e.a_syms;
        return(l);
        }

off_t   
n_datoff(ep)
        register struct xexec *ep;
        {
        off_t   l;
        
        l = n_treloc(ep);
        l -= ep->e.a_data;
        return(l);
        }


off_t
n_dreloc(ep)
        register struct xexec *ep;
        {
        off_t   l;
        register u_short *ov = ep->o.ov_siz;
        register int    i;

        l = (off_t)sizeof (struct exec) + ep->e.a_text + ep->e.a_data;
        if      (ep->e.a_magic == A_MAGIC5 || ep->e.a_magic == A_MAGIC6)
                {
                for     (i = 0; i < NOVL; i++)
                        l += *ov++;
                l += sizeof (struct ovlhdr);
                }
        l += ep->e.a_text;
        return(l);
}

off_t
n_treloc(ep)
        register struct xexec *ep;
        {
        off_t   l;

        l = n_dreloc(ep);
        l -= ep->e.a_text;
        return(l);
        }

off_t
n_symoff(ep)
        register struct xexec *ep;
        {
        register int    i;
        register u_short *ov;
        off_t   sum, l;

        l = (off_t) N_TXTOFF(ep->e);
        sum = (off_t)ep->e.a_text + ep->e.a_data;
        if      (ep->e.a_magic == A_MAGIC5 || ep->e.a_magic == A_MAGIC6)
                {
                for     (ov = ep->o.ov_siz, i = 0; i < NOVL; i++)
                        sum += *ov++;
                }
        l += sum;
        if      ((ep->e.a_flag & 1) == 0)       /* relocation present? */
                l += sum;
        return(l);
        }


#define _AOUT_INCLUDE_
/*#include <nlist.h> */

#ifndef _NLIST_H_
#define _NLIST_H_
/*#include <sys/types.h> */

/*
 * Symbol table entry format.  The #ifdef's are so that programs including
 * nlist.h can initialize nlist structures statically.
 */

struct  oldnlist {              /* XXX - compatibility/conversion aid */
        char    n_name[8];      /* symbol name */
        short     n_type;         /* type flag */
unsigned short    n_value;        /* value */
};

struct  nlist {
#ifdef  _AOUT_INCLUDE_
        union {
                char *n_name;   /* In memory address of symbol name */
                unsigned short n_strx;   /* String table offset (file) */
        } n_un;
#else
        char    *n_name;        /* symbol name (in memory) */
        char    *n_filler;      /* need to pad out to the union's size */
#endif
        unsigned char  n_type;         /* Type of symbol - see below */
        char    n_ovly;         /* Overlay number */
        unsigned short   n_value;        /* Symbol value */
};
struct real_nlist {
        union {
                unsigned short n_strx;   /* String table offset (file) */
        } n_un;
	unsigned short filler;
        unsigned char  n_type;         /* Type of symbol - see below */
        char    n_ovly;         /* Overlay number */
        unsigned short   n_value;        /* Symbol value */
};
#define RNL
/*
 * Simple values for n_type.
 */
#define N_UNDF  0x00            /* undefined */
#define N_ABS   0x01            /* absolute */
#define N_TEXT  0x02            /* text segment */
#define N_DATA  0x03            /* data segment */
#define N_BSS   0x04            /* bss segment */
#define N_REG   0x14            /* register symbol */
#define N_FN    0x1f            /* file name */

#define N_EXT   0x20            /* external (global) bit, OR'ed in */
#define N_TYPE  0x1f            /* mask for all the type bits */

#define N_FORMAT        "%06o"  /* namelist value format; XXX */
#endif  /* !_NLIST_H_ */
 

#endif  /* !_AOUT_H_ */


#include <stdlib.h>


#define MAXSEGNO        512     /* max number of segments in a space */
#define BYTESPERSEG     1024    /* must be power of two! */
#define LOG2BPS         10      /* log2(BYTESPERSEG) */
#define WORDSPERSEG     (BYTESPERSEG/sizeof (int))
int nmapsegs, nswaps;
struct vspace {
	int     v_fd;           /* file for swapping */
        off_t    v_foffset;       /*  offset for computing file
addresses */
        int     v_maxsegno;     /* number of segments  in  this
space */
};

struct dlink {                  /* general double link structure */
	struct dlink *fwd;      /* forward link */
        struct dlink *back;     /* back link */
};

struct     vseg  {                    /* structure of a seg‐
ment in memory */
        struct    dlink     s_link;        /* for linking  into
lru list */
        int  	   s_segno;            /* segment number */
        struct     vspace     *s_vspace;       /* which virtual
space */
        int  s_lock_count;
        int     s_flags;
        union {
        	int  _winfo[WORDSPERSEG];     /* the  actual  seg‐
ment */
        	char _cinfo[BYTESPERSEG];
	} v_un;
};
#define   s_winfo   v_un._winfo
#define   s_cinfo   v_un._cinfo

typedef long    VADDR;
#define VMMODIFY(seg) 
#define VSEG(va) ((short)(va >> LOG2BPS))
#define VOFF(va) ((u_short)va % BYTESPERSEG)

static struct vspace vspace;

static struct vseg **segment_list;
int 
vminit(int nseg)
{
	segment_list = malloc(sizeof(*segment_list)*nseg);
	memset(segment_list, 0, sizeof(*segment_list)*nseg);
	return 0;
}

int 
vmopen(struct vspace *space, char *filename)
{
	return 0;
}

void vmflush() {}
void vmclose(struct vspace *space) {}

struct vseg *vmmapseg(struct    vspace    *space, int segno)
{
	if (segment_list[segno]) 
		return segment_list[segno];

	struct vseg *seg = segment_list[segno] = malloc(sizeof(*seg));
	if (seg) {
		seg->s_segno = segno;
		seg->s_vspace = space;
		seg->s_lock_count = 0;
		seg->s_flags = 0;
	}
	return seg;
}

void vmlock(struct    vseg *seg) {}
void vmunlock(struct    vseg *seg) {}
void vmclrseg(struct    vseg *seg) {memset(&seg->s_cinfo, 0, BYTESPERSEG); }
void vmmodify(struct    vseg *seg) {}

int putw(int w, FILE *f) {
	putc(w&0xff, f);
	putc((w>>8)&0xff, f);
}

#else
#include <ranlib.h>
#include <vmf.h>
#include <a.out.h>
#include <ar.h>
#endif
#include "archive.h"

/*
 *	Layout of standard part of a.out file header:
 *		u_int	a_magic;	magic number
 *		u_int	a_text;		text size	)
 *		u_int	a_data;		data size	) in bytes but even
 *		u_int	a_bss;		bss size	)
 *		u_int	a_syms;		symbol table size
 *		u_int	a_entry;	entry point
 *		u_int	a_unused;	(unused)
 *		u_int	a_flag		bit 0 set if no relocation
 *
 *	Layout of overlaid part of a.out file header:
 *		int	max_ovl;	maximum overlay size
 *		u_int	ov_siz[NOVL];	overlay sizes
 *
 *	Non-overlaid offsets:
 *		header:		0
 *		text:		16
 *		data:		16 + a_text
 *		relocation:	16 + a_text + a_data
 *
 *		If relocation info stripped:
 *			symbol table: 16 + a_text + a_data
 *			string table: 16 + a_text + a_data + a_syms
 *		else
 *			symbol table: 16 + 2 * (a_text + a_data)
 *			string table: 16 + 2 * (a_text + a_data) + a_syms
 *
 *	Overlaid offsets:
 *		header:		0
 *		overlay header:	16
 *		text:		16 + 2 + 2*NOVL = 16 + 2 + 2*15 = 48
 *		data:		48 + a_text + SUM(ov_siz)
 *		relocation:	48 + a_text + SUM(ov_siz) + a_data
 *
 *		If relocation info stripped:
 *			symbol table: 48 + a_text + SUM(ov_siz) + a_data
 *			string table: symbol_table + a_syms
 *		else
 *		       symbol table: 48 + 2 * (a_text + SUM(ov_siz) + a_data)
 *		       string table: symbol_table + a_syms
 *
 *		where SUM(ov_siz) is the sum of the overlays.
 */

/*
 * Do not set the following too high (normally set in the Makefile) or
 * 'ld' will not be able to allocate room (currently 8kb) for string
 * tables and performance will suffer badly.  It is possible that this
 * could be raised a bit higher but 18 gives 'adequate' performance on
 * all but the largest ('tcsh' for example) programs, and even there it's
 * not _too_ bad.
*/
#ifndef	NUM_VM_PAGES
#define	NUM_VM_PAGES 18
#endif
#define	NNAMESIZE 32		/* Maximum symbol string length */
#define	SYMSPERSEG (BYTESPERSEG / sizeof (SYMBOL))

#define NSYM	2000		/* 1103 originally */
#define NROUT	350		/* 256 originally */
#define NSYMPR	800		/* 1000 originally */

#define N_COMM	05	/* internal use only; other values in a.out.h */

#define RABS	00
#define RTEXT	02
#define RDATA	04
#define RBSS	06
#define REXT	010

#define RELFLG	01

#define THUNKSIZ	8


#ifdef _VC_
/*
 *	VC reloc symbols
 *
 *      We have 5 types of relocation:
 *
 *      0000    Absolute
 *      0010    relative to the current text segment (offset stored in target)
 *      0100    relative to the current data segment (offset stored in target)
 *      0110    relative to the current bss segment (offset stored in target)
 *      1000    unknown external reference (includes a symbol offset)
 *
 *      We have 3 types of target:
 *                                      word 0          word 1
 *      A       .word   address+N       N               -
 *      B       la      address+N       lui R, N        add  R, N
 *      C       br/j/jal address+N      lui mulhi, N    b/j/jal X
 *
 *      There are 3x5=15 combinations - no obvious bit encoding so we do:
 *
 *      0000    ABS A
 *      0001    ABS B
 *      0010    TEXT A
 *      0011    TEXT B
 *      0100    DATA A
 *      0101    DATA B
 *      0110    BSS A
 *      0111    BSS B
 *      1000    EXTERN A
 *      1001    EXTERN B
 *      1010    TEXT C
 *      1011    ABS C
 *      1100    DATA C
 *      1101    EXTERN C
 *      1110    BSS C
 *      1111    -
 */

#define REL_A   0x0
#define REL_B   0x1
#define REL_C   0x2

#define IS_A(x) (((x)&0xf) <= 8 && !((x)&1))
#define IS_B(x) (((x)&0xf) <= 9 && ((x)&1))
#define IS_C(x) (((x)&0xf) > 9)

#define REL_X(x) (IS_C(x)?REL_C:IS_B(x)?REL_B:REL_A)

#define REL_ABS         0x0
#define REL_TEXT        0x1
#define REL_DATA        0x2
#define REL_BSS         0x3
#define REL_EXTERN      0x4

#define IS_ABS(x) (((x)&0xf) <= 1 || ((x)&0xf)==0xb)
#define IS_TEXT(x) (((x)&0xe) == 0x2 || ((x)&0xf)==0xa)
#define IS_DATA(x) (((x)&0xe) == 0x4 || ((x)&0xf)==0xc)
#define IS_BSS(x) (((x)&0xe) == 0x6 || ((x)&0xf)==0xe)
#define IS_EXTERN(x) (((x)&0xe) == 0x8 || ((x)&0xf)==0xd)

#define REL_TYPE(x) (IS_ABS(x)?REL_ABS:IS_TEXT(x)?REL_TEXT:IS_DATA(x)?REL_DATA:IS_BSS(x)?REL_BSS:REL_EXTERN)

#define REL_SYMBOL(x) ((x)>>4)
#define MAKE_REL(symbol, type, x) (((symbol)<<4)|((type)!=REL_C?(type)|((x)<<1):(x)==REL_ABS?0xb:(x)==REL_EXTERN?0xd:0x8|((x)<<1)))

#endif

/*
 * one entry for each archive member referenced;
 * set in first pass; needs restoring for overlays
 */
typedef struct {
	long	loc;
	} LIBLIST;

	LIBLIST	liblist[NROUT];
	LIBLIST	*libp = liblist;

	typedef struct
		{
		union	{
#ifdef RNL
			short	*iptr;
#else
			int	*iptr;
#endif
			char	*cptr;
			} ptr;
		int	bno;
		int	nibuf;
		int	nsize;
		int	nread;
		int	bsize;		/* MUST be a power of 2 */
		int	*buff;
		} STREAM;
#define	Iptr	ptr.iptr
#define	Cptr	ptr.cptr

#define	TEXT		0
#define	RELOC		1
#define	SYMBOLS		2
#define	STRINGS		3
#define	STRINGS2	4
#define	NUM_IO_PLACES	5

	STREAM	Input[NUM_IO_PLACES];

/*
 * Header from the a.out and the archive it is from (if any).
 */
	struct	xexec	filhdr;
	CHDR	chdr;

/* symbol management */
typedef struct {
	char	n_name[NNAMESIZE];
	char	n_type;
	char	n_ovly;
	u_int	n_value;
	u_int	sovalue;
	} SYMBOL;

#define	SYMTAB	((VADDR)0)	/* virtual base address of symbol table */
	u_short	symhash[(NSYM+15)/16];	/* bitmap of hash table entries */
	short	lastsym;		/* index # of last symbol entered */
	short	hshtab[NSYM+2];		/* hash table for symbols */
	short	p_etext = -1, p_edata = -1, p_end = -1, entrypt = -1;

struct	xsymbol {
	char	n_name[NNAMESIZE];
	char	n_type;
	char	n_ovly;
	u_int	n_value;
	};

	struct xsymbol	cursym;		/* current symbol */
	int	nsym;			/* pass2: number of local symbols */

struct local {
	short locindex;		/* index to symbol in file */
	short locsymbol;	/* ptr to symbol table */
	};

	struct local	local[NSYMPR];
	short	symindex;		/* next available symbol table entry */

/*
 * Options.
 */
int	trace;
int	xflag;		/* discard local symbols */
int	Xflag;		/* discard locals starting with 'L' */
int	Sflag;		/* discard all except locals and globals*/
int	rflag;		/* preserve relocation bits, don't define common */
int	arflag;		/* original copy of rflag */
int	sflag;		/* discard all symbols */
int	Mflag;		/* print rudimentary load map */
int	nflag;		/* pure procedure */
int	Oflag;		/* set magic # to 0405 (overlay) */
int	dflag;		/* define common even with rflag */
int	iflag;		/* I/D space separated */

/*
 * These are the cumulative sizes, set in pass1, which
 * appear in the a.out header when the loader is finished.
 */
	u_int	tsize, dsize, bsize;
	long	ssize, rnd8k();

/*
 * Symbol relocation:
 */
	u_int	ctrel, cdrel, cbrel;

/*
 * The base addresses for the loaded text, data and bass from the
 * current module during pass2 are given by torigin, dorigin and borigin.
 */
	u_int	torigin, dorigin, borigin;

/*
 * Errlev is nonzero when errors have occured.
 * Delarg is an implicit argument to the routine delexit
 * which is called on error.  We do ``delarg = errlev'' before normal
 * exits, and only if delarg is 0 (i.e. errlev was 0) do we make the
 * result file executable.
 */
	int	errlev, delarg	= 4;

	int	ofilfnd;	/* -o given; otherwise move l.out to a.out */
	char	*ofilename = "l.out";
	int	infil;			/* current input file descriptor */
	char	*filname;		/* and its name */
	/*char	tfname[] = "/tmp/ldaXXXXX";*/
	char	*tfname;

	FILE	*toutb, *doutb, *troutb, *droutb, *soutb, *voutb;

	u_int	torgwas;		/* Saves torigin while doing overlays */
	u_int	tsizwas;		/* Saves tsize while doing overlays */
	int	numov;			/* Total number of overlays */
	int	curov;			/* Overlay being worked on just now */
	int	inov;			/* 1 if working on an overlay */

/* Kernel overlays have a special subroutine to do the switch */

struct	xsymbol ovhndlr =
	{ "ovhndlr1", N_EXT+N_UNDF, 0, 0 };
#define HNDLR_NUM 7		/* position of ov number in ovhndlr.n_name[] */
u_int	ovbase;			/* The base address of the overlays */

#define	NDIRS	25
#define NDEFDIRS 3		/* number of default directories in dirs[] */
	char	*dirs[NDIRS];		/* directories for library search */
	int	ndir;			/* number of directories */

	struct	vspace	Vspace;	/* The virtual address space for symbols */

	short	*lookup(), *slookup(), *lookloc();
	char	*rstrtab;	/* ranlib string table pointer */
	u_int	add();
	void	delexit(int a);
	VADDR	sym2va();
	off_t	skip();
extern	long	lseek(), atol(), strtol();
extern	char	*mktemp();
extern char *tempnam(const char *dir, const char *pfx);

main(argc, argv)
char **argv;
{
	register int c, i;
	int num;
	register char *ap, **p;
	char save;

/*
 * Initialize the hash table, indicating that all entries are unused.
 * -1 is used as a "no symbol" flag.
*/
	memset(hshtab, -1, sizeof(hshtab));

/*
 * Initialize the first three input buffers.  The remaining two are
 * left for later because it may be possible to hold the string table
 * in memory and the input buffer won't be needed.
*/
	Input[TEXT].buff = (int *)malloc(512);
	Input[TEXT].bsize = 512;
	Input[RELOC].buff = (int *)malloc(512);
	Input[RELOC].bsize = 512;
	Input[SYMBOLS].buff = (int *)malloc(512);
	Input[SYMBOLS].bsize = 512;

	if (signal(SIGINT, SIG_IGN) != SIG_IGN) {
		signal(SIGINT, delexit);
		signal(SIGTERM, delexit);
	}
	if (argc == 1)
		exit(4);
/*
 * Initialize the "VM" system with NUM_VM_PAGES memory segments (memory 
 * resident pages).  Then "open the address space" - this creates the paging
 * (tmp) file.
*/
	if	(vminit(NUM_VM_PAGES) < 0)
		error(1, "vminit failed");
	if	(vmopen(&Vspace, (char *)NULL) < 0)
		error(1, "vmopen failed");

	/* 
	 * Pull out search directories.
	 */
	for (c = 1; c < argc; c++) {
		ap = argv[c];
		if (ap[0] == '-' && ap[1] == 'L') {
			if (ap[2] == 0)
				error(1, "-L: pathname missing");
			if (ndir >= NDIRS - NDEFDIRS)
				error(1, "-L: too many directories");
			dirs[ndir++] = &ap[2];
		}
	}
	/* add default search directories */
	dirs[ndir++] = "/lib";
	dirs[ndir++] = "/usr/lib";
	dirs[ndir++] = "/usr/local/lib";

	p = argv+1;
	/*
	 * Scan files once to find where symbols are defined.
	 */
	for (c=1; c<argc; c++) {
		if (trace)
			printf("%s:\n", *p);
		filname = 0;
		ap = *p++;
		if (*ap != '-') {
			load1arg(ap, 1);
			continue;
		}
		for (i=1; ap[i]; i++) switch (ap[i]) {

		case 'o':
			if (++c >= argc)
				error(1, "-o where?");
			ofilename = *p++;
			ofilfnd++;
			continue;
		case 'u':
		case 'e':
			if (++c >= argc)
				error(1, "-u or -c: arg missing");
			enter(slookup(*p++));
			if (ap[i]=='e')
				entrypt = lastsym;
			continue;
		case 'D':
			if (++c >= argc)
				error(1, "-D: arg missing");
			num = atoi(*p++);
			if (dsize>num)
				error(1, "-D: too small");
			dsize = num;
			continue;
		case 'l':
			save = ap[--i];
			ap[i]='-';
			load1arg(&ap[i], -1);
			ap[i]=save;
			goto next;
		case 'M':
			Mflag++;
			continue;
		case 'x':
			xflag++;
			continue;
		case 'X':
			Xflag++;
			continue;
		case 'S':
			Sflag++;
			continue;
		case 'r':
			rflag++;
			arflag++;
			continue;
		case 's':
			sflag++;
			xflag++;
			continue;
		case 'n':
			nflag++;
			continue;
		case 'd':
			dflag++;
			continue;
		case 'i':
		case 'z':
			iflag++;
			continue;
		case 't':
			trace++;
			continue;
		case 'L':
			goto next;
		case 'O':
			Oflag++;
			continue;
		case 'Y':
			if (inov == 0)
				error(1, "-Y: Not in overlay");
			filhdr.o.ov_siz[curov - 1] = tsize;
			if (trace)
				printf("overlay %d size %d\n", curov,
					filhdr.o.ov_siz[curov - 1]);
			curov = inov = 0;
			tsize = tsizwas;
			continue;
		case 'Z':
			if (!inov) {
				tsizwas = tsize;
				if (numov == 0) {
					cursym = ovhndlr;
					enter(lookup());
				}
			}
			else {
				filhdr.o.ov_siz[curov - 1] = tsize;
				if (trace)
					printf("overlay %d size %d\n", curov,
						filhdr.o.ov_siz[curov - 1]);
			}
			tsize = 0;
			inov = 1;
			numov++;
			if (numov > NOVL) {
				printf("ld:too many overlays, max is %d\n",NOVL);
				error(1, (char *)NULL);
			}
			curov++;
			continue;
		case 'v':
		case 'y':
		case 'A':
		case 'H':
		case 'N':
		case 'T':
		default:
			printf("ld:bad flag %c\n",ap[i]);
			error(1, (char *)NULL);
		}
next:
		;
	}
	endload(argc, argv);
	exit(0);
}

void delexit(a)
int a;
	{

	unlink("l.out");
	if (delarg==0)
		chmod(ofilename, 0777 & ~umask(0));
	printf("ld: nswaps: %ld, nmapsegs: %ld sbrk(0): %u\n", (long)nswaps, 
		(long)nmapsegs, sbrk(0));
	exit(delarg);
	}

endload(argc, argv)
	int argc;
	char **argv;
{
	register int c, i;
	int dnum;
	register char *ap, **p;

	if (numov)
		rflag = 0;
	filname = 0;
	middle();
	setupout();
	p = argv+1;
	libp = liblist;
	for (c=1; c<argc; c++) {
		ap = *p++;
		if (trace)
			printf("%s:\n", ap);
		if (*ap != '-') {
			load2arg(ap, 1);
			continue;
		}
		for (i=1; ap[i]; i++) switch (ap[i]) {

		case 'D':
			for (dnum = atoi(*p);dorigin < dnum; dorigin += 2) {
				putw(0, doutb);
				if (rflag)
					putw(0, droutb);
			}
			/* fall into ... */
		case 'u':
		case 'e':
		case 'o':
			++c;
			++p;
			/* fall into ... */
		default:
			continue;
		case 'L':
			goto next;
		case 'l':
			ap[--i]='-';
			load2arg(&ap[i], -1);
			goto next;
		case 'Y':
			roundov();
			inov = 0;
			if (trace)
				printf("end overlay generation\n");
			torigin = torgwas;
			continue;
		case 'Z':
			if (inov == 0)
				torgwas = torigin;
			else
				roundov();
			torigin = ovbase;
			inov = 1;
			curov++;
			continue;
		}
next:
		;
	}
	finishout();
}

/*
 * Compute a symbol's virtual address from its index number.  The code is
 * a bit ugly (and made a routine rather than a macro) because the page
 * size does not divide evenly by the size of a symbol.
*/

VADDR
sym2va(x)
	u_short	x;
	{
	register u_short i, j;

	i = (x % SYMSPERSEG) * sizeof (SYMBOL);
	j = x / SYMSPERSEG;
	return(SYMTAB+ i + ((long)j << LOG2BPS));
	}

/*
 * Scan file to find defined symbols.
 */
load1arg(cp, flag)
	register char *cp;
	int flag;
	{
	off_t nloc;
	int kind, tnum;
	long	ltnum;
	u_long strsize;

	kind = getfile(cp, flag, 1);
	if (Mflag)
		printf("%s\n", filname);
	switch (kind) {

	/*
	 * Plain file.
	 */
	case 0:
		load1(0, 0L);
		break;

	/*
	 * Archive without table of contents.
	 * (Slowly) process each member.
	 */
	case 1:
		error(-1,
"warning: archive has no table of contents; add one using ranlib(1)");
		nloc = SARMAG;
		while (step(nloc))
			nloc += skip();
		break;

	/*
	 * Archive with table of contents.
	 * Read the table of contents and its associated string table.
	 * Pass through the library resolving symbols until nothing changes
	 * for an entire pass (i.e. you can get away with backward references
	 * when there is a table of contents!)
	 */
	case 2:
		nloc = SARMAG + sizeof (struct ar_hdr) + chdr.lname;
		lseek(infil, nloc, L_SET);
/*
 * Read the size of the ranlib structures (a long).
*/
		read(infil, &ltnum, sizeof (ltnum));
/*
 * calculate string table position.  Add in the ranlib size (4 bytes),
 * the size of the ranlib structures (ltnum) from above.
*/
		nloc += (sizeof (ltnum) + ltnum);
		tnum = ltnum / sizeof (struct ranlib);

		rstrtab = NULL;
		lseek(infil, nloc, L_SET);
		read(infil, &strsize, sizeof (u_long));
		if	(strsize <= 8192L)
			{
			rstrtab = (char *)malloc((int)strsize);
			if	(rstrtab)
				read(infil, rstrtab, (int)strsize);
			}
		if	(!rstrtab)
			inistr(STRINGS2);

		while (ldrand(tnum, nloc))
			;
		libp->loc = -1;
		libp++;

		if	(rstrtab)
			free(rstrtab);
		if	(Input[STRINGS2].buff)
			{
			free(Input[STRINGS2].buff);
			Input[STRINGS2].buff = NULL;
			}
		break;

	/*
	 * Table of contents is out of date, so search
	 * as a normal library (but skip the __.SYMDEF file).
	 */
	case 3:
		error(-1,
"warning: table of contents for archive is out of date; rerun ranlib(1)");
		nloc = SARMAG;
		do
			nloc += skip();
		while (step(nloc));
		break;
	case -1:
		return;
	}
	close(infil);
}

/*
 * Advance to the next archive member, which
 * is at offset nloc in the archive.  If the member
 * is useful, record its location in the liblist structure
 * for use in pass2.  Mark the end of the archive in libilst with a -1.
 */
step(nloc)
	off_t nloc;
	{

	lseek(infil, nloc, L_SET);
	if	(get_arobj(infil) <= 0)
		{
		libp->loc = -1;
		libp++;
		return (0);
		}
	if	(load1(1, nloc + sizeof (struct ar_hdr) + chdr.lname))
		{
		libp->loc = nloc;
		libp++;
		if	(Mflag)
			printf("\t%s\n", chdr.name);
		}
	return (1);
	}

ldrand(totnum, sloc)
	int	totnum;
	off_t	sloc;
	{
	register int ntab;
	SYMBOL	*sp;
	short	*hp;
	VADDR	vsym;
	LIBLIST *oldp = libp;
	int amt, tnum = totnum;
	off_t	loc;
/*
 * 'ar' header + member header + SYMDEF table.of.contents + long filename
*/
	off_t	opos = (off_t)SARMAG + sizeof (struct ar_hdr) + sizeof (long) +
			chdr.lname;
#define TABSZ 64
	char	localname[NNAMESIZE];
	register struct ranlib *tp;
	struct ranlib tab[TABSZ], *tplast;

	while	(tnum)
		{
		if	(tnum > TABSZ)
			ntab = TABSZ;
		else
			ntab = tnum;
		tplast = &tab[ntab - 1];
		(void)lseek(infil, opos, L_SET);
		amt = ntab * sizeof (struct ranlib);
		if	(read(infil, tab, amt) != amt)
			error(1, "EOF in ldrand");
		tnum -= ntab;
		opos += amt;

		for	(tp = tab; tp <= tplast; tp++)
			{
/*
 * This is slower and uglier than we would like, but it is not always
 * possible to hold the entire string table in memory.  Need to add
 * an extra increment to skip over the string table size longword.
*/
			if	(rstrtab)
				strncpy(localname, (int)tp->ran_un.ran_strx +
						rstrtab, NNAMESIZE);
			else
				{
				dseek(STRINGS2, tp->ran_un.ran_strx + sloc +
					sizeof (u_long), 07777);
				mgets(localname, NNAMESIZE, STRINGS2);
				}
			hp = slookup(localname);
			if 	(*hp == -1)
				continue;
			vsym = sym2va(*hp);
			sp = (SYMBOL *)(vmmapseg(&Vspace, VSEG(vsym))->s_cinfo +
					VOFF(vsym));
			if	(sp->n_type != N_EXT+N_UNDF)
				continue;
			step(tp->ran_off);
			loc = tp->ran_off;
			while	(tp < tplast && (tp+1)->ran_off == loc)
				tp++;
			}
		}
	return(oldp != libp);
	}

mgets(buf, maxlen, which)
	register char *buf;
	int	maxlen, which;
	{
	register STREAM *sp;
	register int n;

	sp = &Input[which];
	for	(n = 0; n < maxlen; n++)
		{
		if	(--sp->nibuf < 0)
			{
			dseek(which, (off_t)(sp->bno + 1) * sp->bsize, 077777);
			sp->nibuf--;
			}
		if	((*buf++ = *sp->Cptr++) == 0)
			break;
		}
	}

/*
 * Examine a single file or archive member on pass 1.
 */
load1(libflg, loc)
	off_t loc;
{
	register SYMBOL *sp;
	int savindex;
	int ndef, type, mtype;
	long nlocal;
	VADDR	vsym;
	struct	nlist objsym;
	off_t	strloc;
	u_long	strsize;
	char	*strtab;
register struct vseg *seg;

	readhdr(loc);
	if (filhdr.e.a_syms == 0) {
		if (filhdr.e.a_text+filhdr.e.a_data == 0)
			return (0);
		error(1, "no namelist");
	}
	ctrel = tsize; cdrel += dsize; cbrel += bsize;
	ndef = 0;
	nlocal = sizeof (cursym);
	savindex = symindex;
	bzero(symhash, sizeof (symhash));
	if ((filhdr.e.a_flag&RELFLG)==1) {
		error(1, "No relocation bits");
		return(0);
	}
	dseek(SYMBOLS, loc + N_SYMOFF(filhdr), filhdr.e.a_syms);

	strloc = loc + N_STROFF(filhdr);
	lseek(infil, strloc, L_SET);
	read(infil, &strsize, sizeof (u_long));
	strtab = NULL;
	if	(strsize <= 8192L)
		{
		strtab = (char *)malloc((int)strsize);
		if	(strtab)
			read(infil, strtab, (int)strsize);
		}
	if	(!strtab)
		inistr(STRINGS);

	while (Input[SYMBOLS].nsize > 0) {
#ifdef RNL
		{
			struct real_nlist oo;
			mget((int *)&oo, sizeof oo, SYMBOLS);
			objsym.n_un.n_strx = oo.n_un.n_strx;
			objsym.n_type = oo.n_type;
			objsym.n_ovly = oo.n_ovly;
			objsym.n_value = oo.n_value;
		}
#else
		mget((int *)&objsym, sizeof objsym, SYMBOLS);
#endif
		type = objsym.n_type;
		if (Sflag) {
			mtype = type&037;
			if (mtype==1 || mtype>4) {
				continue;
			}
		}
/*
 * Now convert 'nlist' format symbol to 'fixed' (semi old style) format.
 * This may look strange but it greatly simplifies things and avoids having
 * to read the entire string table into virtual memory.
 *
 * Also, we access the symbols in order.  The assembler was nice enough
 * to place the strings in the same order as the symbols - so effectively
 * we are doing a sequential read of the string table.
*/
		if	(strtab)
			strncpy(cursym.n_name, (int)objsym.n_un.n_strx + 
				strtab - sizeof (u_long), NNAMESIZE);
		else
			{
			dseek(STRINGS, objsym.n_un.n_strx + strloc, 077777);
			mgets(cursym.n_name, NNAMESIZE, STRINGS);
			}
		cursym.n_type = objsym.n_type;
		cursym.n_value = objsym.n_value;
		cursym.n_ovly = objsym.n_ovly;
		if ((type&N_EXT)==0) {
			if (Xflag==0 || cursym.n_name[0]!='L')
				nlocal += sizeof (cursym);
			continue;
		}

		switch (cursym.n_type) {
		case N_TEXT:
		case N_EXT+N_TEXT:
			cursym.n_value += ctrel;
			break;
		case N_DATA:
		case N_EXT+N_DATA:
			cursym.n_value += cdrel;
			break;
		case N_BSS:
		case N_EXT+N_BSS:
			cursym.n_value += cbrel;
			break;
		case N_EXT+N_UNDF:
			break;
		default:
			if (cursym.n_type&N_EXT)
				cursym.n_type = N_EXT+N_ABS;
			break;
		}

		if (enter(lookup()))
			continue;
		vsym = sym2va(lastsym);
		seg = vmmapseg(&Vspace, VSEG(vsym));
		sp = (SYMBOL *)(seg->s_cinfo + VOFF(vsym));
		if (sp->n_type != N_EXT+N_UNDF)
			continue;
		if (cursym.n_type == N_EXT+N_UNDF) {
			if (cursym.n_value > sp->n_value) {
				sp->n_value = cursym.n_value;
				vmmodify(seg);
			}
			continue;
		}
		if (sp->n_value != 0 && cursym.n_type == N_EXT+N_TEXT)
			continue;
		ndef++;
		sp->n_type = cursym.n_type;
		sp->n_value = cursym.n_value;
		sp->n_ovly = ((sp->n_type &~ N_EXT) == N_TEXT) ? curov : 0;
		VMMODIFY(seg);
		if (trace)
			printf("%.*s type 0%o in overlay %u at %u\n", NNAMESIZE,
			    sp->n_name, sp->n_type, sp->n_ovly, sp->n_value);
	}

	if	(strtab)
		free(strtab);
	if	(Input[STRINGS].buff)
		{
		free(Input[STRINGS].buff);
		Input[STRINGS].buff = NULL;
		}

	if (libflg==0 || ndef) {
		tsize = add(tsize,filhdr.e.a_text,"text overflow");
		dsize = add(dsize,filhdr.e.a_data,"data overflow");
		bsize = add(bsize,filhdr.e.a_bss,"bss overflow");
		ssize += nlocal;
		return (1);
	}
	/*
	 * No symbols defined by this library member.
	 * Rip out the hash table entries and reset the symbol table.
	 */
	hreset();
	symindex = savindex;
	return(0);
}

static
hreset()
	{
	register u_short *sp, i;
	u_short j;
	register u_short mask;

	sp = symhash;
	for	(i = 0; i < NSYM; sp++, i += 16)
		{
		if	(*sp == 0)
			continue;
		for	(mask = 1, j = i; *sp; j++)
			{
			if	(*sp & mask)
				{
				hshtab[j] = -1;
				*sp &= ~mask;
				}
			mask <<= 1;
			}
		}
	}

middle()
{
	VADDR	vsym;
	register SYMBOL *sp;
	register int	i;
	register struct	vseg *seg;
	u_int csize;
	u_int nund, corigin;
	u_int ttsize;

	torigin = 0;
	dorigin = 0;
	borigin = 0;

	p_etext = *slookup("_etext");
	p_edata = *slookup("_edata");
	p_end = *slookup("_end");
	/*
	 * If there are any undefined symbols, save the relocation bits.
	 * (Unless we are overlaying.)
	 */
	if (rflag==0 && !numov) {
		for (i=0, vsym=sym2va(0); i < symindex; i++, vsym=sym2va(i)) {
			sp = (SYMBOL *)(vmmapseg(&Vspace,VSEG(vsym))->s_cinfo +
					VOFF(vsym));
			if (sp->n_type==N_EXT+N_UNDF && sp->n_value==0
				&& i != p_end && i != p_edata && i != p_etext) {
				rflag++;
				dflag = 0;
				break;
			}
		}
	}
	if (rflag)
		nflag = sflag = iflag = Oflag = 0;
	/*
	 * Assign common locations.
	 */
	csize = 0;
	if (dflag || rflag==0) {
		ldrsym(p_etext, tsize, N_EXT+N_TEXT);
		ldrsym(p_edata, dsize, N_EXT+N_DATA);
		ldrsym(p_end, bsize, N_EXT+N_BSS);
		for (i=0, vsym=sym2va(0); i < symindex; i++, vsym=sym2va(i)) {
			register int t;

			seg = vmmapseg(&Vspace, VSEG(vsym));
			sp = (SYMBOL *)(seg->s_cinfo + VOFF(vsym));
			if (sp->n_type==N_EXT+N_UNDF && (t = sp->n_value)!=0) {
				t = (t+1) & ~01;
				sp->n_value = csize;
				sp->n_type = N_EXT+N_COMM;
				VMMODIFY(seg);
				csize = add(csize, t, "bss overflow");
			}
		}
	}
	if (numov) {
		for (i=0, vsym=sym2va(0); i < symindex; i++, vsym=sym2va(i)) {
			seg = vmmapseg(&Vspace, VSEG(vsym));
			sp = (SYMBOL *)(seg->s_cinfo + VOFF(vsym));
			if (trace)
				printf("%.*s n_type %o n_value %o sovalue %o ovly %d\n",
					NNAMESIZE, sp->n_name, sp->n_type,
					sp->n_value, sp->sovalue, sp->n_ovly);
			if (sp->n_ovly && sp->n_type == N_EXT+N_TEXT) {
				sp->sovalue = sp->n_value;
				sp->n_value = tsize;
				VMMODIFY(seg);
				tsize += THUNKSIZ;
				if (trace)
					printf("relocating %.*s in overlay %d from %o to %o\n",
						NNAMESIZE,sp->n_name,sp->n_ovly,
						sp->sovalue, sp->n_value);
			}
		}
	}
	/*
	 * Now set symbols to their final value
	 */
	if (nflag || iflag)
		tsize = (tsize + 077) & ~077;
	ttsize = tsize;
	if (numov) {
		register int i;

		ovbase = (u_int)rnd8k(tsize);
		if (trace)
			printf("overlay base is %u.\n", ovbase);
		for (i=0, vsym=sym2va(0); i < symindex; i++, vsym=sym2va(i)) {
			seg = vmmapseg(&Vspace, VSEG(vsym));
			sp = (SYMBOL *)(seg->s_cinfo + VOFF(vsym));
			if (sp->n_ovly && sp->n_type == N_EXT+N_TEXT) {
				sp->sovalue += ovbase;
				VMMODIFY(seg);
				if (trace)
					printf("%.*s at %u overlay %d\n",
						NNAMESIZE, sp->n_name,
						sp->sovalue, sp->n_ovly);
			}
		}
		for (i = 0; i < NOVL; i++) {
			filhdr.o.ov_siz[i] = (filhdr.o.ov_siz[i] + 077) &~ 077;
			if (filhdr.o.ov_siz[i] > filhdr.o.max_ovl)
				filhdr.o.max_ovl = filhdr.o.ov_siz[i];
		}
		if (trace)
			printf("max overlay size is %u\n", filhdr.o.max_ovl);
		ttsize = (u_int)rnd8k(ovbase + filhdr.o.max_ovl);
		if (trace)
			printf("overlays end before %u.\n", ttsize);
	}
	dorigin = ttsize;
	if (nflag)
		dorigin = (u_int)rnd8k(ttsize);
	if (iflag)
		dorigin = 0;
	corigin = dorigin + dsize;
	borigin = corigin + csize;
	nund = 0;
	for (i=0, vsym=sym2va(0); i < symindex; i++, vsym=sym2va(i)) {
		seg = vmmapseg(&Vspace, VSEG(vsym));
		sp = (SYMBOL *)(seg->s_cinfo + VOFF(vsym));

		switch (sp->n_type) {

		case N_EXT+N_UNDF:
			if (arflag == 0)
				errlev |= 01;
			if ((arflag==0 || dflag) && sp->n_value==0) {
				if (i == p_end || i == p_etext || i == p_edata)
					continue;
				if (nund==0)
					printf("Undefined:\n");
				nund++;
				printf("%.*s\n", NNAMESIZE, sp->n_name);
			}
			continue;
		case N_EXT+N_ABS:
		default:
			continue;
		case N_EXT+N_TEXT:
			sp->n_value += torigin;
			VMMODIFY(seg);
			continue;
		case N_EXT+N_DATA:
			sp->n_value += dorigin;
			VMMODIFY(seg);
			continue;
		case N_EXT+N_BSS:
			sp->n_value += borigin;
			VMMODIFY(seg);
			continue;
		case N_EXT+N_COMM:
			sp->n_type = N_EXT+N_BSS;
			sp->n_value += corigin;
			VMMODIFY(seg);
			continue;
		}
	}
	if (sflag || xflag)
		ssize = 0;
	bsize = add(bsize, csize, "bss overflow");
	nsym = ssize / (sizeof cursym);
}

ldrsym(ix, val, type)
	short	ix;
	u_int	val;
	int	type;
{
	VADDR	vsym;
	register struct vseg *seg;
	register SYMBOL *sp;

	if (ix == -1)
		return;
	vsym = sym2va(ix);
	seg = vmmapseg(&Vspace, VSEG(vsym));
	sp = (SYMBOL *)(seg->s_cinfo + VOFF(vsym));
	if (sp->n_type != N_EXT+N_UNDF || sp->n_value) {
		printf("%.*s: n_value %o", NNAMESIZE, sp->n_name, sp->n_value);
		error(0, "attempt to redefine loader-defined symbol");
		return;
	}
	sp->n_type = type;
	sp->n_value = val;
	VMMODIFY(seg);
}

setupout()
{
	VADDR	vsym;
	register SYMBOL *sp;
	char *tmp;

	tcreat(&toutb, 0);
	/* mktemp(tfname); */
	tfname = tempnam("/tmp/", "ld");
	tcreat(&doutb, 1);
	if (sflag==0 || xflag==0)
		tcreat(&soutb, 1);
	if (rflag) {
		tcreat(&troutb, 1);
		tcreat(&droutb, 1);
	}
	if (numov)
		tcreat(&voutb, 1);
	filhdr.e.a_magic = (Oflag ? A_MAGIC4 : (iflag ? A_MAGIC3 : (nflag ? A_MAGIC2 : A_MAGIC1)));
	if (numov) {
		if (filhdr.e.a_magic == A_MAGIC1)
			error(1, "-n or -i must be used with overlays");
		filhdr.e.a_magic |= 020;
	}
	filhdr.e.a_text = tsize;
	filhdr.e.a_data = dsize;
	filhdr.e.a_bss = bsize;
#ifdef RNL
	ssize = sflag? 0 : (ssize + (sizeof (struct real_nlist)) * symindex);
#else
	ssize = sflag? 0 : (ssize + (sizeof (struct nlist)) * symindex);
#endif
/*
 * This is an estimate, the real size is computed later and the
 * a.out header rewritten with the correct value.
*/
	filhdr.e.a_syms = ssize&0177777;
	if (entrypt != -1) {
		vsym = sym2va(entrypt);
		sp = (SYMBOL *)(vmmapseg(&Vspace,VSEG(vsym))->s_cinfo +
				VOFF(vsym));
		if (sp->n_type!=N_EXT+N_TEXT)
			error(0, "entry point not in text");
		else if (sp->n_ovly)
			error(0, "entry point in overlay");
		else
			filhdr.e.a_entry = sp->n_value | 01;
	} else
		filhdr.e.a_entry = 0;
	filhdr.e.a_flag = (rflag==0);
	fwrite(&filhdr.e, sizeof (filhdr.e), 1, toutb);
	if (numov)
		fwrite(&filhdr.o, sizeof (filhdr.o), 1, toutb);
}

load2arg(acp, flag)
	char *acp;
	int flag;
{
	register char *cp;
	register LIBLIST *lp;

	cp = acp;
	switch	(getfile(cp, flag, 2))
		{
		case 0:
			while (*cp)
				cp++;
			while (cp >= acp && *--cp != '/')
				;
			mkfsym(++cp);
			load2(0L);
			break;
		case -1:
			return;
		default:	/* scan archive members referenced */
			for (lp = libp; lp->loc != -1; lp++) {
				lseek(infil, lp->loc, L_SET);
				get_arobj(infil);
				mkfsym(chdr.name);
				load2(lp->loc + sizeof (struct ar_hdr) + 
					chdr.lname);
			}
			libp = ++lp;
			break;
		}
	close(infil);
}

load2(loc)
long loc;
{
	register SYMBOL *sp;
	register struct local *lp;
	register int symno;
	int type, mtype;
	VADDR	vsym;
	short	i;
	struct	nlist objsym;
	off_t	stroff;
	char	*strtab;
	u_long	strsize;

	readhdr(loc);
	ctrel = torigin;
	cdrel += dorigin;
	cbrel += borigin;
	/*
	 * Reread the symbol table, recording the numbering
	 * of symbols for fixing external references.
	 */
	lp = local;
	symno = -1;
	dseek(SYMBOLS, loc + N_SYMOFF(filhdr), filhdr.e.a_syms);
	stroff = loc + N_STROFF(filhdr);

	lseek(infil, stroff, L_SET);
	read(infil, &strsize, sizeof (u_long));
	strtab = NULL;
	if	(strsize <= 8192L)
		{
		strtab = (char *)malloc((int)strsize);
		if	(strtab)
			read(infil, strtab, (int)strsize);
		}
	if	(!strtab)
		inistr(STRINGS);

	while (Input[SYMBOLS].nsize > 0) {
		symno++;
#ifdef RNL
		{
			struct real_nlist oo;
			mget((int *)&oo, sizeof oo, SYMBOLS);
			objsym.n_un.n_strx = oo.n_un.n_strx;
			objsym.n_type = oo.n_type;
			objsym.n_ovly = oo.n_ovly;
			objsym.n_value = oo.n_value;
		}
#else
		mget((int *)&objsym, sizeof objsym, SYMBOLS);
#endif
		if	(strtab)
			strncpy(cursym.n_name, (int)objsym.n_un.n_strx +
				strtab - sizeof (u_long), NNAMESIZE);
		else
			{
			dseek(STRINGS, objsym.n_un.n_strx + stroff, 07777);
			mgets(cursym.n_name, NNAMESIZE, STRINGS);
			}
		cursym.n_type = objsym.n_type;
		cursym.n_value = objsym.n_value;
		cursym.n_ovly = objsym.n_ovly;

		switch (cursym.n_type) {
		case N_TEXT:
		case N_EXT+N_TEXT:
			cursym.n_value += ctrel;
			break;
		case N_DATA:
		case N_EXT+N_DATA:
			cursym.n_value += cdrel;
			break;
		case N_BSS:
		case N_EXT+N_BSS:
			cursym.n_value += cbrel;
			break;
		case N_EXT+N_UNDF:
			break;
		default:
			if (cursym.n_type&N_EXT)
				cursym.n_type = N_EXT+N_ABS;
			break;
		}

		type = cursym.n_type;
		if (Sflag) {
			mtype = type&037;
			if (mtype==1 || mtype>4) continue;
		}
		if ((type&N_EXT) == 0) {
			if (!sflag && !xflag &&
			    (!Xflag || cursym.n_name[0] != 'L')) {
				/*
				 * preserve overlay number for locals
				 * mostly for adb.   mjk 7/81
				 */
				if ((type == N_TEXT) && inov)
					cursym.n_ovly = curov;
				fwrite(&cursym, sizeof cursym, 1, soutb);
			}
			continue;
		}
		i = *lookup();
		if (i == -1)
			error(1, "internal error: symbol not found");
		if (cursym.n_type == N_EXT+N_UNDF ||
		    cursym.n_type == N_EXT+N_TEXT) {
			if (lp >= &local[NSYMPR])
				error(2, "Local symbol overflow");
			lp->locindex = symno;
			lp++->locsymbol = i;
			continue;
		}
		vsym = sym2va(i);
		sp = (SYMBOL *)(vmmapseg(&Vspace,VSEG(vsym))->s_cinfo +
				VOFF(vsym));
		if (cursym.n_type != sp->n_type
		    || cursym.n_value != sp->n_value && !sp->n_ovly
		    || sp->n_ovly && cursym.n_value != sp->sovalue) {
			printf("%.*s: ", NNAMESIZE, cursym.n_name);
			if (trace)
				printf(" ovly %d sovalue %o new %o hav %o ",
					sp->n_ovly, sp->sovalue,
					cursym.n_value, sp->n_value);
			error(0, "multiply defined");
		}
	}
	if	(strtab)
		free(strtab);
	if	(Input[STRINGS].buff)
		{
		free(Input[STRINGS].buff);
		Input[STRINGS].buff = NULL;
		}
	dseek(TEXT, loc + N_TXTOFF(filhdr.e), filhdr.e.a_text);
	dseek(RELOC, loc + N_TRELOC(filhdr.e), filhdr.e.a_text);
	load2td(lp, ctrel, inov ? voutb : toutb, troutb);
	dseek(TEXT, loc + N_DATOFF(filhdr), filhdr.e.a_data);
	dseek(RELOC, loc + N_DRELOC(filhdr), filhdr.e.a_data);
	load2td(lp, cdrel, doutb, droutb);
	torigin += filhdr.e.a_text;
	dorigin += filhdr.e.a_data;
	borigin += filhdr.e.a_bss;
}

load2td(lp, creloc, b1, b2)
	struct local *lp;
	u_int creloc;
	FILE *b1, *b2;
{
	register u_int r, t;
	register SYMBOL *sp;
	short	i;
	VADDR	vsym;
#ifdef _VC_
	int off=0;
#endif

	for (;;) {
/*
 * Can't do this because of the word/byte count fakery that's used to
 * prevrent erroneous EOF indications.  Yuck.

		t = get(TEXT);
		t = get(RELOC);
*/
		/*
		 * The pickup code is copied from "get" for speed.
		 */

		/* next text or data word */
		if (--Input[TEXT].nsize <= 0) {
			if (Input[TEXT].nsize < 0)
				break;
			Input[TEXT].nsize++;
			t = get(TEXT);
		} else if (--Input[TEXT].nibuf < 0) {
			Input[TEXT].nibuf++;
			Input[TEXT].nsize++;
			t = get(TEXT);
		} else
			t = *Input[TEXT].Iptr++;

		/* next relocation word */
		if (--Input[RELOC].nsize <= 0) {
			if (Input[RELOC].nsize < 0)
				error(1, "relocation error");
			Input[RELOC].nsize++;
			r = get(RELOC);
		} else if (--Input[RELOC].nibuf < 0) {
			Input[RELOC].nibuf++;
			Input[RELOC].nsize++;
			r = get(RELOC);
		} else
			r = *Input[RELOC].Iptr++;
#ifdef _VC_
		if (r) 
		if (IS_A(r)) {
			switch (REL_TYPE(r)) {
			case REL_ABS:
				break;
			case REL_TEXT:
				t += ctrel;
				break;
			case REL_DATA:
				t += cdrel;
				break;
			case REL_BSS:
				t += cbrel;
				break;
			case REL_EXTERN:
				i = *lookloc(lp, r);
				vsym = sym2va(i);
				sp = (SYMBOL *)(vmmapseg(&Vspace, VSEG(vsym))->s_cinfo +
						VOFF(vsym));
				if (sp->n_type==N_EXT+N_UNDF) {
					r = (r&01) + ((nsym + i)<<4) + REXT;
					break;
				}
				t += sp->n_value;
				r = (r&01) + ((sp->n_type-(N_EXT+N_ABS))<<1);
				break;
			default:
				if (r != 0) {
					error(1, "relocation format botch (symbol type))");
				}
			}
		} else {
			u_int r2, t1, t2, tmp;
			int w, pc;

			/* next text or data word */
			if (--Input[TEXT].nsize <= 0) {
				if (Input[TEXT].nsize < 0)
					break;
				Input[TEXT].nsize++;
				t2 = get(TEXT);
			} else if (--Input[TEXT].nibuf < 0) {
				Input[TEXT].nibuf++;
				Input[TEXT].nsize++;
				t2 = get(TEXT);
			} else
				t2 = *Input[TEXT].Iptr++;
	
			/* next relocation word */
			if (--Input[RELOC].nsize <= 0) {
				if (Input[RELOC].nsize < 0)
					error(1, "relocation error");
				Input[RELOC].nsize++;
				r2 = get(RELOC);
			} else if (--Input[RELOC].nibuf < 0) {
				Input[RELOC].nibuf++;
				Input[RELOC].nsize++;
				r2 = get(RELOC);
			} else
				r2 = *Input[RELOC].Iptr++;

			/*	t = lui	R, addr
			**	r is reloc
			*/
			if (IS_B(r)) {
				pc = 1;
				w = 1;
				/*	t2 = add R, addr */
			} else {
				switch (t2&0xf800) {
				case 0x4000:	/* add */
				case 0x8800:	/* add */
					pc = 0;
					w = 1;
					break;
				case 0x2000:	/* sw name */
				case 0x8000:	/* lw name */
					pc = 0;
					w = 1;
					break;
				case 0x9800:	/* lb name */
				case 0xb800:	/* sb name */
					pc = 0;
					w = 0;
					break;

				case 0x4800:	/* jal	rel */
				case 0x6800:	/* j	rel */
					w = 2;
					pc = 1;
					break;
				case 0x7000:	/* beq	rel */
				case 0x7800:	/* bne	rel */
				case 0xf000:	/* blt	rel */
				case 0xf800:	/* bge	rel */
					w = 0;
					pc = 1;
					break;
				default:
					fprintf(stderr, "ins = 0x%04x/%04x %04x/%04x off=0x%04x\n", t, r, t2, r2, off);
					error(1, "relocation format botch (unknown instruction))");
					break;
				}
			}

			t1 = (t&0x8000) |
			     ((t&0x7f)<<8);
			t &= ~0x807f;
			if (pc) {
				switch (w) {
				case 1:
					tmp = (t2&0xff) |	/* add */
			      	      	      (t2&0x80?0xff00:0x0000);
					t1 += tmp;
					t1 &= 0xffff;
					t2 &= 0xff00;
					break;
				case 0:
					tmp = (t2&0x07fe) |	/* j jal */
					      (t2&1?0xf800:0x0000);
					t1 |= tmp;
					t2 &= 0xe800;
					break;
				case 2:
					tmp = (t2&0xfe) |	/* branch */
			      	      	      (t2&1?0xff00:0x0000);
					t1 |= tmp;
					t2 &= 0xff00;
					break;
				}
			} else {
				if (w) {
					tmp = (t2&0xfe) |	/* lw sw  name */
					      (t2&1?0xff00:0x0000);
					t1 |= tmp;
					t2 &= 0xff00;
				} else {
					tmp = (t2&0xff) |
					      (t1&0x80?0xff00:0x0000);	/* lb sw  name */
					t1 |= tmp;
					t2 &= 0xff00;
				}
			}
			switch (REL_TYPE(r)) {
			case REL_ABS:
				break;
			case REL_TEXT:
				t1 += ctrel;
				break;
			case REL_DATA:
				t1 += cdrel;
				break;
			case REL_BSS:
				t1 += cbrel;
				break;
			case REL_EXTERN:
				i = *lookloc(lp, r);
				vsym = sym2va(i);
				sp = (SYMBOL *)(vmmapseg(&Vspace, VSEG(vsym))->s_cinfo +
						VOFF(vsym));
				if (sp->n_type==N_EXT+N_UNDF) {
					r = (r&01) + ((nsym + i)<<4) + REXT;
					break;
				}
				t1 += sp->n_value;
				r = (r&01) + ((sp->n_type-(N_EXT+N_ABS))<<1);
				break;
			default:
				error(1, "relocation format botch (symbol type))");
			}
			t1 &= 0xffff;

			if (IS_B(r)) {
				tmp = t1&0xff;			
				t1 &= 0xff00;
				if (tmp&0x80)
					t1 += 0x100;
				t |= t1&0x8000;
				t |= (t1>>8)&0x7f;
				t2 |= tmp&0xff;	/* add */
			} else {
				if (pc) 
					t1 = (t1-(creloc+off+2))&0xffff;
				tmp = t1&0xff;
				t1 &= 0xff00;
				t |= t1&0x8000;
				t1 |= (t1>>8)&0x7f;
				if (pc) {
					if (w == 2) {
						t2 |= tmp;	/* add */
					} else {
						t2 |= tmp&0xfe;	/* jal/br */
					}
				} else {
					if (w) {	/* lw */
						t2 |= tmp&0xfe;
					} else {	/* lb */
						t2 |= tmp;
					}
				}
			}
			putw(t, b1);
			if (rflag)
				putw(r, b2);
			off +=2;
			t = t2;
			r = r2;
		}
#else
		switch (r&016) {
		case RTEXT:
			t += ctrel;
			break;
		case RDATA:
			t += cdrel;
			break;
		case RBSS:
			t += cbrel;
			break;
		case REXT:
			i = *lookloc(lp, r);
			vsym = sym2va(i);
			sp = (SYMBOL *)(vmmapseg(&Vspace, VSEG(vsym))->s_cinfo +
					VOFF(vsym));
			if (sp->n_type==N_EXT+N_UNDF) {
				r = (r&01) + ((nsym + i)<<4) + REXT;
				break;
			}
			t += sp->n_value;
			r = (r&01) + ((sp->n_type-(N_EXT+N_ABS))<<1);
			break;
#ifndef pdp11
		default:
			error(1, "relocation format botch (symbol type))");
#endif
		}
		if (r&01)
			t -= creloc;
#endif
		off += 2;
		putw(t, b1);
		if (rflag)
			putw(r, b2);
	}
}

finishout()
{
	register u_int n;
	register SYMBOL *sp;
#ifdef RNL
	struct	real_nlist objsym;
#else
	struct	nlist objsym;
#endif
	VADDR	vsym;
	int type, len;
	off_t	stroff;
	long dtotal, ovrnd;
	int	thunk[THUNKSIZ / sizeof (int)];
 
	if (numov) {
		int aovhndlr[NOVL+1];

		for (n=1; n<=numov; n++) {
			/* Note that NOVL can be up to 15 with this */
			ovhndlr.n_name[HNDLR_NUM] = "0123456789abcdef"[n];
			aovhndlr[n] = adrof(ovhndlr.n_name);
		}
		for (n=0,vsym=sym2va(0); n < symindex; n++,vsym=sym2va(n)) {
			sp = (SYMBOL *)(vmmapseg(&Vspace, VSEG(vsym))->s_cinfo +
					VOFF(vsym));
			if (sp->n_ovly && (sp->n_type & (N_EXT+N_TEXT))) {
				thunk[0] = 012701;	/* mov $~foo+4, r1 */
				thunk[1] = sp->sovalue + 4;
				thunk[2] = 04537;	/* jsr r5, ovhndlrx */
				thunk[3] = aovhndlr[sp->n_ovly];
				fwrite(thunk, THUNKSIZ, 1, toutb);
				torigin += THUNKSIZ;
			}
		}
	}
	if (nflag||iflag) {
		n = torigin;
		while (n&077) {
			n += 2;
			putw(0, toutb);
			if (rflag)
				putw(0, troutb);
		}
	}
	if (numov)
		copy(voutb);
	copy(doutb);
	if (rflag) {
		copy(troutb);
		copy(droutb);
	}

	if	(sflag==0)
		{
/*
 * Now write the symbol table out, converting from the 'fixed' style
 * symbol table used internally to the string table version used in
 * object/executable files.  First the "local" (non-global) symbols
 * are written out, these are the symbols placed in the temporary file
 * accessed via 'soutb'.
 *
 * 'voutb' (overlay temp file), 'troutb' (text relocation temp file),
 * 'droutb' (data relocation temp file), and 'doutb' (data temp file)
 * have all been finished with and closed by this point.  We reuse one 
 * of these ('doutb') to build the string table.
*/

		tcreat(&doutb, 1);
		nsym = 0;
		stroff = sizeof (long);		/* string table size */
		if	(xflag == 0)
			{
			fflush(soutb);		/* flush local symbol file */
			rewind(soutb);
			while	(fread(&cursym, sizeof (cursym), 1, soutb) == 1)
				{
				if	(feof(soutb))
					break;
				objsym.n_value = cursym.n_value;
				objsym.n_type = cursym.n_type;
				objsym.n_ovly = cursym.n_ovly;
				objsym.n_un.n_strx = stroff;
				len = strlen(cursym.n_name);
				if	(len >= NNAMESIZE)
					len = NNAMESIZE;
				fwrite(cursym.n_name, 1, len, doutb);
				fputc('\0', doutb);
				stroff += (len + 1);
				fwrite(&objsym, sizeof (objsym), 1, toutb);
				nsym++;
				}
			fclose(soutb);
			}
/*
 * Now we dump the global/external symbol table by marching thru the
 * 'vm' addresss space.
*/
		for	(n = 0, vsym = sym2va(0); n < symindex; n++,
							vsym = sym2va(n))
			{
			sp = (SYMBOL *)(vmmapseg(&Vspace, VSEG(vsym))->s_cinfo +
					VOFF(vsym));
			objsym.n_value = sp->n_value;
			objsym.n_type = sp->n_type;
			objsym.n_ovly = sp->n_ovly;
			objsym.n_un.n_strx = stroff;
			len = strlen(sp->n_name);
			if	(len > NNAMESIZE)
				len = NNAMESIZE;
			fwrite(sp->n_name, 1, len, doutb);
			fputc('\0', doutb);
			stroff += (len + 1);
			fwrite(&objsym, sizeof (objsym), 1, toutb);
			nsym++;
			}
#ifdef	whybother
		if	(stroff & 1)
			{
			fputc('\0', doutb);
			stroff++;
			}
#endif
/*
 * Now write the length of the string table out.  Then copy the temp
 * file containing the strings to the image being built.
*/
		fwrite(&stroff, sizeof (stroff), 1, toutb);
		copy(doutb);
		}
/*
 * Fix up the header with the correct symbol table size - we now know
 * _exactly_ how many symbols were placed in the symbol table (the size
 * used earlier was only an estimate
*/
	fflush(toutb);
	rewind(toutb);
	fread(&filhdr.e, sizeof (filhdr.e), 1, toutb);
	filhdr.e.a_syms = nsym * sizeof (objsym);
	rewind(toutb);
	fwrite(&filhdr.e, sizeof (filhdr.e), 1, toutb);
	fclose(toutb);

	if (!ofilfnd) {
		if (rename("l.out", "a.out") < 0)
			error(1, "cannot move l.out to a.out");
		ofilename = "a.out";
	}
/*
 * we now do a sanity check on the total sizes of things.  Previously the
 * linker could produce a program marked as executable but which had bogus
 * overlay+root sizes, etc.
*/
#define	K56	(56L * 1024L)
#define	K64	(64L * 1024L)

	dtotal = (long)dsize + (long)bsize;
	ovrnd = rnd8k(filhdr.o.max_ovl);	/* 0 if not overlaid */
	type = 0;
	if (nflag) {
		if (rnd8k(tsize) + ovrnd + dtotal > K56)
			type = filhdr.e.a_magic;
	}
	else if (iflag) {
		if ((rnd8k(tsize) + ovrnd > K64) || (dtotal > K56))
			type = filhdr.e.a_magic;
	}
	else {
		if ((long)tsize + dtotal > K56)
			type = filhdr.e.a_magic;
	}
	if (type && !rflag) {
		fprintf(stderr, "ld: too big for type %o\n", type);
		errlev = 2;
	}
	delarg = errlev;
	delexit(0);
}

long
rnd8k(siz)
	u_int siz;
	{
	long l = siz;

	return((l + 017777) & ~017777L);
	}

mkfsym(s)
	char *s;
	{

	if (sflag || xflag)
		return;
	strncpy(cursym.n_name, s, NNAMESIZE);
	cursym.n_type = N_FN;
	cursym.n_value = torigin;
	fwrite(&cursym, sizeof (cursym), 1, soutb);
	}

mget(loc, an, which)
	register short *loc;
	int an, which;
{
	register int n;
	register STREAM *tp = &Input[which];

	n = an >> 1;
	if ((tp->nibuf -= n) >= 0) {
		if ((tp->nsize -= n) > 0) {
			bcopy(tp->ptr, loc, an);
			tp->Iptr += n;
			return;
		}
		tp->nsize += n;
	}
	tp->nibuf += n;
	do {
		*loc++ = get(which);
	} while (--n);
}

dseek(which, aloc, s)
	int which;
	off_t aloc;
	int s;
	{
	register STREAM *sp = &Input[which];
	register u_int b, o;
	int n;

	b = aloc / sp->bsize;
	o = aloc & (sp->bsize - 1);
	if	(sp->bno != b)
		{
		(void)lseek(infil, (off_t)sp->bsize * b, L_SET);
		if	((n = read(infil, (char *)sp->buff, sp->bsize)) < 0)
			n = 0;
		sp->bno = b;
		sp->nread = n;
		}
	sp->nibuf = sp->nread - o;
	sp->Cptr = (char *)sp->buff + o;
	if	(which != STRINGS)
		sp->nibuf >>= 1;
	if	(s != -1)
		sp->nsize = (s >> 1) & 077777;
	if	(sp->nibuf <= 0)
		sp->nsize = 0;
	}

get(which)
	int which;
{
	register STREAM *sp = &Input[which];

	if (--sp->nibuf < 0) {
		dseek(which, (off_t)(sp->bno + 1) * sp->bsize, -1);
		--sp->nibuf;
	}
	if (--sp->nsize <= 0) {
		if (sp->nsize < 0)
			error(1, "premature EOF#1");
	}
	return(*sp->Iptr++);
}

getfile(acp, flag, phase)
char *acp;
	int flag;	/* 1 = fatal if file not found, -1 = not fatal */
{
	char arcmag[SARMAG+1];
	struct stat stb;

	filname = acp;
	chdr.name[0] = '\0';		/* not in archive for now */
	if (filname[0] == '-' && filname[1] == 'l')
		infil = libopen(filname + 2, O_RDONLY);
	else
		infil = open(filname, O_RDONLY);
	if (infil < 0) {
		if (phase == 1)		/* only complain once on phase 1 */
			error(flag, "cannot open");
		return(-1);
	}
	fstat(infil, &stb);
	Input[TEXT].bno = -1;
	Input[RELOC].bno = -1;
	Input[SYMBOLS].bno = -1;
	Input[STRINGS].bno = -1;
	dseek(TEXT, 0L, SARMAG);
	if (Input[TEXT].nsize <= 0)
		error(1, "premature EOF#2");
	mget((char *)arcmag, SARMAG, TEXT);
	arcmag[SARMAG] = 0;
	if (strcmp(arcmag, ARMAG))
		return(0);
	lseek(infil, (off_t)SARMAG, L_SET);
	if (get_arobj(infil) <= 0)
		return(1);
	if	(strcmp(chdr.name, RANLIBMAG))
		return(1);	/* regular archive */
	return (stb.st_mtime > chdr.date ? 3 : 2);
}

/*
 * Search for a library with given name
 * using the directory search array.
 */
libopen(name, oflags)
	char *name;
	int oflags;
{
	register char *p, *cp;
	register int i;
	static char buf[100];
	int fd;

	for (i = 0; i < ndir ; i++) {
		p = buf;
		for (cp = dirs[i]; *cp; *p++ = *cp++)
			;
		*p++ = '/';
		*p++ = 'l';
		*p++ = 'i';
		*p++ = 'b';
		for (cp = name; *cp; *p++ = *cp++)
			;
		*p++ = '.';
		*p++ = 'a';
		*p++ = '\0';
		fd = open(buf, oflags);
		if (fd != -1) {
			filname = buf;
			return(fd);
		}
	}
	return(-1);
}

short *
lookup()
	{
	register short *hp;
	register char *cp;
	SYMBOL	*sp;
	union
		{
		long	x;
		short	y[2];
		} sh;
	VADDR	vsym;

	sh.x = 0;
	for	(cp = cursym.n_name; cp < &cursym.n_name[NNAMESIZE] && *cp;)
		sh.x = (sh.x<<1) + *cp++;
	sh.y[1] += sh.y[0];
	hp = &hshtab[(sh.y[1]&077777)%NSYM+2];
	while	(*hp != -1)
		{
		vsym = sym2va(*hp);
		sp = (SYMBOL *)(vmmapseg(&Vspace,VSEG(vsym))->s_cinfo +
				VOFF(vsym));
		if	(!strncmp(sp->n_name, cursym.n_name, NNAMESIZE))
			break;
		if	(++hp >= &hshtab[NSYM+2])
			hp = hshtab;
		}
	return(hp);
	}

short *
slookup(s)
	char *s;
	{

	strncpy(cursym.n_name, s, NNAMESIZE);
	cursym.n_type = N_EXT+N_UNDF;
	cursym.n_value = 0;
	return(lookup());
	}

enter(hp)
	short	*hp;
	{
	register SYMBOL *sp;
	u_int word, bit, hnum;
	VADDR	vsym;
	register struct	vseg	*seg;

	if	(*hp == -1)
		{
		if	(symindex>=NSYM)
			error(1, "symbol table overflow");
		hnum = hp - hshtab;
		word = hnum / 16;
		bit = hnum % 16;
		symhash[word] |= (1 << bit);
		vsym = sym2va(symindex);
		*hp = lastsym = symindex;
		symindex++;
		seg = vmmapseg(&Vspace, VSEG(vsym));
		sp = (SYMBOL *)(seg->s_cinfo + VOFF(vsym));
		strncpy(sp->n_name, cursym.n_name, NNAMESIZE);
		sp->n_type = cursym.n_type;
		sp->n_value = cursym.n_value;
		if	(sp->n_type == N_EXT+N_TEXT)
			{
			sp->n_ovly = curov;
			if	(trace)
				printf("found %.*s in overlay %d at %u\n",
					NNAMESIZE, sp->n_name, sp->n_ovly,
					sp->n_value);
			}
		VMMODIFY(seg);
		return(1);
		}
	lastsym = *hp;
	return(0);
	}

error(n, s)
char *s;
{
	if (!s)
		delexit(0);
	if (errlev==0)
		printf("ld:");
	if (filname) {
		printf("%s", filname);
		if (n != -1 && chdr.name[0])
			printf("(%s)", chdr.name);
		printf(": ");
	}
	printf("%s\n", s);
	if (n == -1)
		return;
	if (n)
		delexit(0);
	errlev = 2;
}

readhdr(loc)
off_t loc;
{
	dseek(TEXT, loc, sizeof filhdr);
	mget((int *)&filhdr.e, sizeof filhdr.e, TEXT);
	if (filhdr.e.a_magic != A_MAGIC1)
		error(1, "bad magic number");
	if (filhdr.e.a_text&01)
		++filhdr.e.a_text;
	if (filhdr.e.a_data&01)
		++filhdr.e.a_data;
	if (filhdr.e.a_bss&01)
		++filhdr.e.a_bss;
	cdrel = -filhdr.e.a_text;
	cbrel = cdrel - filhdr.e.a_data;
}

tcreat(fpp, tempflg)
	FILE	**fpp;
	int	tempflg;
	{
	register int ufd;
	char	*nam;

	nam = (tempflg ? tfname : ofilename); 
	if	((ufd = open(nam, O_RDWR|O_CREAT|O_TRUNC, 0666)) < 0) {
		printf("tmp='%s'\n", nam);
		error(2, tempflg?"cannot create temp":"cannot create output");
	}
	if	(tempflg)
		unlink(tfname);
	*fpp = fdopen(ufd, "r+");
	}

adrof(s)
	char *s;
	{
	register short *p;
	register SYMBOL *sp;
	VADDR	vsym;

	p = slookup(s);
	if	(*p == -1)
		{
		printf("%.*s: ", NNAMESIZE, s);
		error(1, "undefined");
		}
	vsym = sym2va(*p);
	sp = (SYMBOL *)(vmmapseg(&Vspace, VSEG(vsym))->s_cinfo + VOFF(vsym));
	return(sp->n_value);
	}

copy(fp)
	register FILE	*fp;
	{
	register int c;

	fflush(fp);
	rewind(fp);
	while	((c = getc(fp)) != EOF)
		putc(c, toutb);
	fclose(fp);
	}

short *
lookloc(alp, r)
struct local *alp;
{
	register struct local *clp, *lp;
	register int sn;

	lp = alp;
	sn = (r>>4) & 07777;
	for (clp = local; clp<lp; clp++)
		if (clp->locindex == sn)
			return(&clp->locsymbol);
	error(1, "local symbol botch");
	/*NOTREACHED*/
}

roundov()
	{

	while	(torigin & 077)
		{
		putw(0, voutb);
		torigin += sizeof (int);
		}
	}

u_int
add(a,b,s)
int a, b;
char *s;
{
	long r;

	r = (long)(u_int)a + (u_int)b;
	if (r >= 0200000)
		error(1,s);
	return(r);
}

/*
 * "borrowed" from 'ar' because we didn't want to drag in everything else
 * from 'ar'.  The error checking was also ripped out, basically if any
 * of the criteria for being an archive are not met then a -1 is returned
 * and the rest of 'ld' figures out what to do.
*/

typedef struct ar_hdr HDR;
static char hb[sizeof(HDR) + 1];	/* real header */

/* Convert ar header field to an integer. */
#define	AR_ATOI(from, to, len, base) { \
	bcopy(from, buf, len); \
	buf[len] = '\0'; \
	to = strtol(buf, (char **)NULL, base); \
}

/*
 * get_arobj --
 *	read the archive header for this member
 */
get_arobj(fd)
	int fd;
{
	HDR *hdr;
	register int len, nr;
	register char *p;
	char buf[20];

	nr = read(fd, hb, sizeof(HDR));
	if (nr != sizeof(HDR))
		return(-1);

	hdr = (HDR *)hb;
	if (strncmp(hdr->ar_fmag, ARFMAG, sizeof(ARFMAG) - 1))
		return(-1);

	/* Convert the header into the internal format. */
#define	DECIMAL	10
#define	OCTAL	 8

	AR_ATOI(hdr->ar_date, chdr.date, sizeof(hdr->ar_date), DECIMAL);
	AR_ATOI(hdr->ar_uid, chdr.uid, sizeof(hdr->ar_uid), DECIMAL);
	AR_ATOI(hdr->ar_gid, chdr.gid, sizeof(hdr->ar_gid), DECIMAL);
	AR_ATOI(hdr->ar_mode, chdr.mode, sizeof(hdr->ar_mode), OCTAL);
	AR_ATOI(hdr->ar_size, chdr.size, sizeof(hdr->ar_size), DECIMAL);

	/* Leading spaces should never happen. */
	if (hdr->ar_name[0] == ' ')
		return(-1);

	/*
	 * Long name support.  Set the "real" size of the file, and the
	 * long name flag/size.
	 */
	if (!bcmp(hdr->ar_name, AR_EFMT1, sizeof(AR_EFMT1) - 1)) {
		chdr.lname = len = atoi(hdr->ar_name + sizeof(AR_EFMT1) - 1);
		if (len <= 0 || len > MAXNAMLEN)
			return(-1);
		nr = read(fd, chdr.name, (size_t)len);
		if (nr != len)
			return(-1);
		chdr.name[len] = 0;
		chdr.size -= len;
	} else {
		chdr.lname = 0;
		bcopy(hdr->ar_name, chdr.name, sizeof(hdr->ar_name));

		/* Strip trailing spaces, null terminate. */
		for (p = chdr.name + sizeof(hdr->ar_name) - 1; *p == ' '; --p);
		*++p = '\0';
	}
	return(1);
}

/*
 * skip - where to seek for next archive member.
 */
off_t
skip()
	{
	off_t len;

	len = chdr.size + (chdr.size + chdr.lname & 1);
	len += sizeof (HDR);
	return(len);
	}

inistr(which)
	int	which;
	{
	register STREAM *sp = &Input[which];
	register int	size = 4096;

	if	(sp->buff == (int *)NULL)
		{
		while	(size > 256)
			{
			sp->buff = (int *)malloc(size);
			if	(sp->buff)
				{
				sp->bsize = size;
				return;
				}
			size >>= 1;
			}
		error(1, "No memory for strings");
		}
	}
