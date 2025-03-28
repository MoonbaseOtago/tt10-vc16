%token t_la t_lr t_value t_sp t_epc t_csr t_s0 t_s1 t_a0 t_a1 t_a2 t_a3 t_a4 t_a5 t_and t_or t_xor t_sub t_add t_mv t_nop t_inv t_ebreak t_jalr t_jr t_lw t_lb t_sw t_sb t_lea t_lui t_li t_beqz t_bnez t_bltz t_bgez t_j t_jal t_sll t_srl t_sra t_word t_name t_nl t_mul t_mulhi t_mmu t_addb t_addbu t_syscall t_stmp t_swapsp t_shl t_shr t_zext t_sext t_ldio t_stio t_flush t_dcache t_icache t_ret t_swap t_addpc t_div t_invmmu t_text t_data t_bss t_byte t_extern t_space t_num_label t_global t_string t_stringv t_align t_r0 t_r1 t_r2 t_r3 t_r4 t_r5 t_r6 t_r7 t_x0 t_addc t_subc t_blez t_bgtz t_neg t_file t_ident t_size t_comm t_lcomm t_ascii t_fp
%start  program
%%

exp:		e t_shl exp		{ $$ = $1 << $3; }
	|	e t_shr exp		{ $$ = $1 >> $3; }
	|	e			{ $$ = $1; }
	;
e:		e0 '&' e		{ $$ = $1 & $3; }
	|	e0 '|' e		{ $$ = $1 | $3; }
	|	e0 '^' e		{ $$ = $1 ^ $3; }
	|	e0			{ $$ = $1; }
	;

e0:		e1 '+' e0		{ $$ = $1 + $3; }
	|	e1 '-' e0		{ $$ = $1 - $3; }
	|	e1			{ $$ = $1; }
	;

e1:		e2 '*' e1		{ $$ = $1 * $3; }
	|	e2 '/' e1		{ $$ = ($3==0?0:$1 / $3); }
	|	e2			{ $$ = $1; }
	;
e2:		'+' e2 			{ $$ = $2; }
	|	'-' e2 			{ $$ = -$2; }
	|	'~' e2 			{ $$ = ~$2; }
	|	'(' exp ')' 		{ $$ = $2; }
	|	t_value 		{ $$ = $1; }
	;

xr:		rm 			{ $$ = 8|$1; }
	|	rx			{ $$ = $1; }
	;

rx: 		t_x0			{ $$ = 0; }
	|	t_lr			{ $$ = 1; }
	|	t_epc			{ $$ = 3; }
	|	t_csr			{ $$ = 4; }
	|	t_mmu			{ $$ = 5; }
	|	t_stmp			{ $$ = 6; }
	|	t_mulhi			{ $$ = 7; }
	;
r:		xr			{ $$ = $1; }
	|	t_sp			{ $$ = 2; }
	;
rm:		t_s0 			{ $$ = 0; }
	|	t_s1 			{ $$ = 1; }
	|	t_a0			{ $$ = 2; }
	|	t_a1			{ $$ = 3; }
	|	t_a2			{ $$ = 4; }
	|	t_a3			{ $$ = 5; }
	|	t_a4			{ $$ = 6; }
	|	t_a5			{ $$ = 7; }
	|	t_r0 			{ $$ = 0; }
	|	t_r1 			{ $$ = 1; }
	|	t_r2			{ $$ = 2; }
	|	t_r3			{ $$ = 3; }
	|	t_r4			{ $$ = 4; }
	|	t_r5			{ $$ = 5; }
	|	t_r6			{ $$ = 6; }
	|	t_r7			{ $$ = 7; }
	|	t_fp			{ $$ = 7; }
	;

