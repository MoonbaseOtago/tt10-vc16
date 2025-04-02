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

r:		rm 			{ $$ = 8|$1; }
	|	rx			{ $$ = $1; }
	;

rx: 		t_x0			{ $$ = 0; }
	|	t_lr			{ $$ = 1; }
	|	t_sp			{ $$ = 2; }
	|	t_epc			{ $$ = 3; }
	|	t_csr			{ $$ = 4; }
	|	t_mmu			{ $$ = 5; }
	|	t_stmp			{ $$ = 6; }
	|	t_mulhi			{ $$ = 7; }
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

ins:		t_and  rm ',' rm 	{ $$ = 0x6017|($2<<8)|($4<<5); }      
	|	t_or  rm ',' rm         { $$ = 0x6007|($2<<8)|($4<<5); } 
	|	t_mul  rm ',' rm        { $$ = 0xe003|($2<<8)|($4<<5); } 
	|	t_div  rm ',' rm        { $$ = 0xe007|($2<<8)|($4<<5); } 
	|	t_addb  rm ',' rm       { $$ = 0xe00b|($2<<8)|($4<<5); } 
	|	t_addbu  rm ',' rm      { $$ = 0xe00f|($2<<8)|($4<<5); } 
	|	t_swap  rm ',' rm      	{ $$ = 0xe013|($2<<8)|($4<<5); } 
	|	t_addpc  rm      	{ $$ = 0xe017|($2<<8); } 
	|	t_sext  rm      	{ $$ = 0xe037|($2<<8); } 
	|	t_zext  rm      	{ $$ = 0xe057|($2<<8); } 
	|	t_inv  rm      		{ $$ = 0xe077|($2<<8); } 
	|	t_neg  rm      		{ $$ = 0xe097|($2<<8); } 
	|	t_xor  rm ',' rm        { $$ = 0xe001|($2<<8)|($4<<5); } 
	|	t_xor  rm ',' exp       { $$ = 0xe009|($2<<8)|(($4&0xf)<<4); } 
	|	t_subc  rm ',' r        { $$ = 0x600b|($2<<8)|(($4&7)<<5)|((($4>>1)&1)<<4); } 
	|	t_addc  rm ',' r        { $$ = 0x600f|($2<<8)|(($4&7)<<5)|((($4>>1)&1)<<4); } 
	|	t_and  rm ',' exp	{
						if ($4 >= 0 && $4 < (1<<6)) {
							$$ = 0x6002|($2<<8)|($4<<2);
						} else
						if ($4 >= 0 && $4 < (1<<14)) {
							emit(0x5800 | ((7)<<8) | luioff(($4<<2)&0xff00,0));
							$$ = 0x6002|($2<<8)|(($4&0x3f)<<2);
						} else {
							emit_err("constant must be 14 bits");
							$$ = 0;
						}
					}
	|	t_or  rm ',' exp	{
						if ($4 >= 0 && $4 < (1<<6)) {
							$$ = 0xe002|($2<<8)|($4<<2);
						} else
						if ($4 >= 0 && $4 < (1<<14)) {
							emit(0x5800 | ((7)<<8) | luioff(($4<<2)&0xff00,0));
							$$ = 0xe002|($2<<8)|(($4&0x3f)<<2);
						} else {
							emit_err("constant must be 14 bits");
							$$ = 0;
						}
					}
	|	t_add  r ',' r       	{ $$ = 0xa002 | (($2&7)<<8) | ((($2>>3)&1)<<3) | (($4&7)<<5)| ((($4>>3)&1)<<4); } 
	|	t_add  r ',' exp 	{
						int v = $4;
						if (($2&8) == 0) {
							if (v >= -128 && v < 128) {
								$$ = 0x8800 | ($2<<8) | cs(v, 0xff);
							} else {
								emit(0x5800 | ((7)<<8) | luioff(v&0xff00,0));
								$$ = 0x8800 | ($2<<8) | cs(v, 0xff);
							}
						} else {
							if ($4 >= -128 && $4 < 128) {
								$$ = 0x4000|(($2&7)<<8)|cs($4, 0xff);
							} else {
								emit(0x5800 | ((7)<<8) | luioff($4&0xff00,0));
								$$ = 0x4000|(($2&7)<<8)|cs($4, 0xff);
							}
						}
					}
	|	t_sub  r ',' r       	{ $$ = 0xa003 | (($2&7)<<8) | ((($2>>3)&1)<<3) | (($4&7)<<5)| ((($4>>3)&1)<<4); } 
	|	t_sub  r ',' exp 	{
						if (($2&8) == 0) {
							int v = -$4;
							if (v >= -128 && v < 128) {
								$$ = 0x8800 | ($2<<8) | cs(v, 0xff);
							} else {
								emit(0x5800 | ((7)<<8) | luioff(v&0xff00,0));
								$$ = 0x8800 | ($2<<8) | cs(v, 0xff);
							}
						} else {
							int x = -$4;
							if (x >= -128 && x < 128) {
								$$ = 0x0001|(($2&7)<<8)|cs(x, 0xff);
							} else {
								emit(0x5800 | ((7)<<8) | luioff(x&0xff00,0));
								$$ = 0x4000|(($2&7)<<8)|cs(x, 0xff);
							}
						}
					}
	|	t_mv   r ',' r        	{ $$ = 0xa001|(($2&7)<<8)|((($2>>3)&1)<<3)|(($4&7)<<5)|((($4>>3)&1)<<4); } 
	|	t_nop  			{ $$ = 0x4000; }
	|	t_inv  		 	{ $$ = 0x0000; }
	|	t_syscall  		{ $$ = 0xe4f7; }
	|	t_swapsp  		{ $$ = 0xe5f7; }
	|	t_ebreak  		{ $$ = 0xe1f7; }
	|	t_jalr r  		{ $$ = 0xa010|(($2&7)<<8)|((($2>>3)&1)<<7); }
	|	t_jr r  		{ $$ = 0xa000|(($2&7)<<8)|((($2>>3)&1)<<7); }
	|	t_ret	  		{ $$ = 0xa000|(1<<8); }

	|	t_lw r ',' exp '(' t_sp ')'{
						if ($4 >= 0 && $4 < 512) {
							$$ = 0x9000|(($2&7)<<8)|((($2>>3)&1)<<7)|cu($4, 0xfe);
						} else {
							emit(0x5800 | ((7)<<8) | luioff($4&0xff00,0));
							$$ = 0x9000|(($2&7)<<8)|((($2>>3)&1)<<7)|cu($4,0xfe);
						}
					}
	|	t_lw r ',' '(' t_sp ')'	{ $$ = 0x9000|(($2&7)<<8)|((($2>>3)&1)<<7); }

	|	t_lw r ',' t_name '+' exp{ 
						chkr($2);
						ref_label($4, 10, $6);
						emit(0x5800 | ((7)<<8));
						$$ = 0x8000|(($2&7)<<8);
				        }
	|	t_lw r ',' t_name '-' exp{ 
						chkr($2);
						ref_label($4, 10, (-$6)&0xffff);
						emit(0x5800 | ((7)<<8));
						$$ = 0x8000|(($2&7)<<8);
				        }
	|	t_lw r ',' t_name	{ 
						chkr($2);
						ref_label($4, 10, 0);
						emit(0x5800 | ((7)<<8));
						$$ = 0x8000|(($2&7)<<8);
				        }
	|	t_lw r ',' exp		{
						chkr($2);
					  	if ($4 >= -256 && $4 < 256) {
							$$ = 0x8000|($2&7)<<8|cs($4, 0x1fe);
					  	} else {
							emit(0x5800 | ((7)<<8) | luioff($4&0xff00,0));
							$$ = 0x8000|(($2&7)<<8)|cs($4, 0x1fe);
					  	}
				        }
	|	t_lb r ',' t_name '+' exp{ 
						chkr($2);
						ref_label($4, 11, $6);
						emit(0x5800 | ((7)<<8));
						$$ = 0x9800|(($2&7)<<8);
				        }
	|	t_lb r ',' t_name '-' exp{ 
						chkr($2);
						ref_label($4, 11, (-$6)&0xffff);
						emit(0x5800 | ((7)<<8));
						$$ = 0x9800|(($2&7)<<8);
				        }
	|	t_lb r ',' t_name	{ 
						chkr($2);
						ref_label($4, 11, 0);
						emit(0x5800 | ((7)<<8));
						$$ = 0x9800|(($2&7)<<8);
				        }
	|	t_lb r ',' exp		{
						chkr($2);
						if ($4 >= -128 && $4 < 128) {
							$$ = 0x9800|(($2&7)<<8)|cs($4, 0xff); 
					  	} else {
							emit(0x5800 | ((7)<<8) | luioff($4&0xff00,0));
							$$ = 0x9800|(($2&7)<<8)|cs($4, 0xff); 
					  	}
					}
	|	t_lw r ',' exp '(' rm ')'{
						chkr($2);
						if ($6 == 7) {
							if ($4 <= -256 || $4 > 256) {
								int x = $4;
								emit(0x5800 | ((7)<<8) | luioff($4&0xff00,0));
								$$ = 0x0800|cs(x, 0x1fe)|(($2&7)<<8);
							} else {
								$$ = 0x0800|cs($4, 0x1fe)|(($2&7)<<8);
							}
					 	} else {
							if ($4 >= -(1<<5) && $4 < (1<<5)) {
								$$ = 0x1000|($6<<5)|cs($4, 0x3e)|(($2&7)<<8);
							} else
							if ($4 > 0 && $4 < (1<<13)) {
								emit(0x5800 | ((7)<<8) | luioff(($4<<2)&0xff00,0));
								$$ = 0x1000|($6<<5)|cs($4, 0x3e)|(($2&7)<<8);
							} else {
								emit_err("constant must be >= -32 and < 32768");
								$$ = 0;
							}
						}
					}
	|	t_lw r ',' '(' rm ')'	{
						chkr($2);
						if ($5==7) {
							$$ = 0x0800|(($2&7)<<8);  
					  	} else {
							$$ = 0x1000|($5<<5)|(($2&7)<<8); 
						}
					}
	|	t_lb r ',' exp '(' rm ')'{
						chkr($2);
						if ($6==7) { 
							if ($4 <= -128 || $4 > 128) {
								int x = $4;
								emit(0x5800 | ((7)<<8) | luioff(x&0xff00,0));
								$$ = 0xe800|cs(x, 0xff)|(($2&7)<<8);
							} else {
								$$ = 0xe800|cs($4, 0xff)|(($2&7)<<8);
							}
					 	} else {
							if ($4 >= -(1<<4) && $4 < (1<<4)) {
								$$ = 0x1800|($6<<5)|cs($4, 0x1f)|(($2&7)<<8); 
							} else
							if ($4 > 0 && $4 < (1<<13)) {
								emit(0x5800 | ((7)<<8) | luioff(($4<<3)&0xff00,0));
								$$ = 0x1800|($6<<5)|cs($4, 0x1f)|(($2&7)<<8); 
							} else {
								emit_err("constant must be >= -16 and < 16384");
								$$ = 0;
							}
					 	}
					}
	|	t_lb r ',' '(' rm ')'	{
						chkr($2);
						if ($5==7) {
						 	$$ = 0x3800|(($2&7)<<8); 
						} else {
						 	$$ = 0x1800|($5<<5)|(($2&7)<<8);
						}
					}
	|	t_sw r ',' exp '(' t_sp ')'{
						if ($4 >= 0 && $4 < 512) {
							$$ = 0xb000|(($2&7)<<8)|((($2>>3)&1)<<7)|cu($4, 0xfe);
						} else {
							emit(0x5800 | ((7)<<8) | luioff($4&0xff00,0));
							$$ = 0xb000|(($2&7)<<8)|((($2>>3)&1)<<7)|cu($4, 0xfe);
						}
					}
	|	t_sw r ',' '(' t_sp ')'	{ $$ = 0xb000|(($2&7)<<8)|((($2>>3)&1)<<7); }

	|	t_sw r ',' t_name '+' exp	{ 
						chkr($2);
						ref_label($4, 10, $6);
						emit(0x5800 | ((7)<<8));
						$$ = 0x2000|($2<<8);
				        }
	|	t_sw r ',' t_name '-' exp	{ 
						chkr($2);
						ref_label($4, 10, (-$6)&0xffff);
						emit(0x5800 | ((7)<<8));
						$$ = 0x2000|($2<<8);
				        }
	|	t_sw r ',' t_name	{ 
						chkr($2);
						ref_label($4, 10, 0);
						emit(0x5800 | ((7)<<8));
						$$ = 0x2000|($2<<8);
				        }
	|	t_sw r ',' exp		{
						chkr($2);
						if ($4 >= -256 && $4 < 256) {
							$$ = 0x2000|(($2&7)<<8)|cs($4, 0x1fe); 
					  	} else {
							emit(0x5800 | ((7)<<8) | luioff($4&0xff00,0));
							$$ = 0x2000|(($2&7)<<8)|cs($4, 0x1fe); 
				  		}
					}
	|	t_sb r ',' t_name '+' exp{ 
						chkr($2);
						ref_label($4, 11, $6);
						emit(0x5800 | ((7)<<8));
						$$ = 0xb800|(($2&7)<<8);
				        }
	|	t_sb r ',' t_name '-' exp{ 
						chkr($2);
						ref_label($4, 11, (-$6)&0xffff);
						emit(0x5800 | ((7)<<8));
						$$ = 0xb800|(($2&7)<<8);
				        }
	|	t_sb r ',' t_name	{ 
						chkr($2);
						ref_label($4, 11, 0);
						emit(0x5800 | ((7)<<8));
						$$ = 0xb800|(($2&7)<<8);
				        }
	|	t_sb r ',' exp		{
						chkr($2);
						if ($4 >= -128 && $4 < 128) {
							$$ = 0xb800|(($2&7)<<8)|cs($4, 0xff);
					  	} else {
							emit(0x5800 | ((7)<<8) | luioff($4&0xff00,0));
							$$ = 0xb800|(($2&7)<<8)|cs($4, 0xff);
					  	}
					}
	|	t_sw r ',' exp '(' rm ')'{
						chkr($2);
						if ($6 == 7) {
							if ($4 <= -256 || $4 > 256) {
								emit(0x5800 | ((7)<<8) | luioff($4&0xff00,0));
								$$ = 0x2800|cs($4, 0x1fe)|(($2&7)<<8); 
							} else {
								$$ = 0x2800|cs($4, 0x1fe)|(($2&7)<<8);
							}
					   	} else {
							if ($4 >= -(1<<5) && $4 < (1<<5)) {
								$$ = 0x3000|($6<<5)|cs($4, 0x3e)|(($2&7)<<8);
							} else
							if ($4 > 0 && $4 < (1<<13)) {
								emit(0x5800 | ((7)<<8) | luioff(($4<<2)&0xff00,0));
								$$ = 0x3000|($6<<5)|cs($4, 0x3e)|(($2&7)<<8);
							} else {
								emit_err("constant must be >= -32 and < 32768");
								$$ = 0;
							}
					  	}
					}
	|	t_sw r ',' '(' rm ')'	{	
						chkr($2);
						if ($5 == 7) {
							$$ = 0x2800|(($2&7)<<8);
					   	} else {
							$$ = 0x3000|($5<<5)|(($2&7)<<8);
					  	}
					}
	|	t_sb r ',' exp '(' rm ')'{
						chkr($2);
						if ($6 == 7) {
							if ($4 <= -128 || $4 > 128) {
								int x = $4;
								emit(0x5800 | ((7)<<8) | luioff(x&0xff00,0));
								$$ = 0xa800|cs(x, 0xff)|(($2&7)<<8);;
							} else {
								$$ = 0xa800|cs($4, 0xff)|(($2&7)<<8);
							}
					    	} else {
							if ($4 >= -(1<<4) && $4 < (1<<4)) {
								$$ = 0x3800|($6<<5)|cs($4, 0x1f)|(($2&7)<<8); 
							} else
							if ($4 > 0 && $4 < (1<<13)) {
								emit(0x5800 | ((7)<<8) | luioff(($4<<3)&0xff00,0));
								$$ = 0x3800|($6<<5)|cs($4, 0x1f)|(($2&7)<<8); 
							} else {
								emit_err("constant must be >= -16 and < 16384");
								$$ = 0;
							}
					 	}
					}
	|	t_sb r ',' '(' rm ')'	{
						chkr($2);
						if ($6 == 7) {
							$$ = 0xa800|(($2&7)<<8); 
					 	} else {
							$$ = 0x3900|($5<<5)|(($2&7)<<8); 
					 	}
					}
	|	t_lea rm ',' exp '(' t_sp ')' {	if ($4 == 0) {
							$$ = 0xa049|($2<<8);
						} else {
							if ($4 >= -256 && $4 < 256) {
								$$ = 0x0000 | ($2<<8) | cs($4, 0x1fe);
							} else {
								emit(0x5800 | ((7)<<8) | luioff(($4<<3)&0xff00,0));
								$$ = 0x0000 | ($2<<8) | cs($4, 0x1fe);
							}
						}
					 }
	|	t_lea rm ',' '(' t_sp ')'{ $$ = 0xa049|($2<<8);}
	|	t_lui    r ',' exp	{ $$ = 0x5800 | (($2&7)<<8) | ((($2>>3)&1)<<7) | luioff($4&0xff00,0); }	
	|	t_la     rm ',' exp	{ if (simple_li($4)) { $$ = 0x5000 | ($2<<8) | cs($4, 0xff); } else
						{
							int delta = $4&0xffff;
							if (delta&0x80) {
                                                		delta = (delta&~0xff)+0x100;
                                        		} else {
                                                		delta = delta&~0xff;
                                        		}
						 	emit(0x5880|(($2|8)<<8)|luioff(delta&0xff00, 0));
							$$ = 0x4000 | ($2<<8) | cs($4,0xff);
						}}
	|	t_li	rm ',' t_name '-' t_name { unsigned short a=ref_label($4, 10, 0), b= ref_label($6, 10, 0);
							a = a-b;
						     if (simple_li(a)) { $$ = 0x5000 | ($2<<8) | cs(a, 0xff); } else
						{
							int delta = a&0xffff;
							if (delta&0x80) {
                                                		delta = (delta&~0xff)+0x100;
                                        		} else {
                                                		delta = delta&~0xff;
                                        		}
						 	emit(0x5880|(($2)<<8)|luioff(delta&0xff00, 0));
							delta = (a)&0xff;
                                			if (delta&0x80)
                                        			delta = -(0x100-delta);
							$$ = 0x4000 | ($2<<8) | cs(delta, 0xff);
						}}
	|	t_li     rm ',' exp	{ if (simple_li($4)) { $$ = 0x5000 | ($2<<8) | cs($4, 0xff); } else
						{
							int  delta = $4&0xffff;
							if (delta&0x80) {
                                                		delta = (delta&~0xff)+0x100;
                                        		} else {
                                                		delta = delta&~0xff;
                                        		}
						 	emit(0x5880|(($2)<<8)|luioff(delta&0xff00, 0));
							delta = ($4)&0xff;
                                			if (delta&0x80)
                                        			delta = -(0x100-delta);
							$$ = 0x4000 | ($2<<8) | cs(delta, 0xff);
						}}
	|	t_la     rx ',' exp	{ 
							int  delta = $4&0xffff;
							if (delta&0x80) {
                                                		delta = (delta&~0xff)+0x100;
                                        		} else {
                                                		delta = delta&~0xff;
                                        		}
						 	emit(0x5800|(($2)<<8)|luioff(delta&0xff00, 0));
							delta = ($4)&0xff;
                                			if (delta&0x80)
                                        			delta = -(0x100-delta);
							$$ = 0x4000 | ($2<<8) | cs(delta, 0xff);
						}
	|	t_li     rx ',' exp	{ 
							int  delta = $4&0xffff;
							if (delta&0x80) {
                                                		delta = (delta&~0xff)+0x100;
                                        		} else {
                                                		delta = delta&~0xff;
                                        		}
						 	emit(0x5800|(($2)<<8)|luioff(delta&0xff00, 0));
							delta = ($4)&0xff;
                                			if (delta&0x80)
                                        			delta = -(0x100-delta);
							$$ = 0x4000 | ($2<<8) | cs(delta, 0xff);
						}
	|	t_beqz	rm ',' t_name	{if (is_short_branch($4, 0)) {$$ = 0x7000 | ($2<<8); ref_label($4, 3, 0); } else {
						ref_label($4, 8, 0);
						emit(5800|(7<<8));  		/* lui mul, X */
						$$ = 0x7000 | ($2<<8);     	/* beq X */
					}}
	|	t_bnez	rm ',' t_name	{if (is_short_branch($4, 0)) {$$ = 0x7800 | ($2<<8); ref_label($4, 3, 0); } else {
						ref_label($4, 8, 0);
						emit(0x5800|(7<<8));  		/* lui mul, X */
						$$ = 0x7800 | ($2<<8);	      	/* bne X */
					}}
	|	t_bltz	rm ',' t_name	{if (is_short_branch($4, 0)) {$$ = 0xf800 | ($2<<8); ref_label($4, 3, 0); } else {
						ref_label($4, 8, 0);
						emit(0x5800|(7<<9));  		/* lui mul, X */
						$$ = 0xf800 | ($2<<8);	      	/* bltz X */
					}}
	|	t_bgez	rm ',' t_name	{if (is_short_branch($4, 0)) {$$ = 0xf000 | ($2<<8); ref_label($4, 3, 0); } else {
						ref_label($4, 8, 0);
						emit(0x5800|(7<<8));  		/* lui mul, X */
						$$ = 0xf000 | ($2<<8);	      	/* bgez X */
					}}
	|	t_bgtz	rm ',' t_name	{if (is_short_branch($4, 1)) {
						emit(0x7000 | ($2<<8) | 1);	// beq skip 1 ins
					 } else {
						emit(0x7000 | ($2<<8) | 2);	// beq skip 2 ins
					}
					 if (is_short_branch($4, 0)) {$$ = 0xf000 | ($2<<8); ref_label($4, 3, 0); } else {
						ref_label($4, 8, 0);
						emit(0x5800|(7<<8));  		/* lui mul, X */
						$$ = 0xf000 | ($2<<8);	      /* jalr X(lr) */
					}}
	|	t_blez	rm ',' t_name	{if (is_short_branch($4, 0)) {ref_label($4, 3, 0); emit(0x7000 | ($2<<8)); } else {
						ref_label($4, 8, 0);
						emit(0x5800|(7<<8));  		/* lui mul, X */
						emit(0x7000 | ($2<<8));	      /* jalr X(lr) */
					 }
					 if (is_short_branch($4, 0)) {$$ = 0xf800 | ($2<<8); ref_label($4, 3, 0); } else {
						ref_label($4, 8, 0);
						emit(0x5800|(7<<8));  	/* li lr, X */
						$$ = 0xf800 | ($2<<8);	      /* jalr X(lr) */
					}}
	|	t_beqz	rm ',' t_num_label { $$ = 0x7000 | ($2<<8) | ref_label($4, 7, 0); }
	|	t_bnez	rm ',' t_num_label { $$ = 0x7800 | ($2<<8) | ref_label($4, 7, 0); }
	|	t_bltz	rm ',' t_num_label { $$ = 0xf800 | ($2<<8) | ref_label($4, 7, 0); }
	|	t_bgez	rm ',' t_num_label { $$ = 0xf000 | ($2<<8) | ref_label($4, 7, 0); }
	|	t_bgtz	rm ',' t_num_label { emit(0x7000 | ($2<<8) | 1); $$ = 0xf000 | ($2<<8) | ref_label($4, 7, 0); }
	|	t_blez	rm ',' t_num_label { ref_label($4, 7, 0); emit(0x6000 | ($2<<8)); $$ = 0xf800 | ($2<<8) | ref_label($4, 7, 0); }
	|	t_j	t_name		{ if (is_short_jump($2)) { $$ = 0x6800; ref_label($2, 2, 0);} else {
						ref_label($2, 8, 0);
						emit(0x5800|(7<<8));    /* li mulhi, X */
						$$ = 0x6800;      	/* j X */
					} }
	|	t_jal	t_name		{ if (is_short_jump($2)) { $$ = 0x4800; ref_label($2, 2, 0);} else {
						ref_label($2, 8, 0);
						emit(0x5800|(7<<8));  /* li mulhi, X */
						$$ = 0x4800;	      /* jal */
					} }
	|	t_j	t_num_label	{ $$ = 0x6800| ref_label($2, 6, 0); }
	|	t_jal	t_num_label	{ $$ = 0x4800| ref_label($2, 6, 0); }
	|	t_sll	rm ',' rm	{ $$ = 0xe000 | ($2<<8) | ($4<<5); }
	|	t_sll	rm ',' exp	{ $$ = 0xe008 | ($2<<8) | (($4&0xf)<<4); }
	|	t_srl	rm ',' rm	{ $$ = 0x6000 | ($2<<8) | ($4<<5); }
	|	t_srl	rm ',' exp 	{ $$ = 0x6008 | ($2<<8) | (($4&0xf)<<4); }
	|	t_sra	rm ',' rm	{ $$ = 0x6001 | ($2<<8) | ($4<<5); }
	|	t_sra	rm ',' exp	{ $$ = 0x6009 | ($2<<8) | (($4&0xf)<<4); }

	|	t_la	rm ',' t_num_label 	{ ref_label($4, 4, 0); emit(0x5880|(($2)<<8)); $$ = 0x4000 | ($2<<8);  }
	|	t_la	rm ',' t_num_label '+' exp { ref_label($4, 4, $6); emit(0x5880|(($2)<<8)); $$ = 0x4000 | ($2<<8); }
	|	t_la	rm ',' t_num_label '-' exp { ref_label($4, 4, (-$6)&0xffff); emit(0x5880|(($2)<<8)); $$ = 0x4000 | ($2<<8); }
	|	t_la	rm ',' t_name 	{ ref_label($4, 4, 0); emit(0x5880|(($2)<<8)); $$ = 0x4000 | ($2<<8);  }
	|	t_la	rm ',' t_name '+' exp 	{ ref_label($4, 4, $6); emit(0x5880|(($2)<<8)); $$ = 0x4000 | ($2<<8); }
	|	t_la	rm ',' t_name '-' exp 	{ ref_label($4, 4, (-$6)&0xffff); emit(0x5880|(($2)<<8)); $$ = 0x4000 | ($2<<8); }
	|	t_la	rx ',' t_name 	{ ref_label($4, 4, 0); emit(0x5800|(($2)<<8)); $$ = 0x8800 | ($2<<8);  }
	|	t_la	rx ',' t_name '+' exp 	{ ref_label($4, 4, $6); emit(0x5800|(($2)<<8)); $$ = 8800 | ($2<<8); }
	|	t_la	rx ',' t_name '-' exp 	{ ref_label($4, 4, (-$6)&0xffff); emit(0x5800|(($2)<<8)); $$ = 0x8800 | ($2<<8); }
	|	t_ldio rm ',' exp '(' rm ')'{ $$ = 0xd000|($6<<5)|cs($4, 0x3e)|($2<<8); }
	|	t_ldio rm ',' '(' rm ')'    { $$ = 0xd000|($5<<5)|($2<<8); }
	|	t_stio rm ',' exp '(' rm ')'{ $$ = 0xc800|($6<<5)|cs($4, 0x3e)|($2<<8); }
	|	t_stio rm ',' '(' rm ')'    { $$ = 0xc800|($5<<5)|($2<<8); }
	|	t_flush	'(' rm ')'	{ $$ = 0xe0b7|($3<<8); }
	|	t_flush	cache		{ $$ = 0xe0fb|($2<<8); }
	|	t_invmmu exp		{ $$ = 0xa004|check_inv($2)<<3; }
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
