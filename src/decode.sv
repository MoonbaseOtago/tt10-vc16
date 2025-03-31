`define MULT 1
//
//	(C) Paul Campbell Moonbase Otago 2023-2024
//	All Rights Reserved
//

`define OP_ADD	0
`define OP_SUB	1
`define OP_XOR	2
`define OP_OR	3
`define OP_AND	4
`define OP_SLL	5
`define OP_SRA	6
`define OP_SRL	7
`define OP_ADDB	8
`define OP_ADDBU 9
`define OP_SWAP 10

module decode(input clk, input reset,
	    input [15:0]ins, 
		input idone,
		input supmode,
		input user_io,

		output iready,
		output jmp,
		output br, 
		output [2:0]cond,
		output trap,
		output sys_call,
		output swapsp,
		output load,
		output store, 
		output io, 
		output do_flush_all, 
		output do_flush_write, 
		output do_inv_mmu, 
		output load_lui_hi,
		output set_cc, 
		output use_lui_hi,
		output [1:0]lui_hi_type,
`ifdef MULT
		output mult,
		output div,
`endif
		output [3:0]op,
		output [3:0]rs1, output[3:0]rs2, output [3:0]rd,
		output needs_rs2, 
		output rs2_pc, 
		output rs2_inv, 
		output [RV-1:0]imm);

	parameter RV=32;	// register width

	reg		r_ready; assign iready = r_ready;
	always @(posedge clk)
		r_ready <= idone&!reset;
	reg		r_trap, c_trap; assign trap = r_trap;
	reg		r_sys_call, c_sys_call; assign sys_call = r_sys_call;
	reg		r_swapsp, c_swapsp; assign swapsp = r_swapsp;
	reg		r_load, c_load; assign load = r_load;
	reg		r_io, c_io; assign io = r_io;
	reg		r_store, c_store; assign store = r_store;
	reg[2:0]r_cond, c_cond; assign cond = r_cond;
	reg		r_jmp, c_jmp; assign jmp = r_jmp;
	reg		r_br, c_br; assign br = r_br;
	reg[3:0]r_op, c_op; assign op = r_op;
	reg[3:0]r_rs1, c_rs1; assign rs1 = r_rs1;
	reg[3:0]r_rs2, c_rs2; assign rs2 = r_rs2;
	reg[3:0]r_rd, c_rd; assign rd = r_rd;
	reg		r_needs_rs2, c_needs_rs2; assign needs_rs2 = r_needs_rs2;
	reg		r_rs2_pc, c_rs2_pc; assign rs2_pc = r_rs2_pc;
	reg		r_rs2_inv, c_rs2_inv; assign rs2_inv = r_rs2_inv;
	reg[RV-1:0]r_imm, c_imm; assign imm = r_imm;
`ifdef MULT
	reg		r_mult, c_mult; assign mult = r_mult;
	reg		r_div, c_div; assign div = r_div;
`endif
	reg		r_flush_all, c_flush_all; assign do_flush_all = r_flush_all;
	reg		r_flush_write, c_flush_write; assign do_flush_write = r_flush_write;
	reg		r_inv_mmu, c_inv_mmu; assign do_inv_mmu = r_inv_mmu;
	reg		r_set_cc, c_set_cc; assign set_cc = r_set_cc;
	reg		r_load_lui_hi, c_load_lui_hi; assign load_lui_hi = r_load_lui_hi;
	reg		r_use_lui_hi, c_use_lui_hi; assign use_lui_hi = r_use_lui_hi;
	reg[1:0]r_lui_hi_type, c_lui_hi_type; assign lui_hi_type = r_lui_hi_type;

	always @(*) begin
		c_use_lui_hi = 0;
		c_lui_hi_type = 2'bx;
		c_flush_all = 0;
		c_flush_write = 0;
		c_trap = 0;
		c_load = 0;
		c_io = 0;
		c_store = 0;
		c_cond = 3'bx;
		c_needs_rs2 = 0;
		c_op = 4'bx;
		c_rs1 = 4'bx;
		c_rs2 = 4'bx;
		c_rd = 4'h0;
		c_jmp = 0;
		c_br = 0;
		c_sys_call = 0;
		c_swapsp = 0; 
		c_rs2_pc = 0;
		c_rs2_inv = 0;
		c_inv_mmu = 0;
		c_set_cc = 0;
		c_load_lui_hi = 0;