ins:		t_and  rm ',' rm 	{ $$ = 0x8c61|($2<<7)|($4<<2); }      
	|	t_or  rm ',' rm         { $$ = 0x8c41|($2<<7)|($4<<2); } 
	|	t_mul  rm ',' rm        { $$ = 0x8c03|($2<<7)|($4<<2); } 
	|	t_div  rm ',' rm        { $$ = 0x8c23|($2<<7)|($4<<2); } 
	|	t_addb  rm ',' rm       { $$ = 0x8c43|($2<<7)|($4<<2); } 
	|	t_addbu  rm ',' rm      { $$ = 0x8c63|($2<<7)|($4<<2); } 
	|	t_swap  rm ',' rm      	{ $$ = 0x9c03|($2<<7)|($4<<2); } 
	|	t_addpc  rm      	{ $$ = 0x9c23|($2<<7); } 
	|	t_sext  rm      	{ $$ = 0x9c27|($2<<7); } 
	|	t_zext  rm      	{ $$ = 0x9c2b|($2<<7); } 
	|	t_inv  rm      		{ $$ = 0x9c2f|($2<<7); } 
	|	t_neg  rm      		{ $$ = 0x9c33|($2<<7); } 
	|	t_xor  rm ',' rm        { $$ = 0x9c43|($2<<7)|($4<<2); } 
	|	t_sub  rm ',' r         { $$ = 0x8c01|($2<<7)|($4<<2); } 
	|	t_subc  rm ',' r        { $$ = 0x9c01|($2<<7)|($4<<2); } 
	|	t_addc  rm ',' r        { $$ = 0x9c41|($2<<7)|($4<<2); } 
	|	t_and  rm ',' exp	{
						if ($4 >= 0 && $4 < (1<<6)) {
							$$ = 0x8801|($2<<7)|imm6($4);
						} else
						if ($4 >= 0 && $4 < (1<<14)) {
							emit(0x6001 | ((7)<<7) | luioff(($4<<2)&0xff00,0));
							$$ = 0x8801|($2<<7)|imm6($4&0x3f);
						} else {
							emit_err("constant must be 14 bits");
							$$ = 0;
						}
					}
	|	t_or  rm ',' exp	{
						if ($4 >= 0 && $4 < (1<<6)) {
							$$ = 0x8803|($2<<7)|imm6($4);
						} else
						if ($4 >= 0 && $4 < (1<<14)) {
							emit(0x6001 | ((7)<<7) | luioff(($4<<2)&0xff00,0));
							$$ = 0x8803|($2<<7)|imm6($4&0x3f);
						} else {
							emit_err("constant must be 14 bits");
							$$ = 0;
						}
					}
	|	t_add  t_sp ',' exp 	{	
						if ($4 >= -128 && $4 < 128) {
							$$ = 0x6101 | addsp($4);
						} else {
							int v = $4;
							emit(0x6001 | ((7)<<7) | luioff(v&0xff00, 0));
							v &= 0xff;
							if (v&0x80)
							 	v |= ~0xff;
							$$ = 0x6101 | addsp(v);
						}
					}
	|	t_sub  t_sp ',' exp 	{
						int v = -$4;
						if ($4 >= -128 && $4 < 128) {
							$$ = 0x6101 | addsp($4);
						} else {
							emit(0x6001 | ((7)<<7) | luioff(v&0xff00,0));
							v &= 0xff;
							if (v&0x80)
							 	v |= ~0xff;
							$$ = 0x6101 | addsp(v);
						}
					}
	|	t_sub  t_sp ',' rm 	{ $$ = 0x9c3b | ($4<<7); }
	|	t_add  t_sp ',' r       { $$ = 0x8002|(2<<7)|($4<<2); } 
	|	t_add  rm ',' exp	{
						if ($4 >= -128 && $4 < 128) {
							$$ = 0x0001|($2<<7)|imm8($4, 0);
						} else {
							emit(0x6001 | ((7)<<7) | luioff($4&0xff00,0));
							$$ = 0x0001|($2<<7)|imm8($4&0xff, 0);
						}
					}
	|	t_sub  rm ',' exp	{ 
						int x = -$4;
						if (x >= -128 && x < 128) {
							$$ = 0x0001|($2<<7)|imm8(x, 0);
						} else {
							emit(0x6001 | ((7)<<7) | luioff(x&0xff00,0));
							$$ = 0x0001|($2<<7)|imm8(x&0xff, 0);
						}
					}
	|	t_add  rx ',' exp	{
						if ($4 >= -128 && $4 < 128) {
							$$ = 0x0001|($2<<7)|imm8($4, 0);
						} else {
							emit(0x6001 | ((7)<<7) | luioff($4&0xff00,0));
							$$ = 0x0001|($2<<7)|imm8($4&0xff, 0);
						}
					}
	|	t_sub  rx ',' exp	{
						int x = -$4;
						if (x >= -128 && x < 128) {
							$$ = 0x0001|($2<<7)|imm8(x, 0);
						} else {
							emit(0x6001 | ((7)<<7) | luioff(x&0xff00,0));
							$$ = 0x0001|($2<<7)|imm8(x&0xff, 0);
						}
					}
	|	t_add  rm ',' r        	{ $$ = 0x9002|((8|$2)<<7)|($4<<2); } 
	|	t_add  rx ',' r        	{ $$ = 0x9002|($2<<7)|($4<<2); } 
	|	t_mv   r ',' r        	{ $$ = 0x8002|($2<<7)|($4<<2); } 
	|	t_nop  			{ $$ = 0x0001; }
	|	t_inv  		 	{ $$ = 0x0003; }
	|	t_syscall  		{ $$ = 0x0017; }
	|	t_swapsp  		{ $$ = 0x001b; }
	|	t_ebreak  		{ $$ = 0x0007; }
	|	t_jalr r  		{ $$ = 0x9002|($2<<7); }
	|	t_jr r  		{ $$ = 0x8002|($2<<7); }
	|	t_ret	  		{ $$ = 0x8002|(1<<7); }
	|	t_lw r ',' exp '(' t_sp ')'{ $$ = 0x4002|($2<<7)|offX($4); }
	|	t_lw r ',' '(' t_sp ')'	{ $$ = 0x4002|($2<<7)|offX(0); }

	|	t_lw r ',' t_name	{ 
						chkr($2);
						ref_label($4, 10, 0);
						emit(0x6001 | ((7)<<7));
						$$ = 0x0002|(($2&7)<<7);
				        }
	|	t_lw r ',' exp		{ if ($4 >= -256 && $4 < 256) {
						$$ = 0x0002|(($2&7)<<7)|pack_label($4, 0x1fe, 1); chkr($2);
					  } else {
						emit(0x6001 | ((7)<<7) | luioff($4&0xff00,0));
						$$ = 0x0002|(($2&7)<<7)|pack_label($4, 0xfe, 1); chkr($2);
					  }
				        }
	|	t_lb r ',' t_name	{ 
						chkr($2);
						ref_label($4, 11, 0);
						emit(0x6001 | ((7)<<7));
						$$ = 0x6002|(($2&7)<<7);
				        }
	|	t_lb r ',' exp		{ if ($4 >= -128 && $4 < 128) {
						$$ = 0x6002|(($2&7)<<7)|pack_label($4, 0xff, 1); chkr($2);
					  } else {
						emit(0x6001 | ((7)<<7) | luioff($4&0xff00,0));
						$$ = 0x6002|(($2&7)<<7)|pack_label($4, 0xff, 1); chkr($2);
					  }
					}
	|	t_lw r ',' exp '(' rm ')'{ if ($6 == 7) {
						if ($4 <= -256 || $4 > 256) {
							int x = $4;
							emit(0x6001 | ((7)<<7) | luioff($4&0xff00,0));
							x &= 0xff;
							if (x&0x80)
								x |= 0xffffff00;
							$$ = 0x2000|pack_label(x, 0xfe, 1)|(($2&7)<<7); chkr($2); 
						} else {
							$$ = 0x2000|pack_label($4, 0x1fe, 1)|(($2&7)<<7); chkr($2); 
						}
					 } else {
						if ($4 >= -(1<<5) && $4 < (1<<5)) {
							$$ = 0x4000|($6<<7)|roffX($4)|(($2&7)<<2); chkr($2);
						} else
						if ($4 > 0 && $4 < (1<<13)) {
							int v;

							emit(0x6001 | ((7)<<7) | luioff(($4<<2)&0xff00,0));
							v = $4&0x3f;
							if (v&(1<<5))
								v |= (~0)<<5;
							$$ = 0x4000|($6<<7)|roffX(v)|(($2&7)<<2); chkr($2);
						} else {
							emit_err("constant must be >= -32 and < 32768");
							$$ = 0;
						}
					}}
	|	t_lw r ',' '(' rm ')'	{ if ($5==7) {
						$$ = 0x2000|pack_label(0, 0x1fe, 1)|(($2&7)<<7); chkr($2); 
					  } else {
						$$ = 0x4000|($5<<7)|roffX(0)|(($2&7)<<2); chkr($2); 
					}}
	|	t_lb r ',' exp '(' rm ')'{ if ($6==7) { 
						if ($4 <= -128 || $4 > 128) {
							int x = $4;
							emit(0x6001 | ((7)<<7) | luioff(x&0xff00,0));
							x &= 0xff;
							if (x&0x80)
								x |= 0xffffff00;
							$$ = 0xa003|pack_label(x, 0xff, 1)|(($2&7)<<7); chkr($2); 
						} else {
							$$ = 0xa003|pack_label($4, 0xff, 1)|(($2&7)<<7); chkr($2); 
						}
					 } else {
						if ($4 >= -(1<<4) && $4 < (1<<4)) {
							$$ = 0x6000|($6<<7)|roff($4)|(($2&7)<<2); chkr($2);
						} else
						if ($4 > 0 && $4 < (1<<13)) {
							int v;

							emit(0x6001 | ((7)<<7) | luioff(($4<<3)&0xff00,0));
							v = $4&0x1f;
							if (v&(1<<4))
								v |= (~0)<<4;
							$$ = 0x6000|($6<<7)|roff(v)|(($2&7)<<2); chkr($2);
						} else {
							emit_err("constant must be >= -16 and < 16384");
							$$ = 0;
						}
					 }}
	|	t_lb r ',' '(' rm ')'	{ if ($5==7) {
						 $$ = 0xa003|pack_label(0, 0xff, 1)|(($2&7)<<7); chkr($2);
					} else {
						 $$ = 0x6000|($5<<7)|roff(0)|(($2&7)<<2); chkr($2);
					}}
	|	t_sw r ',' exp '(' t_sp ')'{ $$ = 0xc002|($2<<7)|offX($4); }
	|	t_sw r ',' '(' t_sp ')'	{ $$ = 0xc002|($2<<7)|offX(0); }
	|	t_sw r ',' t_name	{ 
						chkr($2);
						ref_label($4, 10, 0);
						emit(0x6001 | ((7)<<7));
						$$ = 0x8000|(($2&7)<<7);
				        }
	|	t_sw r ',' exp		{ if ($4 >= -256 && $4 < 256) {
						$$ = 0x8000|(($2&7)<<7)|pack_label($4, 0x1fe, 1); chkr($2);
					  } else {
						emit(0x6001 | ((7)<<7) | luioff($4&0xff00,0));
						$$ = 0x8000|(($2&7)<<7)|pack_label($4, 0xfe, 1); chkr($2);
					  }
					}
	|	t_sb r ',' t_name	{ 
						chkr($2);
						ref_label($4, 11, 0);
						emit(0x6001 | ((7)<<7));
						$$ = 0xe002|(($2&7)<<7);
				        }
	|	t_sb r ',' exp		{ if ($4 >= -128 && $4 < 128) {
						$$ = 0xe002|(($2&7)<<7)|pack_label($4, 0xff, 1); chkr($2);
					  } else {
						emit(0x6001 | ((7)<<7) | luioff($4&0xff00,0));
						$$ = 0xe002|(($2&7)<<7)|pack_label($4, 0xff, 1); chkr($2);
					  }
					}
	|	t_sw r ',' exp '(' rm ')'{ if ($6 == 7) {
						if ($4 <= -256 || $4 > 256) {
							int x = $4;
							emit(0x6001 | ((7)<<7) | luioff(x&0xff00,0));
							x &= 0xff;
							if (x&0x80)
								x |= 0xffffff00;
							$$ = 0xa000|pack_label(x, 0xfe, 1)|(($2&7)<<7); chkr($2);
						} else {
							$$ = 0xa000|pack_label($4, 0x1fe, 1)|(($2&7)<<7); chkr($2);
						}
					   } else {
						if ($4 >= -(1<<5) && $4 < (1<<5)) {
							$$ = 0xc000|($6<<7)|roffX($4)|(($2&7)<<2); chkr($2);
						} else
						if ($4 > 0 && $4 < (1<<13)) {
							int v;

							emit(0x6001 | ((7)<<7) | luioff(($4<<2)&0xff00,0));
							v = $4&0x3f;
							if (v&(1<<5))
								v |= (~0)<<5;
							$$ = 0xc000|($6<<7)|roffX(v)|(($2&7)<<2); chkr($2);
						} else {
							emit_err("constant must be >= -32 and < 32768");
							$$ = 0;
						}
					  }}
	|	t_sw r ',' '(' rm ')'	{ if ($5 == 7) {
						$$ = 0xa000|(($2&7)<<7); chkr($2);
					   } else {
						$$ = 0xc000|($5<<7)|(($2&7)<<2); chkr($2);
					  }}
	|	t_sb r ',' exp '(' rm ')'{ if ($6 == 7) {
						if ($4 <= -128 || $4 > 128) {
							int x = $4;
							emit(0x6001 | ((7)<<7) | luioff(x&0xff00,0));
							x &= 0xff;
							if (x&0x80)
								x |= 0xffffff00;
							$$ = 0xa002|pack_label(x, 0xff, 1)|(($2&7)<<7); chkr($2);
						} else {
							$$ = 0xa002|pack_label($4, 0xff, 1)|(($2&7)<<7); chkr($2);
						}
					    } else {
						if ($4 >= -(1<<4) && $4 < (1<<4)) {
							$$ = 0xe000|($6<<7)|roff($4)|(($2&7)<<2); chkr($2);
						} else
						if ($4 > 0 && $4 < (1<<13)) {
							int v;

							emit(0x6001 | ((7)<<7) | luioff(($4<<3)&0xff00,0));
							v = $4&0x1f;
							if (v&(1<<4))
								v |= (~0)<<4;
							$$ = 0xe000|($6<<7)|roff(v)|(($2&7)<<2); chkr($2);
						} else {
							emit_err("constant must be >= -16 and < 16384");
							$$ = 0;
						}
					 }}
	|	t_sb r ',' '(' rm ')'	 { if ($6 == 7) {
						$$ = 0xa002|(($2&7)<<7); chkr($2);
					 } else {
						$$ = 0xe000|($5<<7)|roff(0)|(($2&7)<<2); chkr($2);
					 }}
	|	t_lea rm ',' exp '(' t_sp ')' { $$ = 0x0000 | ($2<<2) | zoffX($4); }
	|	t_lea rm ',' '(' t_sp ')'{ $$ = 0x0000 | ($2<<2) | zoffX(0); }
	|	t_lui    r ',' exp	{ $$ = 0x6001 | (($2)<<7) | luioff($4,0); }	
	|	t_la     rm ',' exp	{ if (simple_li($4)) { $$ = 0x4001 | ($2<<7) | lioff($4); } else
						{
							int delta = $4&0xffff;
							if (delta&0x80) {
                                                		delta = (delta&~0xff)+0x100;
                                        		} else {
                                                		delta = delta&~0xff;
                                        		}
						 	emit(0x6001|((8|$2)<<7)|luioff(delta&0xff00, 0));
							delta = ($4)&0xff;
                                			if (delta&0x80)
                                        			delta = -(0x100-delta);
							$$ = 0x0001 | ($2<<7) | imm8(delta, 0);
						}}
	|	t_li	rm ',' t_name '-' t_name { unsigned short a=ref_label($4, 10, 0), b= ref_label($6, 10, 0);
							a = a-b;
						     if (simple_li(a)) { $$ = 0x4001 | ($2<<7) | lioff(a); } else
						{
							int delta = a&0xffff;
							if (delta&0x80) {
                                                		delta = (delta&~0xff)+0x100;
                                        		} else {
                                                		delta = delta&~0xff;
                                        		}
						 	emit(0x6001|((8|$2)<<7)|luioff(delta&0xff00, 0));
							delta = (a)&0xff;
                                			if (delta&0x80)
                                        			delta = -(0x100-delta);
							$$ = 0x0001 | ($2<<7) | imm8(delta, 0);
						}}
	|	t_li     rm ',' exp	{ if (simple_li($4)) { $$ = 0x4001 | ($2<<7) | lioff($4); } else
						{
							int  delta = $4&0xffff;
							if (delta&0x80) {
                                                		delta = (delta&~0xff)+0x100;
                                        		} else {
                                                		delta = delta&~0xff;
                                        		}
						 	emit(0x6001|((8|$2)<<7)|luioff(delta&0xff00, 0));
							delta = ($4)&0xff;
                                			if (delta&0x80)
                                        			delta = -(0x100-delta);
							$$ = 0x0001 | ($2<<7) | imm8(delta, 0);
						}}
	|	t_la     rx ',' exp	{ 
							int  delta = $4&0xffff;
							if (delta&0x80) {
                                                		delta = (delta&~0xff)+0x100;
                                        		} else {
                                                		delta = delta&~0xff;
                                        		}
						 	emit(0x6001|(($2)<<7)|luioff(delta&0xff00, 0));
							delta = ($4)&0xff;
                                			if (delta&0x80)
                                        			delta = -(0x100-delta);
							$$ = 0x2002 | ($2<<7) | imm8(delta, 0);
						}
	|	t_li     rx ',' exp	{ 
							int  delta = $4&0xffff;
							if (delta&0x80) {
                                                		delta = (delta&~0xff)+0x100;
                                        		} else {
                                                		delta = delta&~0xff;
                                        		}
						 	emit(0x6001|(($2)<<7)|luioff(delta&0xff00, 0));
							delta = ($4)&0xff;
                                			if (delta&0x80)
                                        			delta = -(0x100-delta);
							$$ = 0x2002 | ($2<<7) | imm8(delta, 0);
						}
	|	t_beqz	rm ',' t_name	{if (is_short_branch($4, 0)) {$$ = 0xc001 | ($2<<7); ref_label($4, 3, 0); } else {
						ref_label($4, 8, 0);
						emit(0x6001|(7<<7));  		/* lui mul, X */
						$$ = 0xc001 | ($2<<7);     	/* beq X */
					}}
	|	t_bnez	rm ',' t_name	{if (is_short_branch($4, 0)) {$$ = 0xe001 | ($2<<7); ref_label($4, 3, 0); } else {
						ref_label($4, 8, 0);
						emit(0x6001|(7<<7));  		/* lui mul, X */
						$$ = 0xe001 | ($2<<7);	      	/* bne X */
					}}
	|	t_bltz	rm ',' t_name	{if (is_short_branch($4, 0)) {$$ = 0xe003 | ($2<<7); ref_label($4, 3, 0); } else {
						ref_label($4, 8, 0);
						emit(0x6001|(7<<7));  		/* lui mul, X */
						$$ = 0xe003 | ($2<<7);	      	/* bltz X */
					}}
	|	t_bgez	rm ',' t_name	{if (is_short_branch($4, 0)) {$$ = 0xc003 | ($2<<7); ref_label($4, 3, 0); } else {
						ref_label($4, 8, 0);
						emit(0x6001|(7<<7));  		/* lui mul, X */
						$$ = 0xc003 | ($2<<7);	      	/* bgez X */
					}}
	|	t_bgtz	rm ',' t_name	{if (is_short_branch($4, 1)) {
						emit(0xc001 | ($2<<7) | 8);	// beq skip 1 ins
					 } else {
						emit(0xc001 | ($2<<7) | 16);	// beq skip 2 ins
					}
					 if (is_short_branch($4, 0)) {$$ = 0xc003 | ($2<<7); ref_label($4, 3, 0); } else {
						ref_label($4, 8, 0);
						emit(0x6001|(7<<7));  		/* lui mul, X */
						$$ = 0xc003 | ($2<<7);	      /* jalr X(lr) */
					}}
	|	t_blez	rm ',' t_name	{if (is_short_branch($4, 0)) {ref_label($4, 3, 0); emit(0xc001 | ($2<<7)); } else {
						ref_label($4, 8, 0);
						emit(0x6001|(7<<7));  		/* lui mul, X */
						emit(0xc001 | ($2<<7));	      /* jalr X(lr) */
					 }
					 if (is_short_branch($4, 0)) {$$ = 0xe003 | ($2<<7); ref_label($4, 3, 0); } else {
						ref_label($4, 8, 0);
						emit(0x6001|(7<<7));  	/* li lr, X */
						$$ = 0xe003 | ($2<<7);	      /* jalr X(lr) */
					}}
	|	t_beqz	rm ',' t_num_label { $$ = 0xc001 | ($2<<7) | ref_label($4, 7, 0); }
	|	t_bnez	rm ',' t_num_label { $$ = 0xe001 | ($2<<7) | ref_label($4, 7, 0); }
	|	t_bltz	rm ',' t_num_label { $$ = 0xe003 | ($2<<7) | ref_label($4, 7, 0); }
	|	t_bgez	rm ',' t_num_label { $$ = 0xc003 | ($2<<7) | ref_label($4, 7, 0); }
	|	t_bgtz	rm ',' t_num_label { emit(0xc001 | ($2<<7) | 8); $$ = 0xe003 | ($2<<7) | ref_label($4, 7, 0); }
	|	t_blez	rm ',' t_num_label { ref_label($4, 7, 0); emit(0xc001 | ($2<<7)); $$ = 0xe003 | ($2<<7) | ref_label($4, 7, 0); }
	|	t_j	t_name		{ if (is_short_jump($2)) { $$ = 0xa001; ref_label($2, 2, 0);} else {
						ref_label($2, 8, 0);
						emit(0x6001|(7<<7));    /* li mulhi, X */
						$$ = 0xa001;      	/* j X */
					} }
	|	t_jal	t_name		{ if (is_short_jump($2)) { $$ = 0x2001; ref_label($2, 2, 0);} else {
						ref_label($2, 8, 0);
						emit(0x6001|(7<<7));  /* li mulhi, X */
						$$ = 0x2001;	      /* jal */
					} }
	|	t_j	t_num_label	{ $$ = 0xa001| ref_label($2, 6, 0); }
	|	t_jal	t_num_label	{ $$ = 0x2001| ref_label($2, 6, 0); }
	|	t_sll	rm ',' rm	{ $$ = 0x9003 | ($2<<7) | ($4<<2); }
	|	t_sll	rm ',' exp	{ $$ = 0x8003 | ($2<<7) | shift_exp($4); }
	|	t_srl	rm ',' rm	{ $$ = 0x9001 | ($2<<7) | ($4<<2); }
	|	t_srl	rm ',' exp 	{ $$ = 0x8001 | ($2<<7) | shift_exp($4); }
	|	t_sra	rm ',' rm	{ $$ = 0x9401 | ($2<<7) | ($4<<2); }
	|	t_sra	rm ',' exp	{ $$ = 0x8401 | ($2<<7) | shift_exp($4); }
	|	t_la	rm ',' t_num_label 	{ ref_label($4, 4, 0); emit(0x6001|((8|$2)<<7)); $$ = 0x0001 | ($2<<7);  }
	|	t_la	rm ',' t_num_label '+' exp { ref_label($4, 4, $6); emit(0x6001|((8|$2)<<7)); $$ = 0x0001 | ($2<<7); }
	|	t_la	rm ',' t_num_label '-' exp { ref_label($4, 4, (-$6)&0xffff); emit(0x6001|((8|$2)<<7)); $$ = 0x0001 | ($2<<7); }
	|	t_la	rm ',' t_name 	{ ref_label($4, 4, 0); emit(0x6001|((8|$2)<<7)); $$ = 0x0001 | ($2<<7);  }
	|	t_la	rm ',' t_name '+' exp 	{ ref_label($4, 4, $6); emit(0x6001|((8|$2)<<7)); $$ = 0x0001 | ($2<<7); }
	|	t_la	rm ',' t_name '-' exp 	{ ref_label($4, 4, (-$6)&0xffff); emit(0x6001|((8|$2)<<7)); $$ = 0x0001 | ($2<<7); }
	|	t_la	rx ',' t_name 	{ ref_label($4, 4, 0); emit(0x6001|(($2)<<7)); $$ = 0x2002 | ($2<<7);  }
	|	t_la	rx ',' t_name '+' exp 	{ ref_label($4, 4, $6); emit(0x6001|(($2)<<7)); $$ = 0x2002 | ($2<<7); }
	|	t_la	rx ',' t_name '-' exp 	{ ref_label($4, 4, (-$6)&0xffff); emit(0x6001|(($2)<<7)); $$ = 0x2002 | ($2<<7); }
	|	t_ldio r ',' exp '(' rm ')'{ $$ = 0x4003|($6<<7)|roffIO($4)|(($2&7)<<2); chkr($2); }
	|	t_ldio r ',' '(' rm ')'	{ $$ = 0x4003|($5<<7)|roffIO(0)|(($2&7)<<2); chkr($2); }
	|	t_stio r ',' exp '(' rm ')'{ $$ = 0x2003|($6<<7)|roffIO($4)|(($2&7)<<2); chkr($2); }
	|	t_stio r ',' '(' rm ')'	{ $$ = 0x2003|($5<<7)|roffIO(0)|(($2&7)<<2); chkr($2); }
	|	t_flush	'(' rm ')'	{ $$ = 0x9c37|($3<<7); }
	|	t_flush	cache		{ $$ = 0x0023|($2<<2); }
	|	t_invmmu exp		{ $$ = 0x0043|check_inv($2); }
	;

