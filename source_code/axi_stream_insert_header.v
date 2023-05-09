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

// 握手信号
wire shake_in = ready_in & valid_in;
wire shake_insert = ready_insert & valid_insert;
wire shake_out = ready_out & valid_out;

// 1.数据头和数据体输入部分
reg header_captured_reg, head_in_reg, data_stock_reg;
reg [DATA_WD-1:0] data_in_reg, data_insert_reg, data_cache_reg;
reg [DATA_BYTE_WD-1:0] keep_in_reg, keep_insert_reg, keep_cache_reg;
reg [BYTE_CNT_WD-1:0] byte_insert_cnt_reg, byte_insert_cnt_real_reg;

assign ready_insert = ~header_captured_reg & (~data_stock_reg | shake_out);
assign ready_in = header_captured_reg & (~data_stock_reg | shake_out) & (~dual_time_reg) | (last_out & shake_out);

always@(posedge clk or negedge rst_n) begin
  if(~rst_n) begin
    head_in_reg <= 0;
  end
  else if(shake_insert) begin
    {data_cache_reg, data_in_reg} <= {data_in_reg, data_insert};
	{keep_cache_reg, keep_in_reg} <= {keep_in_reg, keep_insert};
	head_in_reg <= 1;
  end
  else if(shake_in) begin
    {data_cache_reg, data_in_reg} <= {data_in_reg, data_in};
	{keep_cache_reg, keep_in_reg} <= {keep_in_reg, keep_in};
	head_in_reg <= 0;
  end
end

always@(posedge clk or negedge rst_n) begin
  if(~rst_n | (last_in & shake_in)) begin
    header_captured_reg <= 0;
  end
  else if(shake_insert) begin
    header_captured_reg <= 1;
  end
end

always@(posedge clk or negedge rst_n) begin
  if(~rst_n) begin
    data_stock_reg <= 0;
  end
  else if(shake_in) begin
    data_stock_reg <= 1;
  end
  else if(shake_out) begin
    data_stock_reg <= 0;
  end
end

always@(posedge clk) begin
  if((last_out & shake_out) | shake_in) begin
    byte_insert_cnt_real_reg <= byte_insert_cnt_reg;
  end
end

always@(posedge clk) begin
  if(shake_insert) begin
    data_insert_reg <= data_insert;
	keep_insert_reg <= keep_insert;
	byte_insert_cnt_reg <= byte_insert_cnt;
  end
end

// 2.数据输出部分

localparam BIT_CNT_DATA = $clog2(DATA_WD)+1;

wire last_in_real = last_in & valid_in;
wire [DATA_BYTE_WD-1:0] cnst = 0;
wire [DATA_WD-1:0] bit_insert_cnt = byte_insert_cnt_real_reg << 3; // head的有效bit
wire [BYTE_CNT_WD-1:0] disbyte_insert_cnt = DATA_BYTE_WD-byte_insert_cnt_real_reg; //head的无效byte
wire [DATA_WD-1:0] disbit_insert_cnt = disbyte_insert_cnt << 3; // head的无效bit
wire [DATA_WD-1:0] data_in_reg_real = head_in_reg ? 0 : data_in_reg;
wire [DATA_BYTE_WD-1:0] keep_in_reg_real = head_in_reg ? 0 : keep_in_reg;

reg dual_time_reg;

assign valid_out = data_stock_reg | last_out;
assign data_out = {data_cache_reg, data_in_reg_real} >> bit_insert_cnt;
assign keep_out = {keep_cache_reg, keep_in_reg_real} >> byte_insert_cnt_real_reg;
assign last_out = ((keep_in_reg_real << disbyte_insert_cnt) == cnst) & dual_time_reg;

always@(posedge clk or negedge rst_n) begin
  if(~rst_n | (last_out & shake_out))
    dual_time_reg <= 0;
  else if(last_in & shake_in)
    dual_time_reg <= 1;
end	

endmodule