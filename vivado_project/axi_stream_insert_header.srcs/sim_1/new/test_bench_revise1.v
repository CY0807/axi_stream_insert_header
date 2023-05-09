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
parameter CLK_TIME = 10;
parameter cnt_test_num_max = 200;

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
always #(CLK_TIME/2) clk <= ~clk;

// initialization
initial begin
  // basic
  $display("***** Start	Simulation *****");
  $display("Random Seed = ", seed);
  clk = 1;
  rst_n = 0;
  
  // data_in
  data_len = {$random(seed)} % 256 + 1;
  data_in = $random(seed);
  last_in = 0;
  keep_in = 4'b1111;
  byte_in_cnt = 0;
  cnt_data_len = 0;  
  valid_in = 0;
  
  // data_insert
  data_insert = $random(seed);
  valid_insert = 0;
  byte_insert_cnt = {$random(seed)} % (DATA_BYTE_WD-1) + 1;
  keep_insert = ~(4'b1111<<(byte_insert_cnt)); 
  
  // start
  # 105
  rst_n = 1;
  # 10
  valid_insert = 1;
end

// random data_in: content, length
always@(posedge clk) begin 
  if(valid_in & ready_in) begin
    data_in <= $random(seed);
    cnt_data_len <= cnt_data_len + 1;	
    if(cnt_data_len == data_len-1) begin
  	  cnt_data_len <= 0;
  	  data_len <= {$random(seed)} % 256 + 1;
    end  
  end
end

// random valid_in
always@(posedge clk) begin
  if((~valid_in) | ready_in) //
    valid_in <= $random(seed);
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
  if((cnt_data_len == data_len-1) & valid_in & ready_in)
  	last_in <= 1;
  else
    last_in <= 0;
end

// random ready_out
always@(posedge clk) begin
  ready_out <= $random(seed);
end

// random data header
always@(posedge clk) begin
  if(last_in) begin
    data_insert = $random(seed);
    byte_insert_cnt = {$random(seed)} % (DATA_BYTE_WD-1) + 1;
    keep_insert = ~(4'b1111<<(byte_insert_cnt)); 
  end
end

// 自动化验证部分
reg [7:0] data_input[0:1151];
reg [7:0] data_input_cache[0:1151];
reg [7:0] data_output[0:1151];
reg [DATA_BYTE_WD-1:0] keep_in_test, keep_insert_test, keep_out_test;

integer cnt_out, cnt_in, cnt_in_cache, cnt_test_num, i, j;

// output result
integer byte_data_out_cnt;

always@(posedge clk or negedge rst_n) begin
  if(~rst_n)
    cnt_out = 0;
  else if(valid_out & ready_out) begin
    byte_data_out_cnt = keep_out[0] + keep_out[1] + keep_out[2] + keep_out[3];
    for(i=0; i<=byte_data_out_cnt-1; i=i+1) begin
	  data_output[cnt_out+i] = data_out >> ((3-i)*8);
	end
	cnt_out = cnt_out + byte_data_out_cnt;	
	if(last_out) begin
	  keep_out_test = keep_out;
	  # (CLK_TIME * 0.8);
	  cnt_out = 0;
	end
  end
end

// input result 
integer byte_data_in_cnt;

always@(posedge clk or rst_n) begin
  if(~rst_n) begin
    cnt_in = 0;
	cnt_test_num = 0;
  end
  else if(ready_insert & valid_insert) begin
    keep_insert_test = keep_insert;
    for(j=0; j<=byte_insert_cnt-1; j=j+1) begin
	  data_input[cnt_in+j] = data_insert >> ((byte_insert_cnt-j-1)*8);
	end
	cnt_in = cnt_in + byte_insert_cnt;	
  end
  else if(ready_in & valid_in) begin
    byte_data_in_cnt = keep_in[0] + keep_in[1] + keep_in[2] + keep_in[3];
	for(j=0; j<=byte_data_in_cnt-1; j=j+1) begin
	  data_input[cnt_in+j] = data_in >> ((3-j)*8);
	end
	cnt_in = cnt_in + byte_data_in_cnt;
	if(last_in) begin
	  keep_in_test = keep_in;
	  # (CLK_TIME * 0.8);
	  cnt_in = 0;
	end
  end
end

// print
always@(posedge clk) begin
  // print input data
  if(last_in & ready_in & valid_in) begin
    # 1
    cnt_in_cache = cnt_in;
    $display("\ntest repeat times: %d", cnt_test_num);
	$display("input head and data:");
	for(i=0; i<cnt_in; i=i+1) begin	 
      data_input_cache[i] = data_input[i];	
	  $write("%H", data_input[i]);
	end
	$display("\nkeep_insert: 4'b%b", keep_insert_test);
	$display("keep_in: 4'b%b", keep_in_test);
  end
  // print output data
  else if(last_out & ready_out & valid_out) begin
    # 1
    $display("output head and data:");
	for(i=0; i<cnt_out; i=i+1) begin	  
	  $write("%H", data_output[i]);
	end
	$display("\nkeep_out: 4'b%b", keep_out_test);
	cnt_test_num = cnt_test_num + 1;
	// check result
	if(~(cnt_in_cache == cnt_out)) begin
	  $display("Error: check result");
	  $finish;
	end
	for(i=0; i<cnt_out; i=i+1) begin	  
	  if(~(data_input_cache[i] == data_output[i])) begin
	  $display("Error: check result");
	  $finish;
	end
	end
	// repeat end
	if(cnt_test_num == cnt_test_num_max) begin
	  $display("test success! repeat time: %d", cnt_test_num_max);
	  $finish;
	end
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