cache:		t_icache		{ $$ = 2; }
	|	t_dcache		{ $$ = 1; }
	|	t_dcache t_icache	{ $$ = 3; }
	|	t_icache t_dcache	{ $$ = 3; }


label:		t_name ':'		{ declare_label(0, $1); }
	|	t_value ':'		{ declare_label(1, $1); }
	;

inw:		ins			{ emit($1); }
	|	'.' t_word exp		{ emit_data(1, $3); }
	|	'.' t_word t_name 	{ ref_label($3, 1, 0); emit_data(1, 0); }
	|	'.' t_word t_name '+' exp { ref_label($3, 1, $5); emit_data(1, 0); }
	|	'.' t_word t_name '-' exp { ref_label($3, 1, (-$5)&0xffff); emit_data(1, 0); }
	|	'.' t_align exp		{ align($3); }
	|	'.' t_align 		{ align(2); }
	;
inb:		'.' t_space exp		{ emit_space($3); }
	|	'.' t_byte exp		{ emit_data(0, $3); }
	|	'.' t_string t_stringv	{ emit_string(); }
	|	'.' t_ascii t_stringv	{ emit_string(); }
	;
		

line:		label nl 		
	|	label inb nl	
	|	label inw nl	
	|	      inb nl		
	|	      inw nl		
	|	'.' '=' exp nl		{ set_offset(0, $3); }
	|	'.' '=' '.' '+' exp nl  { set_offset(1, $5); }
	|	'.' t_text nl		{ set_seg(0); }
	|	'.' t_data nl		{ set_seg(1); }
	|	'.' t_bss nl		{ set_seg(2); }
	|	'.' t_extern e_name_list nl
	|	'.' t_global g_name_list nl
	|	'.' t_file t_stringv nl  { set_file(); }
	|	'.' t_ident t_stringv nl  
	|	'.' t_size t_name ',' '.' '-' t_name  nl  
	|	'.' t_comm t_name ',' exp nl { make_bss(0, $3, $5); }
	|	'.' t_lcomm t_name ',' exp nl { make_bss(1, $3, $5); }
	|	nl
	;

nl :		t_nl
	|	';'
	;

e_name_list :	t_name 			{set_extern($1);}
	|	e_name_list ',' t_name	{set_extern($3);}
	;

g_name_list :	t_name 			{set_global($1);}
	|	g_name_list ',' t_name	{set_global($3);}
	;

program:	line
	|	program line
	;
