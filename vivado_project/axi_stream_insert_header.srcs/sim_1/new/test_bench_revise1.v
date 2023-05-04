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


module test_bench_revise1(
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
reg [8:0] data_len; // length of data_in: 1~256
reg [8:0] cnt_data_len; // count of length of data_in
reg [BYTE_CNT_WD-1:0] byte_in_cnt; // last word of data_in
integer seed = 0;

// clk
always #5 clk <= ~clk;

// initialization
initial begin
  // basic
  clk = 1;
  rst_n = 0;
  ready_out = 1;  
  
  // data_in
  data_len = {$random(seed)} % 256 + 1;
  data_in = $random(seed);
  valid_in = 1;
  last_in = 0;
  keep_in = 4'b1111;
  byte_in_cnt = 0;
  cnt_data_len = 0;  
  
  // data_insert
  data_insert = $random(seed);
  valid_insert = 1;
  byte_insert_cnt = {$random(seed)} % (DATA_BYTE_WD-1) + 1;
  keep_insert = ~(4'b1111<<(byte_insert_cnt)); 
  
  // start
  # 105
  rst_n = 1;
end

// random data_in: including signals of valid, content, length
always@(posedge clk) begin
  valid_in <= $random(seed);
  if(valid_in & ready_in) begin
    data_in <= $random(seed);
    cnt_data_len <= cnt_data_len + 1;	
    if(cnt_data_len == data_len-1) begin
  	  cnt_data_len <= 0;
  	  data_len <= {$random(seed)} % 256 + 1;
    end  
  end
end

// random last keep_in
always@(*) begin
  if(valid_in & ready_in & last_in) begin
    byte_in_cnt <= {$random(seed)} % (DATA_BYTE_WD);
    keep_in <= 4'b1111<<(byte_in_cnt);
  end
  else begin
    keep_in <= 4'b1111;
  end
end

// last_in
always@(*) begin
  if(cnt_data_len == data_len-1 & valid_in) begin
  	last_in <= 1;
  end 
  else begin
    last_in <= 0;
  end
end

// random data header
always@(posedge clk) begin
  if(last_in) begin
    data_insert = $random(seed);
    byte_insert_cnt = {$random(seed)} % (DATA_BYTE_WD-1) + 1;
    keep_insert = ~(4'b1111<<(byte_insert_cnt)); 
  end
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
