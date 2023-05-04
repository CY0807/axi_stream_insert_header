`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: ChenYan
// 
// Create Date: 2023/04/25 15:34:58
// Design Name: 
// Module Name: axi_stream_insert_header
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


module axi_stream_insert_header 
#(
  parameter DATA_WD = 32,
  parameter DATA_BYTE_WD = DATA_WD / 8,
  parameter BYTE_CNT_WD = $clog2(DATA_BYTE_WD)
) 
(
  input clk,
  input rst_n,
  // AXI Stream input original data
  input valid_in,
  input [DATA_WD-1:0] data_in,
  input [DATA_BYTE_WD-1:0] keep_in,
  input last_in,
  output ready_in,
  // AXI Stream output with header inserted
  output valid_out,
  output [DATA_WD-1:0] data_out,
  output [DATA_BYTE_WD-1:0] keep_out,
  output last_out,
  input ready_out,
  // The header to be inserted to AXI Stream input
  input valid_insert,
  input [DATA_WD-1:0] data_insert,
  input [DATA_BYTE_WD-1:0] keep_insert,
  input [BYTE_CNT_WD-1:0] byte_insert_cnt,
  output ready_insert
);

// 1.数据头和数据体输入部分

reg header_captured; // 表示是否捕获到了1拍的data header
reg [DATA_WD-1:0] data_cache; // 缓存一拍数据
reg [DATA_BYTE_WD-1:0] keep_in_cache;
reg [BYTE_CNT_WD-1:0] byte_insert_cnt_reg;

assign ready_insert = ~header_captured & (~valid_out);
assign ready_in = valid_out; // 当头byte捕获到且输出数据时允许输入数据

always@(posedge clk or negedge rst_n) begin
  if(~rst_n) begin
    header_captured <= 0;
    data_cache <= 0;
    byte_insert_cnt_reg <= 0;
    keep_in_cache <= 0;
  end
  else begin
    if(last_in_d1) begin
      header_captured <= 0;  // 一次输出后清零捕获状态
    end
    else if(ready_insert & valid_insert) begin
      header_captured <= 1;  // 捕获到1拍的header
    end	
	
    if(ready_insert & valid_insert) begin			
      data_cache <= data_insert;
      byte_insert_cnt_reg <= byte_insert_cnt;
      keep_in_cache <= keep_insert;
    end
    else if(ready_in & valid_in) begin
      data_cache <= data_in;
      keep_in_cache <= keep_in_real;
    end
  end
end

// 2.数据输出部分

localparam BIT_CNT_DATA = $clog2(DATA_WD)+1;

wire [BIT_CNT_DATA-1:0] header_valid_bit; //header中有效数据的位宽
wire last_in_real = last_in & valid_in;
reg last_in_d1; //last_in打一拍
reg last_out_d1; //last_out打一拍
wire [DATA_BYTE_WD-1:0] keep_in_real = (valid_in & ready_in & (~last_in_d1)) ? keep_in : 0;
wire [DATA_BYTE_WD-1:0] cnst = 0;

assign header_valid_bit = byte_insert_cnt_reg << 3;
assign data_out = {data_cache, data_in} >> header_valid_bit;
assign valid_out = (valid_in & header_captured & ready_out) | (last_out & (~last_out_d1));
assign keep_out = {keep_in_cache, keep_in_real} >> byte_insert_cnt_reg;
assign last_out = ((keep_in_real<<(DATA_BYTE_WD-byte_insert_cnt_reg)) == cnst) & (last_in_real | last_in_d1);

always@(posedge clk) begin
  last_in_d1 <= last_in_real;
  last_out_d1 <= last_out;
end
	

endmodule
