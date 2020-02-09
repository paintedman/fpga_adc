//-----------------------------------------------------------------
//                      Simple SDRAM Controller
//                              V0.1
//                        Ultra-Embedded.com
//                          Copyright 2015
//
//                 Email: admin@ultra-embedded.com
//-----------------------------------------------------------------
module sdram
(
    input           clk_i,
    input           rst_i, // reset imp 0->1

    // Wishbone Interface
    input           we_i,  // Operation: read=0 write=1
    input  [1:0]    sel_i, // num byte for read (4'b0011)
    input           cyc_i, // start operation (1) (read or write)
    input  [31:0]   addr_i,
    input  [15:0]   data_i,
    output [15:0]   data_o,
    output          stall_o, // slave cant accept data (1)
    output          ack_o,   // operation success (1) (read or write)

    // SDRAM Interface
    output          sdram_cke_o,
    output          sdram_cs_o,
    output          sdram_ras_o,
    output          sdram_cas_o,
    output          sdram_we_o,
    output [1:0]    sdram_dqm_o,
    output [12:0]   sdram_addr_o,
    output [1:0]    sdram_ba_o,
    inout [15:0]    sdram_data_io,
    output [3:0]    state
);

//-----------------------------------------------------------------
// Defines / Local params
//-----------------------------------------------------------------
localparam SDRAM_ADDR_W          = 24;
localparam SDRAM_COL_W           = 9;
localparam SDRAM_BANK_W          = 2;
localparam SDRAM_DQM_W           = 2;
localparam SDRAM_BANKS           = 2 ** SDRAM_BANK_W; //4,//
localparam SDRAM_ROW_W           = SDRAM_ADDR_W - SDRAM_COL_W - SDRAM_BANK_W; //13, //
localparam SDRAM_READ_LATENCY    = 2;
localparam SDRAM_MHZ             = 100; // Frequency
localparam SDRAM_START_DELAY     = 100000 / (1000 / SDRAM_MHZ); // 10000
localparam SDRAM_REFRESH_CYCLES  = (64000*SDRAM_MHZ) / SDRAM_REFRESH_CNT-1; // 781
localparam SDRAM_REFRESH_CNT     = 2 ** SDRAM_ROW_W; //8192

localparam CMD_W             = 4;
localparam CMD_NOP           = 4'b0111;
localparam CMD_ACTIVE        = 4'b0011;
localparam CMD_READ          = 4'b0101;
localparam CMD_WRITE         = 4'b0100;
localparam CMD_TERMINATE     = 4'b0110;
localparam CMD_PRECHARGE     = 4'b0010;
localparam CMD_REFRESH       = 4'b0001;
localparam CMD_LOAD_MODE     = 4'b0000;

// Mode: Burst Length = 4 bytes, CAS=2
localparam MODE_REG          = {3'b000,1'b0,2'b00,3'b010,1'b0,3'b111}; // full page

// SM states
localparam STATE_W           = 4;
localparam STATE_INIT        = 4'd0;
localparam STATE_DELAY       = 4'd1;
localparam STATE_IDLE        = 4'd2;
localparam STATE_ACTIVATE    = 4'd3;
localparam STATE_READ        = 4'd4;
localparam STATE_READ_WAIT   = 4'd5;
localparam STATE_WRITE0      = 4'd6;
localparam STATE_WRITE1      = 4'd7;
localparam STATE_PRECHARGE   = 4'd8;
localparam STATE_REFRESH     = 4'd9;
localparam STATE_TERMINATE   = 4'd10;

localparam AUTO_PRECHARGE    = 10;
localparam ALL_BANKS         = 10;
localparam SDRAM_DATA_W      = 16;
localparam CYCLE_TIME_NS     = 1000 / SDRAM_MHZ;

// SDRAM timing
localparam SDRAM_TRCD_CYCLES = (20 + (CYCLE_TIME_NS-1)) / CYCLE_TIME_NS;
localparam SDRAM_TRP_CYCLES  = (20 + (CYCLE_TIME_NS-1)) / CYCLE_TIME_NS;
localparam SDRAM_TRFC_CYCLES = (60 + (CYCLE_TIME_NS-1)) / CYCLE_TIME_NS;

//-----------------------------------------------------------------
// Registers / Wires
//-----------------------------------------------------------------
reg [CMD_W-1:0]        command_q;
reg [SDRAM_ROW_W-1:0]  addr_q;
reg [SDRAM_DATA_W-1:0] data_q;
reg                    data_rd_en_q;
reg [SDRAM_DQM_W-1:0]  dqm_q;
reg                    cke_q;
reg [SDRAM_BANK_W-1:0] bank_q;