`ifdef MULT
		c_mult = 0;
		c_div = 0;
`endif
		c_rd = {1'b1, ins[10:8]};
		c_rs1 = {1'b1, ins[7:5]};
		c_rs2 = {1'b1, ins[10:8]};
		c_imm = 16'bx;
		casez (ins[15:11]) // synthesis full_case parallel_case
		5'b00_000: begin	// addi4sp
						c_op = `OP_ADD;
						c_use_lui_hi = 1;
						c_lui_hi_type = 0;
						c_rs1 = 2;
						c_trap = ins[10:0]==0;	// 0 instruction is trap
						c_imm = {{(RV-8){ins[0]}}, ins[7:1],1'b0};
					end
		5'b00_001: begin 	// lw7
						c_load = 1;
						c_op = `OP_ADD;
						c_cond = 3'bxx0;
						c_rs1 = {1'b1, 3'b111};
						c_use_lui_hi = 1;
						c_lui_hi_type = 0;
						c_imm = {{(RV-8){ins[0]}}, ins[7:1],1'b0};
				    end
		5'b00_010: begin 	// lw
						c_load = 1;
						c_op = `OP_ADD;
						c_cond = 3'bxx0;
						c_trap = c_rs1 == 7;
						c_use_lui_hi = 1;
						c_lui_hi_type = 2;
						c_imm = {{(RV-5){ins[0]}}, ins[4:1],1'b0};
				    end
		5'b00_011: begin 	// lb
						c_load = 1;
						c_op = `OP_ADD;
						c_cond = 3'bxx1;
						c_trap = c_rs1 == 7;
						c_use_lui_hi = 1;
						c_lui_hi_type = 1;
						c_imm = {{(RV-5){ins[4]}}, ins[4:0]};
					end
		5'b00_100: begin 	// sw name
						c_store = 1;
						c_cond = 3'bxx0;
						c_op = `OP_ADD;
						c_rs1 = 0;
						c_use_lui_hi = 1;
						c_lui_hi_type = 0;
						c_imm = {{(RV-8){ins[0]}}, ins[7:1],1'b0};
					end
		5'b00_101: begin 	// sw7
						c_store = 1;
						c_cond = 3'bxx0;
						c_op = `OP_ADD;
						c_rs1 = {1'b1, 3'b111};
						c_use_lui_hi = 1;
						c_lui_hi_type = 0;
						c_imm = {{(RV-8){ins[0]}}, ins[7:1],1'b0};
					end
		5'b00_110: begin 	// sw
						c_store = 1;
						c_cond = 3'bxx0;
						c_op = `OP_ADD;
						c_trap = c_rs1 == 7;
						c_use_lui_hi = 1;
						c_lui_hi_type = 2;
						c_imm = {{(RV-5){ins[0]}}, ins[4:1],1'b0};
					end
		5'b00_111: begin 	// sb
						c_store = 1;
						c_cond = 3'bxx1;
						c_op = `OP_ADD;
						c_trap = c_rs1 == 7;
						c_use_lui_hi = 1;
						c_lui_hi_type = 1;
						c_imm = {{(RV-5){ins[4]}}, ins[4:0]};
					end
		5'b01_000:	begin	// addi **
						c_op = `OP_ADD;
						c_rs1 = c_rd;
						c_use_lui_hi = 1;
						c_lui_hi_type = 0;
						c_imm = {{(RV-8){ins[7]}}, ins[7:0]};
					end
		5'b01_001:	begin	// jal
						c_br = 1;
						c_cond = 3'b1x1;
						c_op = `OP_ADD;
						c_use_lui_hi = 1;
						c_lui_hi_type = 0;
						c_rd = 1;
						c_rs1 = 0;
						c_imm = {{(RV-11){ins[0]}}, ins[10:1],1'b0};
					end
		5'b01_010:	begin	// li
						c_op = `OP_ADD;
						c_rs1 = 0;
						c_imm = {{(RV-8){ins[7]}}, ins[7:0]};
					end
		5'b01_011:	begin	// lui
						c_op = `OP_ADD;
						c_rd[3] = ins[7];
						c_rs1 = 0;
						c_load_lui_hi = c_rd == 4'b0111;
						c_trap = !supmode && (c_rd >= 4'b0011 && c_rd <= 4'b0110);
						c_imm = {1'b0, ins[6:0], 8'b0};
					end
		5'b01_100:	begin
						c_rs1 = {1'b1, ins[10:8]};
						c_rs2 = {1'b1, ins[7:5]};
						case (ins[1:0]) // synthesis full_case parallel_case
						2'b00: begin	
									c_op = `OP_SRL;
									c_needs_rs2 = !ins[3];
									c_imm = {12'bx, ins[7:4]};
									c_trap = ins[2] || (!ins[3] &&  ins[4]);
							   end
						2'b01: begin
									c_op = `OP_SRA; 
									c_needs_rs2 = !ins[3];
									c_imm = {12'bx, ins[7:4]};
									c_trap = ins[2] || (!ins[3] &&  ins[4]);
							   end
						2'b10: begin
									c_op = `OP_AND;
									c_use_lui_hi = 1;
									c_lui_hi_type = 2;
									c_imm = {10'b0, ins[7:2]};
							   end
						2'b11: begin
								c_needs_rs2 = 1;
								casez ({ins[4:2]}) // synthesis full_case parallel_case
								3'b?_00:	begin // free
												c_trap = 1;
											end
								3'b0_01:	c_op = `OP_OR;
								3'b1_01:	c_op = `OP_AND;
								3'b?_10:	begin
												c_rs2[3] = ins[4];
												c_op = `OP_SUB;
												c_set_cc = 1;
												c_trap = !supmode && (c_rs2 >= 4'b0011 && c_rs2 <= 4'b0110);
											end
								3'b?_11:	begin
												c_rs2[3] = ins[4];
												c_op = `OP_ADD;
												c_set_cc = 1;
												c_trap = !supmode && (c_rs2 >= 4'b0011 && c_rs2 <= 4'b0110);
											end
								default: c_trap = 1;
								endcase
							   end
						endcase
					end
		5'b01_101:	begin	// j
						c_br = 1;
						c_cond = 3'b1x0;
						c_op = `OP_ADD;
						c_use_lui_hi = 1;
						c_lui_hi_type = 0;
						c_rs1 = 0;
						c_imm = {{(RV-11){ins[0]}}, ins[10:1],1'b0};
					end
		5'b01_11?:	begin	//  beqz/bnez
						c_br = 1;
						c_cond = {2'b00, ins[11]};	// beqz/bnez
						c_op = `OP_ADD;
						c_rs1 = {1'b1, ins[10:8]};
						c_use_lui_hi = 1;
						c_lui_hi_type = 0;
						c_imm = {{(RV-8){ins[0]}}, ins[7:1],1'b0};
					end
		5'b10_000: begin 	// lw name
						c_load = 1;
						c_op = `OP_ADD;
						c_cond = 3'bxx0;
						c_rs1 = 0;
						c_use_lui_hi = 1;
						c_lui_hi_type = 0;
						c_imm = {{(RV-8){ins[0]}}, ins[7:1],1'b0};
				    end
		5'b10_001:	begin	// addi (rx)
						c_op = `OP_ADD;
						c_rd[3] = 0;
						c_rs1 = {1'b0, ins[10:8]};
						c_trap = !supmode && (c_rd >= 4'b0011 && c_rd <= 4'b0110);
						c_use_lui_hi = 1;
						c_lui_hi_type = 0;
						c_imm = {{(RV-8){ins[7]}}, ins[7:0]};
					end
		5'b10_010:	begin	// lwsp  **
						c_load = 1;
						c_cond = 3'bxx0;
						c_op = `OP_ADD;
						c_rd = {ins[7], ins[10:8]};
						c_rs1 = 2;
						c_use_lui_hi = 1;
						c_lui_hi_type = 0;
						c_trap = !supmode && (c_rd >= 4'b0011 && c_rd <= 4'b0110);
						c_imm =  {{(RV-8){1'b0}}, ins[0], ins[6:1], 1'b0};
					end
		5'b10_011: begin 	// lb name
						c_load = 1;
						c_op = `OP_ADD;
						c_cond = 3'bxx1;
						c_rs1 = 0;
						c_use_lui_hi = 1;
						c_lui_hi_type = 0;
						c_imm = {{(RV-8){ins[7]}}, ins[7:0]};
				    end
		5'b10_100:	case (ins[2:0])
					3'b000:	begin
								c_rs1 = {ins[7], ins[10:8]};
								if (!ins[4]) begin // jr
									c_jmp = 1;
									c_op = `OP_ADD;
									c_cond = 3'bxx0;
									c_rs2 = 0;
									c_needs_rs2 = 1;
								end else begin	// jalr
									c_jmp = 1;
									c_cond = 3'bxx1;
									c_op = `OP_ADD;
									c_rd = 1;
									c_rs2 = 0;
									c_needs_rs2 = 1;
								end
								c_trap = ins[3:2]!=0 || ins[6:5]!=0 || (!supmode && (c_rs1 >= 4'b0011 && c_rs1 <= 4'b0110));
							end
					3'b001:	begin	// mov
								c_op = `OP_ADD;
								c_rd[3] = ins[3];
								c_rs1 = 0;
								c_rs2 = {ins[4], ins[7:5]};
								c_needs_rs2 = 1;
								c_trap = (!supmode && ((c_rs2 >= 4'b0011 && c_rs2 <= 4'b0110) || (c_rs1 >= 4'b0011 && c_rs1 <= 4'b0110)));
						end
					3'b010: begin	// add
								c_op = `OP_ADD;
								c_rd[3] = ins[3];
								c_rs1 = {ins[3], ins[10:8]};
								c_rs2 = {ins[4], ins[7:5]};
								c_needs_rs2 = 1;
								c_trap = (!supmode && ((c_rs2 >= 4'b0011 && c_rs2 <= 4'b0110) || (c_rs1 >= 4'b0011 && c_rs1 <= 4'b0110)));
							end
					3'b011: begin	// sub
								c_op = `OP_SUB;
								c_rd[3] = ins[3];
								c_rs1 = {ins[3], ins[10:8]};
								c_rs2 = {ins[4], ins[7:5]};
								c_needs_rs2 = 1;
								c_trap = (!supmode && ((c_rs2 >= 4'b0011 && c_rs2 <= 4'b0110) || (c_rs1 >= 4'b0011 && c_rs1 <= 4'b0110)));
							end
					3'b100:	begin	 // invmmu  si sd ui ud
								c_rd = 0;
								c_inv_mmu = supmode;
								c_imm = {{(RV-4){1'bx}}, ins[6:3]};
								c_trap = !supmode || ins[10:7]!=0;
							end
					default:c_trap = 1;
					endcase
		5'b10_101: begin 	// sb7
						c_store = 1;
						c_cond = 3'bxx1;
						c_op = `OP_ADD;
						c_rs1 = {1'b1, 3'b111};
						c_use_lui_hi = 1;
						c_lui_hi_type = 0;
						c_imm = {{(RV-8){ins[7]}}, ins[7:0]};
					end
		5'b10_110:	begin	// swsp  **
						c_store = 1;
						c_cond = 3'bxx0;
						c_rs2 = {ins[7], ins[10:8]};
						c_op = `OP_ADD;
						c_rs1 = 2;
						c_use_lui_hi = 1;
						c_lui_hi_type = 0;
						c_trap = !supmode && (c_rs2 >= 4'b0011 && c_rs2 <= 4'b0110);
						c_imm =  {{(RV-8){1'b0}}, ins[0], ins[6:1], 1'b0};
					end
		5'b10_111: begin 	// sb name
						c_store = 1;
						c_cond = 3'bxx1;
						c_op = `OP_ADD;
						c_rs1 = 0;
						c_use_lui_hi = 1;
						c_lui_hi_type = 0;
						c_imm = {{(RV-8){ins[7]}}, ins[7:0]};
					end
		5'b11_000:	begin	//  free
						c_trap = 1;
				    end
		5'b11_001: begin 	// swio
						c_store = 1;
						c_io = 1;
						c_cond = 3'b0x0;
						c_op = `OP_ADD;
						c_trap = !supmode && !user_io;
						c_imm = {{(RV-6){1'b0}}, ins[0], ins[4:1], 1'b0};
					end
		5'b11_010: begin 	// lwio
						c_load = 1;
						c_io = 1;
						c_op = `OP_ADD;
						c_cond = 3'b0x0;
						c_trap = !supmode && !user_io;
						c_imm = {{(RV-6){1'b0}}, ins[0], ins[4:1], 1'b0};
				    end
		5'b11_011:
					begin				// lui ** - note inverted extension
						c_op = `OP_ADD;
						c_rd = {ins[7], ins[10:8]};	// allows lr
						c_rs1 = 0;
						c_imm = {1'b1, ins[6:0], 8'b0};
						c_load_lui_hi = c_rd == 4'b0111;
						c_trap = (!supmode && (c_rd >= 4'b0011 && c_rd <= 4'b0110));
					end
		5'b11_100:	begin
						c_rd = {1'b1, ins[10:8]};
						c_rs1 = {1'b1, ins[10:8]};
						c_rs2 = {1'b1, ins[7:5]};
						case (ins[1:0]) // synthesis full_case parallel_case
						2'b00: begin
									c_op = `OP_SLL;
									c_needs_rs2 = !ins[3];
									c_imm = {12'bx, ins[7:4]};
							   end
						2'b01: begin
									c_op = `OP_XOR;
									c_needs_rs2 = !ins[3];
									c_imm = {12'b0, ins[7:4]};
									c_trap = ins[2] || (!ins[3] && ins[5]);
							   end
						2'b10: begin
									c_op = `OP_OR;
									c_use_lui_hi = 1;
									c_lui_hi_type = 2;
									c_imm = {10'b0, ins[7:2]};
							   end
						2'b11: begin
								c_needs_rs2 = 1;
								case ({ins[4:2]}) // synthesis full_case parallel_case
`ifdef MULT
								3'b000:	c_mult = 1;
								3'b001:	c_div = 1;
`endif
								3'b010:	c_op = `OP_ADDB;
								3'b011:	c_op = `OP_ADDBU;
								3'b100:	c_op = `OP_SWAP; // swap 
								3'b101:	casez (ins[7:5])
										3'b000: begin	// addpc
													c_op = `OP_ADD;
													c_rs2_pc = 1;
													c_rs2 = 4'bx;
												end	
										3'b001: begin	// sext
													c_op = `OP_ADDB;
													c_rs2 = 0;
												end   
										3'b010: begin	// zext
													c_op = `OP_ADDBU;
													c_rs2 = 0;
												end  
										3'b011: begin	//inv
													c_op = `OP_XOR;
													c_rs2 = 0;
													c_rs2_inv = 1;
												end   
										3'b100: begin // neg
													c_op = `OP_SUB;
													c_rs1 = 0;
													c_rs2 = {1'b1, ins[10:8]};
												end   
										3'b101: begin 	// flushw (reg)
													c_store = 1;
													c_flush_write = 1;
													c_io = 0;
													c_cond = 3'bxx0;
													c_op = `OP_ADD;
													c_rs2 = 0;
													c_rs1 = {1'b1, ins[10:8]};
													c_imm = 0;
													c_trap = !supmode;
												end
										3'b110: begin // free
													c_trap = 1;
												end 
										3'b111:	casez (ins[10:8]) // synthesis full_case parallel_case
												3'b0??: begin	// trap instructions (use 01 for break)
															c_sys_call = 0;
															c_trap = 1;
														end
												3'b100:begin				// syscall
															c_sys_call = 1;
															c_trap = 1;
													end
												3'b101:begin				// swapsp
															c_op = `OP_ADD;
															c_trap = !supmode;
															c_rd = 2;
															c_rs1 = 6;
															c_rs2 = 0;
															c_needs_rs2 = 1;
															c_swapsp = 1;
														end
												default:	c_trap = 1;
												endcase
										default:	c_trap = 1;
										endcase
								3'b110:	begin	// flush all
											c_rd = 0;
											c_flush_all = 1;
											c_imm = {{(RV-2){1'bx}}, ins[9:8]};
											c_trap = ins[10] || !supmode;
										end
								default:	c_trap = 1;
								endcase
							   end
						default: c_trap = 1;
						endcase
					end
		5'b11_101: begin 	// lb7
						c_load = 1;
						c_op = `OP_ADD;
						c_cond = 3'bxx1;
						c_rs1 = {1'b1, 3'b111};
						c_use_lui_hi = 1;
						c_lui_hi_type = 0;
						c_imm = {{(RV-8){ins[7]}}, ins[7:0]};
				    end
		5'b11_11?:	begin	//  bltz/bgez
						c_br = 1;
						c_cond = {2'b01, ins[11]};	// bltz/bgez
						c_rs1 = {1'b1, ins[10:8]};
						c_op = `OP_ADD;
						c_use_lui_hi = 1;
						c_lui_hi_type = 0;
						c_imm = {{(RV-8){ins[0]}}, ins[7:1],1'b0};
					end
		default: c_trap = 1;
		endcase
	end

	always @(posedge clk) 
	if (idone) begin
		r_trap <= c_trap;
		r_sys_call <= c_sys_call;
		r_swapsp <= c_swapsp;
		r_rs1 <= c_rs1;
		r_rs2 <= c_rs2;
		r_needs_rs2 <= c_needs_rs2;
		r_rs2_pc <= c_rs2_pc;
		r_rs2_inv <= c_rs2_inv;
		r_rd <= c_rd;
		r_imm <= c_imm;
		r_store <= c_store;
		r_load <= c_load;
		r_io <= c_io;
`ifdef MULT
		r_mult <= c_mult;
		r_div <= c_div;
`endif
		r_op <= c_op;
		r_br <= c_br;
		r_cond <= c_cond;
		r_jmp <= c_jmp;
		r_flush_all <= c_flush_all;
		r_flush_write <= c_flush_write;
		r_inv_mmu <= c_inv_mmu;
		r_set_cc <= c_set_cc;
		r_load_lui_hi <= c_load_lui_hi;
		r_use_lui_hi <= c_use_lui_hi;
		r_lui_hi_type <= c_lui_hi_type;
	end


endmodule

/* For Emacs:
 * Local Variables:
 * mode:c
 * indent-tabs-mode:t
 * tab-width:4
 * c-basic-offset:4
 * End:
 * For VIM:
 * vim:set softtabstop=4 shiftwidth=4 tabstop=4:
 */

