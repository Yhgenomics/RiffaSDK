
module m_pcie_if_v2(

     input clk,
     input rst_n,
     output[C_NUM_CHNL-1:0]                    CHNL_RX_CLK,
     input [C_NUM_CHNL-1:0]                    CHNL_RX,
     output[C_NUM_CHNL-1:0]                    CHNL_RX_ACK,
     input [C_NUM_CHNL-1:0]                    CHNL_RX_LAST,
     input [(C_NUM_CHNL*32)-1:0]               CHNL_RX_LEN,
     input [(C_NUM_CHNL*31)-1:0]               CHNL_RX_OFF,
     input [C_NUM_CHNL*C_PCI_DATA_WIDTH-1:0]   CHNL_RX_DATA,
     input [C_NUM_CHNL-1:0]                    CHNL_RX_DATA_VALID,
     output[C_NUM_CHNL-1:0]                    CHNL_RX_DATA_REN,

     output[C_NUM_CHNL-1:0]                     CHNL_TX_CLK,
     output[C_NUM_CHNL-1:0]                     CHNL_TX,
     input [C_NUM_CHNL-1:0]                     CHNL_TX_ACK,
     output[C_NUM_CHNL-1:0]                     CHNL_TX_LAST,
     output[(C_NUM_CHNL*32)-1:0]                CHNL_TX_LEN,
     output[(C_NUM_CHNL*31)-1:0]                CHNL_TX_OFF,
     output[C_PCI_DATA_WIDTH-1:0]               CHNL_TX_DATA,
     output[C_NUM_CHNL-1:0]                     CHNL_TX_DATA_VALID,
     input [C_NUM_CHNL-1:0]                     CHNL_TX_DATA_REN,
	  output [15:0]                              debug_state
  );
/*------------------------------

Paramter settings

-------------------------------*/
parameter C_NUM_CHNL=1;
parameter C_PCI_DATA_WIDTH=64;
parameter REG_ADDR_DEPTH=16;
parameter REG_DATA_WIDTH=16;
parameter PADDING=C_PCI_DATA_WIDTH-REG_DATA_WIDTH;
parameter IDLE=8'D0;
parameter CHK_LOC=8'D1;
parameter ACK_RESP=8'D2;
parameter RECV=8'D3;
parameter HOLD=8'D4;
parameter WAIT_END=8'D5;
parameter WAIT_NEXT=8'D6;
parameter FETCH=8'D7;
parameter DECODE=8'D8;
parameter DDR_TRANS=8'D9;
parameter READ_REG=8'D10;
parameter TX_VALID=8'D11;
parameter WRITE_REG=8'D12;
/*------------------------------
System Arch
      |-----|
----->|FIFO |---->Fetch---->Decode--->Execution
      |-----|  |
               |
               |--->Register Bank
-------------------------------*/
reg [REG_DATA_WIDTH-1:0] reg_bank[REG_ADDR_DEPTH-1:0] ;
/*------------------------------

RIFFA INTERFACE HANLDER

-------------------------------*/
reg [7:0]  riffa_state_c /* synthesis keep */; 
reg [15:0] rx_cnt;
wire local_ready;
wire fifo_full;
wire fifo_empty;
wire fifo_wr;
wire fifo_rd;
wire [3:0] reg_addr;
wire [7:0] r_state;
wire [7:0] e_state;
assign r_state=riffa_state_c /* synthesis keep */; 


wire [C_PCI_DATA_WIDTH-1:0] fifo_data;

assign reg_addr=fifo_data[REG_DATA_WIDTH+3:REG_DATA_WIDTH];// Take the 4 bits as addr for register bank

