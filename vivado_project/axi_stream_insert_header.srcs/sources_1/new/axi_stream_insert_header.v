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
reg header_captured, header_added, data_stock, shake_in_d;
reg [DATA_WD-1:0] data_in_reg, data_insert_reg;
reg [2*DATA_WD-1:0] data_cache;
reg [DATA_BYTE_WD-1:0] keep_in_reg, keep_insert_reg;
reg [2*DATA_BYTE_WD-1:0] keep_cache;
reg [BYTE_CNT_WD-1:0] byte_insert_cnt_reg, byte_insert_cnt_real;

assign ready_insert = ~header_captured;
assign ready_in = header_captured & (~data_stock | shake_out) & (~dual_time);

always@(posedge clk) begin
  if(shake_in) begin
    data_cache <= {data_cache, data_in};
    keep_cache <= {keep_cache, keep_in};
	if(~header_added) begin
	  data_cache <= {data_insert_reg, data_in};
	  keep_cache <= {keep_insert_reg, keep_in};
	end
  end
  else if(dual_time & shake_out) begin
    data_cache <= data_cache << DATA_WD;
    keep_cache <= keep_cache << DATA_BYTE_WD;
  end
end

always@(posedge clk or negedge rst_n) begin
  if(~rst_n | last_in) begin
    header_captured <= 0;
  end
  else if(shake_insert) begin
    header_captured <= 1;
  end
end

always@(posedge clk or negedge rst_n) begin
  if(~rst_n) begin
    data_stock <= 0;
  end
  else if(shake_in) begin
    data_stock <= 1;
  end
  else if(shake_out) begin
    data_stock <= 0;
  end
end

always@(posedge clk) shake_in_d <= shake_in;

always@(*) begin
  if(~rst_n | (last_out & shake_out)) begin
    header_added <= 0;
  end
  else if(shake_in_d) begin
    header_added <= 1;
  end
end

always@(posedge clk) begin
  if(~header_added) begin
    byte_insert_cnt_real <= byte_insert_cnt_reg;
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
wire [DATA_WD-1:0] bit_insert_cnt = byte_insert_cnt_real << 3; // head的有效bit
wire [BYTE_CNT_WD-1:0] disbyte_insert_cnt = DATA_BYTE_WD-byte_insert_cnt_real; //head的无效byte
wire [DATA_WD-1:0] disbit_insert_cnt = disbyte_insert_cnt << 3; // head的无效bit
reg dual_time;

assign valid_out = data_stock | last_out;
assign data_out = data_cache >> bit_insert_cnt;
assign keep_out = keep_cache >> byte_insert_cnt_real;
assign last_out = ((keep_cache[DATA_BYTE_WD-1:0] << disbyte_insert_cnt) == cnst) & dual_time;

always@(posedge clk or negedge rst_n) begin
  if(~rst_n | (last_out & shake_out))
    dual_time <= 0;
  else if(last_in & shake_in)
    dual_time <= 1;
end	

endmodule