// Buffer half word during read and write commands
reg [SDRAM_DATA_W-1:0] data_buffer_q;
reg [SDRAM_DQM_W-1:0]  dqm_buffer_q;

reg                    refresh_q;
reg [SDRAM_BANKS-1:0]  row_open_q;
reg [SDRAM_ROW_W-1:0]  active_row_q[0:SDRAM_BANKS-1];
reg  [STATE_W-1:0]     state_q;
reg  [STATE_W-1:0]     next_state_r;
reg  [STATE_W-1:0]     target_state_r;
reg  [STATE_W-1:0]     target_state_q;
reg  [STATE_W-1:0]     delay_state_q;

wire [SDRAM_DATA_W-1:0] sdram_data_in_w;
// Address bits
// SDRAM_ROW_W=13 SDRAM_COL_W=9      shift left 2 bits  addr_i[SDRAM_COL_W-1:0];//
wire [SDRAM_ROW_W-1:0]  addr_col_w  =  {{(SDRAM_ROW_W-SDRAM_COL_W){1'b0}}, addr_i[SDRAM_COL_W-1:0]}; // 9 bits
wire [SDRAM_ROW_W-1:0]  addr_row_w  = addr_i[SDRAM_ADDR_W:SDRAM_COL_W+2+1]; // [24:12]  Active command! 13 bits
wire [SDRAM_BANK_W-1:0] addr_bank_w = addr_i[SDRAM_COL_W+2:SDRAM_COL_W+2-1]; // [11:10]

//-----------------------------------------------------------------
// SDRAM State Machine
//-----------------------------------------------------------------
always @ *
begin
    next_state_r   = state_q;
    target_state_r = target_state_q;

    case (state_q)
    //-----------------------------------------
    // STATE_INIT
    //-----------------------------------------
    STATE_INIT :
    begin
        if (refresh_q)
            next_state_r = STATE_IDLE;
    end
    //-----------------------------------------
    // STATE_IDLE
    //-----------------------------------------
    STATE_IDLE :
    begin
        // Pending refresh
        // Note: tRAS (open row time) cannot be exceeded due to periodic
        //        auto refreshes.
        if (refresh_q)
        begin
            // Close open rows, then refresh
            if (|row_open_q)
                next_state_r = STATE_PRECHARGE;
            else
                next_state_r = STATE_REFRESH;

            target_state_r = STATE_REFRESH;
        end
        // Access request
        else if (cyc_i)
        begin
            // Open row hit
            if (row_open_q[addr_bank_w] && addr_row_w == active_row_q[addr_bank_w])
            begin
                if (we_i)
                    next_state_r = STATE_WRITE0;
                else
                    next_state_r = STATE_READ;
            end
            // Row miss, close row, open new row
            else if (row_open_q[addr_bank_w])
            begin
                next_state_r   = STATE_PRECHARGE;

                if (we_i)
                    target_state_r = STATE_WRITE0;
                else
                    target_state_r = STATE_READ;
            end
            // No open row, open row
            else
            begin
                next_state_r   = STATE_ACTIVATE;

                if (we_i)
                    target_state_r = STATE_WRITE0;
                else
                    target_state_r = STATE_READ;
            end
        end
    end
    //-----------------------------------------
    // STATE_ACTIVATE
    //-----------------------------------------
    STATE_ACTIVATE :
    begin
        // Proceed to read or write state
        next_state_r = target_state_r;
    end
    //-----------------------------------------
    // STATE_READ
    //-----------------------------------------
    STATE_READ :
    begin
        next_state_r = STATE_READ_WAIT;
    end
    //-----------------------------------------
    // STATE_READ_WAIT
    //-----------------------------------------
    STATE_READ_WAIT :
    begin
        /*next_state_r = STATE_TERMINATE;// STATE_IDLE;

        // Another pending read request (with no refresh pending)
        if (!refresh_q && cyc_i && !we_i)
        begin
            // Open row hit
            if (row_open_q[addr_bank_w] && addr_row_w == active_row_q[addr_bank_w]) next_state_r = STATE_READ;
        end*/
        if(!cyc_i) next_state_r = STATE_TERMINATE;
    end
    //-----------------------------------------
    // STATE_WRITE0
    //-----------------------------------------
    STATE_WRITE0 :
    begin
        next_state_r = STATE_WRITE1;
    end
    //-----------------------------------------
    // STATE_WRITE1
    //-----------------------------------------
    STATE_WRITE1 :
    begin
        next_state_r = STATE_IDLE;

        // Another pending write request (with no refresh pending)
        if (!refresh_q && cyc_i && we_i) // continue write
        begin
            // Open row hit
            if (row_open_q[addr_bank_w] && addr_row_w == active_row_q[addr_bank_w]) next_state_r = STATE_WRITE1;
            else next_state_r = STATE_TERMINATE;
        end
        else next_state_r = STATE_TERMINATE;
    end
    //-----------------------------------------
    // STATE_PRECHARGE
    //-----------------------------------------
    STATE_PRECHARGE :
    begin
        // Closing row to perform refresh
        if (target_state_r == STATE_REFRESH)
            next_state_r = STATE_REFRESH;
        // Must be closing row to open another
        else
            next_state_r = STATE_ACTIVATE;
    end
    //-----------------------------------------
    // STATE_REFRESH
    //-----------------------------------------
    STATE_REFRESH :
    begin
        next_state_r = STATE_IDLE;
    end
    //-----------------------------------------
    // STATE_DELAY
    //-----------------------------------------
    STATE_DELAY :
    begin
        next_state_r = delay_state_q;
    end
    //-----------------------------------------
    // STATE_TERMINATE
    //-----------------------------------------
    STATE_TERMINATE :
    begin
        next_state_r = STATE_IDLE;
    end

    default:
        ;
   endcase
end

//-----------------------------------------------------------------
// Delays
//-----------------------------------------------------------------
localparam DELAY_W = 4;

reg [DELAY_W-1:0] delay_q;
reg [DELAY_W-1:0] delay_r;

/* verilator lint_off WIDTH */

always @ *
begin
    case (state_q)
    //-----------------------------------------
    // STATE_ACTIVATE
    //-----------------------------------------
    STATE_ACTIVATE :
    begin
        // tRCD (ACTIVATE -> READ / WRITE)
        delay_r = SDRAM_TRCD_CYCLES;
    end
    //-----------------------------------------
    // STATE_READ_WAIT
    //-----------------------------------------
    STATE_READ_WAIT :
    begin
        delay_r = SDRAM_READ_LATENCY;

        // Another pending read request (with no refresh pending)
        if (!refresh_q && cyc_i && !we_i)
        begin
            // Open row hit
            if (row_open_q[addr_bank_w] && addr_row_w == active_row_q[addr_bank_w])
                delay_r = 4'd0;
        end
    end
    //-----------------------------------------
    // STATE_PRECHARGE
    //-----------------------------------------
    STATE_PRECHARGE :
    begin
        // tRP (PRECHARGE -> ACTIVATE)
        delay_r = SDRAM_TRP_CYCLES;
    end
    //-----------------------------------------
    // STATE_REFRESH
    //-----------------------------------------
    STATE_REFRESH :
    begin
        // tRFC
        delay_r = SDRAM_TRFC_CYCLES;
    end
    //-----------------------------------------
    // STATE_DELAY
    //-----------------------------------------
    STATE_DELAY:
    begin
        delay_r = delay_q - 4'd1;
    end
    //-----------------------------------------
    // STATE_TERMINATE
    //-----------------------------------------
    STATE_TERMINATE:
    begin
        //delay_r = 0;//delay_q - 4'd1;
    end

    //-----------------------------------------
    // Others
    //-----------------------------------------
    default:
    begin
        delay_r = {DELAY_W{1'b0}};
    end
    endcase
end


/* verilator lint_on WIDTH */

//----- Record target state
always @ (posedge rst_i or posedge clk_i)
if (rst_i)
    target_state_q   <= STATE_IDLE;
else
    target_state_q   <= target_state_r;

//----- Record delayed state
always @ (posedge rst_i or posedge clk_i)
if (rst_i)
    delay_state_q   <= STATE_IDLE;
// On entering into delay state, record intended next state
else if (state_q != STATE_DELAY && delay_r != {DELAY_W{1'b0}})
    delay_state_q   <= next_state_r;

//----- Update actual state
always @ (posedge rst_i or posedge clk_i)
if (rst_i) state_q   <= STATE_INIT;
// Delaying...
else if (delay_r != {DELAY_W{1'b0}})  state_q   <= STATE_DELAY;
else  state_q   <= next_state_r;

//----- Update delay flops
always @ (posedge rst_i or posedge clk_i)
if (rst_i)
    delay_q   <= {DELAY_W{1'b0}};
else
    delay_q   <= delay_r;

//-----------------------------------------------------------------
// Refresh counter
//-----------------------------------------------------------------
localparam REFRESH_CNT_W = 17;

reg [REFRESH_CNT_W-1:0] refresh_timer_q;
always @ (posedge rst_i or posedge clk_i)
if (rst_i)
    refresh_timer_q <= SDRAM_START_DELAY + 100; // 10100 (101 mks)
else if (refresh_timer_q == {REFRESH_CNT_W{1'b0}})
    refresh_timer_q <= SDRAM_REFRESH_CYCLES;  // 781 (7.81 mks)
else
    refresh_timer_q <= refresh_timer_q - 1;

always @ (posedge rst_i or posedge clk_i)
if (rst_i)
    refresh_q <= 1'b0;
else if (refresh_timer_q == {REFRESH_CNT_W{1'b0}})
    refresh_q <= 1'b1;
else if (state_q == STATE_REFRESH)
    refresh_q <= 1'b0;


//-----------------------------------------------------------------
// Command Output
//-----------------------------------------------------------------
integer idx;

always @ (posedge rst_i or posedge clk_i)
if (rst_i)
begin
    command_q       <= CMD_NOP;
    data_q          <= 16'b0;
    addr_q          <= {SDRAM_ROW_W{1'b0}};
    bank_q          <= {SDRAM_BANK_W{1'b0}};
    cke_q           <= 1'b0;
    dqm_q           <= {SDRAM_DQM_W{1'b0}};
    data_rd_en_q    <= 1'b1;
    dqm_buffer_q    <= {SDRAM_DQM_W{1'b0}};

    for (idx=0;idx<SDRAM_BANKS;idx=idx+1)
        active_row_q[idx] <= {SDRAM_ROW_W{1'b0}};

    row_open_q      <= {SDRAM_BANKS{1'b0}};
end
else
begin
    case (state_q)
    //-----------------------------------------
    // STATE_IDLE / Default (delays)
    //-----------------------------------------
    default:
    begin
        // Default
        command_q    <= CMD_NOP;
        addr_q       <= {SDRAM_ROW_W{1'b0}};
        bank_q       <= {SDRAM_BANK_W{1'b0}};
        data_rd_en_q <= 1'b1;
    end
    //-----------------------------------------
    // STATE_INIT
    //-----------------------------------------
    STATE_INIT:
    begin
        // Assert CKE
        if (refresh_timer_q == 50)
        begin
            // Assert CKE after 100uS
            cke_q <= 1'b1;
        end
        // PRECHARGE
        else if (refresh_timer_q == 40)
        begin
            // Precharge all banks
            command_q           <= CMD_PRECHARGE;
            addr_q[ALL_BANKS]   <= 1'b1;
        end
        // 2 x REFRESH (with at least tREF wait)
        else if (refresh_timer_q == 20 || refresh_timer_q == 30)
        begin
            command_q <= CMD_REFRESH;
        end
        // Load mode register
        else if (refresh_timer_q == 10)
        begin
            command_q <= CMD_LOAD_MODE;
            addr_q    <= MODE_REG;
        end
        // Other cycles during init - just NOP
        else
        begin
            command_q   <= CMD_NOP;
            addr_q      <= {SDRAM_ROW_W{1'b0}};
            bank_q      <= {SDRAM_BANK_W{1'b0}};
        end
    end
    //-----------------------------------------
    // STATE_ACTIVATE
    //-----------------------------------------
    STATE_ACTIVATE :
    begin
        // Select a row and activate it
        command_q     <= CMD_ACTIVE;
        addr_q        <= addr_row_w;
        bank_q        <= addr_bank_w;

        active_row_q[addr_bank_w]  <= addr_row_w;
        row_open_q[addr_bank_w]    <= 1'b1;
    end
    //-----------------------------------------
    // STATE_PRECHARGE
    //-----------------------------------------
    STATE_PRECHARGE :
    begin
        // Precharge due to refresh, close all banks
        if (target_state_r == STATE_REFRESH)
        begin
            // Precharge all banks
            command_q           <= CMD_PRECHARGE;
            addr_q[ALL_BANKS]   <= 1'b1;
            row_open_q          <= {SDRAM_BANKS{1'b0}};
        end
        else
        begin
            // Precharge specific banks
            command_q           <= CMD_PRECHARGE;
            addr_q[ALL_BANKS]   <= 1'b0;
            bank_q              <= addr_bank_w;

            row_open_q[addr_bank_w] <= 1'b0;
        end
    end
    //-----------------------------------------
    // STATE_REFRESH
    //-----------------------------------------
    STATE_REFRESH :
    begin
        // Auto refresh
        command_q   <= CMD_REFRESH;
        addr_q      <= {SDRAM_ROW_W{1'b0}};
        bank_q      <= {SDRAM_BANK_W{1'b0}};
    end
    //-----------------------------------------
    // STATE_READ
    //-----------------------------------------
    STATE_READ :
    begin
        command_q   <= CMD_READ;
        addr_q      <= addr_col_w;
        bank_q      <= addr_bank_w;

        // Disable auto precharge (auto close of row)
        addr_q[AUTO_PRECHARGE]  <= 1'b0;

        // Read mask (all bytes in burst)
        dqm_q       <= {SDRAM_DQM_W{1'b0}};
    end
    //-----------------------------------------
    // STATE_WRITE0
    //-----------------------------------------
    STATE_WRITE0 :
    begin
        command_q       <= CMD_WRITE;
        addr_q          <= addr_col_w;
        bank_q          <= addr_bank_w;
        data_q          <= data_i; // to sdram bus

        // Disable auto precharge (auto close of row)
        addr_q[AUTO_PRECHARGE]  <= 1'b0;

        // Write mask
        dqm_q           <= ~sel_i;
        data_rd_en_q    <= 1'b0;
    end
    //-----------------------------------------
    // STATE_WRITE1
    //-----------------------------------------
    STATE_WRITE1 :
    begin
        // Burst continuation
        command_q   <= CMD_NOP;
        data_q      <= data_i; // to sdram bus
        // Disable auto precharge (auto close of row)
        //addr_q[AUTO_PRECHARGE]  <= 1'b0;
        addr_q[AUTO_PRECHARGE]  <= 1'b1;    // Need auto precharge after write burst terminate! Atherwise data lost
        // Write mask
        dqm_q       <= ~sel_i;
    end
    //-----------------------------------------
    // STATE_TERMINATE
    //-----------------------------------------
	 STATE_TERMINATE:
	 begin
        // Burst terminate
        command_q   <= CMD_TERMINATE;
        // Disable auto precharge (auto close of row)
        addr_q[AUTO_PRECHARGE]  <= 1'b0;
        //addr_q[AUTO_PRECHARGE]  <= 1'b1;
    end
    endcase
end

//-----------------------------------------------------------------
// Record read events
//-----------------------------------------------------------------
reg [SDRAM_READ_LATENCY+1:0]  rd_q;  // [3:0]

always @ (posedge rst_i or posedge clk_i)
if (rst_i)
    rd_q    <= {(SDRAM_READ_LATENCY+2){1'b0}}; // rd_q<=4'd0;
else
    rd_q    <= {rd_q[SDRAM_READ_LATENCY:0], (state_q == STATE_READ)}; // shift left and set low bit

//-----------------------------------------------------------------
// Data Buffer
//-----------------------------------------------------------------
// Buffer upper 16-bits of write data so write command can be accepted
// in WRITE0. Also buffer lower 16-bits of read data.

always @ (posedge rst_i or posedge clk_i)
if (rst_i)   data_buffer_q <= 16'b0;
else if (rd_q[SDRAM_READ_LATENCY])     data_buffer_q <= sdram_data_io; // check bit

// Read data output
assign data_o = data_buffer_q;

//-----------------------------------------------------------------
// Wishbone ACK
//-----------------------------------------------------------------
reg ack_q;

always @ (posedge rst_i or posedge clk_i)
if (rst_i)
    ack_q   <= 1'b0;
else
begin
    //if (state_q == STATE_WRITE1)         ack_q <= 1'b1; // logic ACK
    //else
    if (rd_q[SDRAM_READ_LATENCY-1]) ack_q <= 1'b1; // check bit and set ack
    else  ack_q <= 1'b0;
end

//-------------
reg data_en;

always @ (posedge rst_i or posedge clk_i)
if (rst_i)
    data_en   <= 1'b0;
else
begin
    if(ack_q) data_en<=1'b1;
    else if (cyc_i==0) data_en<=1'b0;
end

//assign ack_o  = ack_q;
assign ack_o  = data_en;



// Accept wishbone command in READ or WRITE0 states
assign stall_o = ~(state_q == STATE_READ || state_q == STATE_WRITE0);
assign sdram_data_io   = data_rd_en_q ? 16'bz : data_q;
//assign sdram_data_in_w = sdram_data_io;
assign sdram_cke_o  = cke_q;
assign sdram_cs_o   = command_q[3];
assign sdram_ras_o  = command_q[2];
assign sdram_cas_o  = command_q[1];
assign sdram_we_o   = command_q[0];
assign sdram_dqm_o  = dqm_q;
assign sdram_ba_o   = bank_q;
assign sdram_addr_o = addr_q;
assign state = state_q;
endmodule