assign local_ready=~fifo_full;
//State machine definition
always @(posedge clk, negedge rst_n)
begin
  if(!rst_n)
    riffa_state_c<=IDLE;
  else
    begin
      case(riffa_state_c)
        IDLE:
          begin
            if(CHNL_RX==1'b1)
              riffa_state_c<=CHK_LOC;
            else
              riffa_state_c<=IDLE;
          end

        CHK_LOC:
          begin
            if(local_ready)
              riffa_state_c<=ACK_RESP;
            else
              riffa_state_c<=riffa_state_c;
          end

        ACK_RESP:riffa_state_c<=RECV;

        RECV:
          begin
            if(local_ready==1'b0 && rx_cnt<CHNL_RX_LEN)
            riffa_state_c<=HOLD;
            else if((rx_cnt==CHNL_RX_LEN && CHNL_RX_LAST==1'b0) || (rx_cnt!=CHNL_RX_LEN && CHNL_RX_LAST==1'b0 && CHNL_RX==1'b0 && CHNL_RX_DATA_VALID==1'b0))
            riffa_state_c<=WAIT_NEXT;
            else if((rx_cnt==CHNL_RX_LEN && CHNL_RX_LAST==1'b1) || (rx_cnt!=CHNL_RX_LEN && CHNL_RX_LAST==1'b1 && CHNL_RX==1'b0 && CHNL_RX_DATA_VALID==1'b0))
            riffa_state_c<=WAIT_END;
            else
            riffa_state_c<=riffa_state_c;
          end

        WAIT_NEXT:
          begin
            if(CHNL_RX==1'b1)
            riffa_state_c<=IDLE;
            else
            riffa_state_c<=riffa_state_c;
          end

        WAIT_END:
			begin
				if(rx_cnt==CHNL_RX_LEN && CHNL_RX==1'b0)
				riffa_state_c<=IDLE;
				else
				riffa_state_c<=riffa_state_c;
			end 

        default:riffa_state_c<=IDLE;
      endcase
    end
end

// Associated variables logic
//1.CHNL_RX_ACK
//2.CHNL_RX_DATA_REN
//3.rx_cnt
//4.fifo_wr
//5.CHNL_RX_CLK

assign CHNL_RX_ACK=(riffa_state_c==ACK_RESP ? 1'b1 : 1'b0);
assign CHNL_RX_DATA_REN=(riffa_state_c==RECV ? 1'b1 : 1'b0);
assign fifo_wr=CHNL_RX_DATA_REN & CHNL_RX_DATA_VALID;

always @(posedge clk, negedge rst_n)
begin
  if(!rst_n)
    rx_cnt<=16'd0;
  else if(riffa_state_c==IDLE)
    rx_cnt<=16'd0;
  else if(fifo_wr==1'b1)
    rx_cnt<=rx_cnt+(C_PCI_DATA_WIDTH/32);
end

assign CHNL_RX_CLK=clk;

/*------------------------------

Command Execution pipeline

-------------------------------*/

reg [7:0] ex_state_c /* synthesis keep */; 
assign e_state=ex_state_c /* synthesis keep */;
always @(posedge clk,negedge rst_n)
begin
  if(!rst_n)
  ex_state_c<=IDLE;
  else
    begin
      case(ex_state_c)
        IDLE:
          begin
            if(fifo_empty==1'b0)
            ex_state_c<=FETCH;
            else
            ex_state_c<=ex_state_c;
          end

        FETCH:ex_state_c<=DECODE;

        DECODE:
          begin
            if(fifo_data[47:32]==16'hFFFF) // write request
              ex_state_c<=WRITE_REG;
            else if(fifo_data[47:32]==16'h0000)
              ex_state_c<=READ_REG;
            else
              ex_state_c<=DDR_TRANS;
          end

        WRITE_REG:ex_state_c<=IDLE;

        READ_REG:ex_state_c<=TX_VALID;

        TX_VALID:
          begin
            if(CHNL_TX_DATA_REN)
              ex_state_c<=WAIT_END;
            else
              ex_state_c<=ex_state_c;
          end

        WAIT_END:ex_state_c<=IDLE;

        default:ex_state_c<=IDLE;
      endcase
    end
end

// Associated variables logic
//1.CHNL_TX
//2.CHNL_TX_LEN
//3.CHNL_TX_CLK
//4.CHNL_TX_DATA
//5.CHNL_TX_LAST
//6.CHNL_TX_DATA_VALID
//7.CHNL_TX_OFF

assign CHNL_TX=((ex_state_c==READ_REG | ex_state_c==TX_VALID) ? 1'b1 : 1'b0);
assign CHNL_TX_LEN=2;//64BIT=2 8-OCTETS
assign CHNL_TX_CLK=clk;
assign CHNL_TX_DATA={48'b0,reg_bank[reg_addr]};
assign CHNL_TX_LAST=1'B1;
assign CHNL_TX_DATA_VALID=(ex_state_c==TX_VALID ? 1'b1 : 1'b0);
assign CHNL_TX_OFF=0;
assign fifo_rd=(ex_state_c==FETCH ? 1'b1 : 1'b0);

/*------------------------------

Register Bank

-------------------------------*/
wire reg_wr;
assign reg_wr=(ex_state_c==WRITE_REG ? 1'b1 : 1'b0);
reg [REG_DATA_WIDTH-1:0] fifo_data_reg;

always @(negedge clk, negedge rst_n)
if(!rst_n)
	fifo_data_reg<=16'd0;
else
	fifo_data_reg<=fifo_data;
	

always @(posedge clk)
begin
  if(reg_wr)
  reg_bank[reg_addr]<=fifo_data[REG_DATA_WIDTH-1:0];
end

myfifo u_fifo(
	.clock(clk),
	.data(CHNL_RX_DATA),
	.rdreq(fifo_rd),
	.wrreq(fifo_wr),
	.empty(fifo_empty),
	.full(fifo_full),
	.q(fifo_data)
	);

assign debug_state={e_state,r_state};

endmodule
