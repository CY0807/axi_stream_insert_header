`timescale 1ns / 1ps

// 主要修改内容：
/*
1、由于valid_out依赖于输入握手信号，而要求逐级反压，因此输入握手
   信号受限于输出握手信号，不可避免产生逻辑环路，因此将valid_out
   的组合逻辑改为时序电路；
   
2、为了避免产生气泡，在last_in和last_out之间的时间段内（dual time）
   将同时输出数据尾和捕获下一段数据的数据头，data_cache产生矛盾，
   因此分别例化了data_in的cache和data_insert的cache；keep信号和
   byte_insert_cnt信号同理，并采用head_added区别使用哪个cache；
   
3、test bench增加了ready out的随机化，增加了自动测试程序，能输出
   每次测试的输入输出结果，测试次数由cnt_test_num_max控制
*/

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

localparam BIT_CNT_DATA = $clog2(DATA_WD)+1;

reg valid_out, last_out, head_captured, head_added, dual_time, last_in_d1, shake_in_d1; 
// head: 数据头的捕获、添加信号
// dual_time: 在last_in,last_out之间(不含); 发送数据尾的同时接受下一段head; 不允许接受数据体
reg [DATA_WD-1:0] data_in_cache, data_insert_cache, data_out;
reg [DATA_BYTE_WD-1:0] keep_in_cache, keep_insert_cache, keep_out;
reg [BYTE_CNT_WD-1:0] byte_insert_cnt_reg, byte_insert_cnt_real;

wire [BIT_CNT_DATA-1:0] header_valid_bit = byte_insert_cnt_real << 3; //header中有效数据的位宽
wire shake_in, shake_out, shake_insert;

assign ready_insert = (~head_captured) & rst_n;
assign ready_in = head_captured & ready_out & (~dual_time) & rst_n;
assign shake_in = ready_in & valid_in;
assign shake_insert = ready_insert & valid_insert;
assign shake_out = ready_out & valid_out;

// 缓存data insert信号
always@(posedge clk or negedge rst_n) begin
  if(~rst_n) begin
    data_insert_cache <= 0;
    byte_insert_cnt_reg <= 0;
    keep_insert_cache <= 0;
  end
  else if(shake_insert) begin			
    data_insert_cache <= data_insert;
    byte_insert_cnt_reg <= byte_insert_cnt;
	keep_insert_cache <= keep_insert;
  end
end

// 缓存data in信号
always@(posedge clk or negedge rst_n) begin
  if(~rst_n) begin
    data_in_cache <= 0;
	keep_in_cache <= 0;
  end
  else if(shake_in | (shake_out & dual_time)) begin	
    data_in_cache <= data_in;
	keep_in_cache <= keep_in;
  end
end

// valid_out
always@(posedge clk or negedge rst_n) begin
  if(~rst_n)
    valid_out <= 0;
  else if(shake_in)
    valid_out <= 1;
  else if(shake_out)
    valid_out <= 0;
	if(dual_time)
	  valid_out <= 1;
end

// keep_out and data_out
always@(posedge clk or negedge rst_n) begin
  if(~rst_n) begin
    last_out <= 0;
  end
  else begin
    if(shake_in) begin
      if(~head_added) begin
        keep_out <= {keep_insert_cache, keep_in} >> byte_insert_cnt_real;
        data_out <= {data_insert_cache, data_in} >> header_valid_bit; 
      end
      else begin
        keep_out <= {keep_in_cache, keep_in} >> byte_insert_cnt_real;	
	    data_out <= {data_in_cache, data_in} >> header_valid_bit;
        last_out <= (keep_in << (DATA_WD - byte_insert_cnt_real) == 0);
      end
    end
    else if(shake_out & dual_time) begin
      keep_out <= {keep_in_cache, 4'b0} >> byte_insert_cnt_real;
      data_out <= {data_in_cache, data_in} >> header_valid_bit; 
      last_out <= 1;	
    end
    if(last_out & shake_out)
      last_out <= 0;
  end
end

// head_captured: insert握手后拉高，last_in握手后拉低
always@(posedge clk or negedge rst_n) begin
  if(~rst_n)
    head_captured <= 0;   
  else begin
    if(last_in & shake_in)
      head_captured <= 0;
    else if(shake_insert)
      head_captured <= 1;  
  end
end

// head_added: 伴随last_out拉低，shake_in后拉高: 在head输出的同时拉高
always@(*) begin
  if(~rst_n | last_out)
    head_added <= 0;
  else if(shake_in_d1) 
    head_added <= 1;
end

// dual_time: 伴随last_out握手拉低，last_in握手之后拉高
always@(*) begin
  if(~rst_n | (last_out & shake_out))
    dual_time <= 0;
  else if(last_in_d1 & shake_in_d1)
    dual_time <= 1;
end

// byte_insert_cnt_real
always@(*) begin
  if(~head_added)
    byte_insert_cnt_real <= byte_insert_cnt_reg;
end

// 打拍信号
always@(posedge clk) begin
  last_in_d1 <= last_in;
  shake_in_d1 <= shake_in;
end
	
endmodule
