`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/05/09 11:24:10
// Design Name: 
// Module Name: test_bench_tmp
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module test_bench_tmp(

    );
endmodule

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/05/04 12:17:49
// Design Name: 
// Module Name: test_bench_revise1
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module test_bench_tmp(
);
	
parameter DATA_WD = 32;
parameter DATA_BYTE_WD = DATA_WD / 8;
parameter BYTE_CNT_WD = $clog2(DATA_BYTE_WD);

// module ports	
reg clk, rst_n;
reg valid_in, valid_insert, last_in, ready_out;
reg [DATA_WD-1:0] data_in, data_insert;
reg [DATA_BYTE_WD-1:0] keep_in, keep_insert;
reg [BYTE_CNT_WD-1:0] byte_insert_cnt;
wire ready_in, ready_insert, valid_out, last_out;	
wire [DATA_BYTE_WD-1:0] keep_out;
wire [DATA_WD-1:0] data_out;

// other test bench variables
integer seed = 0;
reg [8:0] clk_cnt;

// clk
always #5 clk <= ~clk;

// initialization
initial begin
  // basic
  clk = 1;
  rst_n = 0;
  ready_out = 1; 
  valid_insert = 0;
  valid_in = 0;
  last_in = 0;
  clk_cnt = 0;  
  // start
  # 5
  rst_n = 1;
end

wire [3:0] tmp = clk_cnt-3;

always@(posedge clk) begin
  clk_cnt <= clk_cnt + 1;
  case(clk_cnt)
    'd2: begin
	  valid_insert <= 1;
	  keep_insert <= 4'b0111;
	  byte_insert_cnt <= 3;
	  data_insert <= 'hffffffff;
	  end
	'd4, 'd5, 'd6, 'd7, 'd8: begin
	  valid_in <= 1;
	  keep_in <= 4'b1111;
	  data_in <= {8{tmp}};
	  end
	'd9: begin
	  keep_in <= 4'b1100;
	  data_in <= {8{tmp}};
	  last_in <= 1;
	  keep_insert <= 4'b0001;
	  byte_insert_cnt <= 1;
	  end
	'd10, 'd11, 'd12, 'd13: begin
	  last_in <= 0;
	  data_in <= {8{tmp}};
	  keep_in <= 4'b1111;
	  end
	'd14: begin
	  keep_in <= 4'b1110;
	  data_in <= {8{tmp}};
	  last_in <= 1;
	  end
	'd15: begin
	  last_in <= 0;
	  valid_in <= 0;
	  end
	'd20: begin
	  $finish;
	  end
  endcase
end

axi_stream_insert_header 
#(
  .DATA_WD(DATA_WD)
) 
axi_stream_insert_header_inst
(
  .clk(clk),
  .rst_n(rst_n),
  .valid_in(valid_in),
  .data_in(data_in),
  .keep_in(keep_in),
  .last_in(last_in),
  .ready_in(ready_in),
  .valid_out(valid_out),
  .data_out(data_out),
  .keep_out(keep_out),
  .last_out(last_out),
  .ready_out(ready_out),
  .valid_insert(valid_insert),
  .data_insert(data_insert),
  .keep_insert(keep_insert),
  .byte_insert_cnt(byte_insert_cnt),
  .ready_insert(ready_insert)
);

endmodule
