`timescale 1ns/1ps

module axi512_to_axi256 #(
    parameter ADDR_WIDTH = 48,
    parameter S_DATA_WIDTH = 512,
    parameter M_DATA_WIDTH = 256,
    parameter ID_WIDTH = 4,
    parameter OUTSTANDING = 4
) (
    input  wire                      aclk,
    input  wire                      aresetn,

    input  wire [ID_WIDTH-1:0]       s_awid,
    input  wire [ADDR_WIDTH-1:0]     s_awaddr,
    input  wire [7:0]                s_awlen,
    input  wire [2:0]                s_awsize,
    input  wire [1:0]                s_awburst,
    input  wire                      s_awvalid,
    output wire                      s_awready,

    input  wire [S_DATA_WIDTH-1:0]   s_wdata,
    input  wire [S_DATA_WIDTH/8-1:0] s_wstrb,
    input  wire                      s_wlast,
    input  wire                      s_wvalid,
    output wire                      s_wready,

    output reg  [ID_WIDTH-1:0]       s_bid,
    output reg  [1:0]                s_bresp,
    output reg                       s_bvalid,
    input  wire                      s_bready,

    input  wire [ID_WIDTH-1:0]       s_arid,
    input  wire [ADDR_WIDTH-1:0]     s_araddr,
    input  wire [7:0]                s_arlen,
    input  wire [2:0]                s_arsize,
    input  wire [1:0]                s_arburst,
    input  wire                      s_arvalid,
    output wire                      s_arready,

    output reg  [ID_WIDTH-1:0]       s_rid,
    output reg  [S_DATA_WIDTH-1:0]   s_rdata,
    output reg  [1:0]                s_rresp,
    output reg                       s_rlast,
    output reg                       s_rvalid,
    input  wire                      s_rready,

    output reg  [ID_WIDTH-1:0]       m_awid,
    output reg  [ADDR_WIDTH-1:0]     m_awaddr,
    output reg  [7:0]                m_awlen,
    output reg  [2:0]                m_awsize,
    output reg  [1:0]                m_awburst,
    output reg                       m_awvalid,
    input  wire                      m_awready,

    output reg  [M_DATA_WIDTH-1:0]   m_wdata,
    output reg  [M_DATA_WIDTH/8-1:0] m_wstrb,
    output reg                       m_wlast,
    output reg                       m_wvalid,
    input  wire                      m_wready,

    input  wire [ID_WIDTH-1:0]       m_bid,
    input  wire [1:0]                m_bresp,
    input  wire                      m_bvalid,
    output reg                       m_bready,

    output reg  [ID_WIDTH-1:0]       m_arid,
    output reg  [ADDR_WIDTH-1:0]     m_araddr,
    output reg  [7:0]                m_arlen,
    output reg  [2:0]                m_arsize,
    output reg  [1:0]                m_arburst,
    output reg                       m_arvalid,
    input  wire                      m_arready,

    input  wire [ID_WIDTH-1:0]       m_rid,
    input  wire [M_DATA_WIDTH-1:0]   m_rdata,
    input  wire [1:0]                m_rresp,
    input  wire                      m_rlast,
    input  wire                      m_rvalid,
    output reg                       m_rready
);
    localparam S_BYTES = S_DATA_WIDTH / 8;
    localparam M_BYTES = M_DATA_WIDTH / 8;
    localparam BURST_FIXED = 2'b00;
    localparam BURST_INCR  = 2'b01;
    localparam BURST_WRAP  = 2'b10;

    reg [ID_WIDTH-1:0]   aw_id_q    [0:OUTSTANDING-1];
    reg [ADDR_WIDTH-1:0] aw_addr_q  [0:OUTSTANDING-1];
    reg [7:0]            aw_len_q   [0:OUTSTANDING-1];
    reg [2:0]            aw_size_q  [0:OUTSTANDING-1];
    reg [1:0]            aw_burst_q [0:OUTSTANDING-1];
    integer aw_wr_ptr, aw_rd_ptr, aw_count;

    reg [ID_WIDTH-1:0]   ar_id_q    [0:OUTSTANDING-1];
    reg [ADDR_WIDTH-1:0] ar_addr_q  [0:OUTSTANDING-1];
    reg [7:0]            ar_len_q   [0:OUTSTANDING-1];
    reg [2:0]            ar_size_q  [0:OUTSTANDING-1];
    reg [1:0]            ar_burst_q [0:OUTSTANDING-1];
    integer ar_wr_ptr, ar_rd_ptr, ar_count;

    reg [ID_WIDTH-1:0]   w_id;
    reg [ADDR_WIDTH-1:0] w_addr;
    reg [7:0]            w_len;
    reg [2:0]            w_size;
    reg [1:0]            w_burst;
    reg [7:0]            w_beat;
    reg [1:0]            w_resp_acc;
    reg [S_DATA_WIDTH-1:0]   w_data_hold;
    reg [S_DATA_WIDTH/8-1:0] w_strb_hold;
    reg                  w_last_hold;
    reg [2:0]            w_state;
    reg                  w_half;
    reg                  w_have_active;
    reg [8:0]            w_total_subbeats;
    reg [8:0]            w_sent_subbeats;
    reg                  w_group_done;

    reg [ID_WIDTH-1:0]   r_id;
    reg [ADDR_WIDTH-1:0] r_addr;
    reg [7:0]            r_len;
    reg [2:0]            r_size;
    reg [1:0]            r_burst;
    reg [7:0]            r_beat;
    reg [1:0]            r_resp_acc;
    reg [S_DATA_WIDTH-1:0] r_data_acc;
    reg [2:0]            r_state;
    reg                  r_half;
    reg                  r_need_low;
    reg                  r_need_high;
    reg [8:0]            r_total_subbeats;
    reg [8:0]            r_recv_subbeats;

    integer i;

    wire aw_push;
    wire ar_push;
    wire aw_pop;
    wire ar_pop;

    assign s_awready = (aw_count < OUTSTANDING);
    assign s_arready = (ar_count < OUTSTANDING);
    assign s_wready  = (w_state == 2'd1) && !s_bvalid;
    assign aw_push = s_awvalid && s_awready;
    assign ar_push = s_arvalid && s_arready;
    assign aw_pop = (w_state == 2'd0) && (aw_count > 0) && !s_bvalid;
    assign ar_pop = (r_state == 2'd0) && (ar_count > 0) && !s_rvalid;

    function [1:0] worst_resp;
        input [1:0] a;
        input [1:0] b;
        begin
            if (a == 2'b11 || b == 2'b11)
                worst_resp = 2'b11;
            else if (a == 2'b10 || b == 2'b10)
                worst_resp = 2'b10;
            else if (a == 2'b01 || b == 2'b01)
                worst_resp = 2'b01;
            else
                worst_resp = 2'b00;
        end
    endfunction

    function [ADDR_WIDTH-1:0] next_addr;
        input [ADDR_WIDTH-1:0] addr;
        input [2:0]            size;
        input [7:0]            len;
        input [1:0]            burst;
        reg [ADDR_WIDTH-1:0] step;
        reg [ADDR_WIDTH-1:0] span;
        reg [ADDR_WIDTH-1:0] base;
        reg [ADDR_WIDTH-1:0] offset;
        begin
            step = {{(ADDR_WIDTH-1){1'b0}}, 1'b1} << size;
            if (burst == BURST_FIXED) begin
                next_addr = addr;
            end else if (burst == BURST_WRAP) begin
                span = step * (len + 1);
                base = (addr / span) * span;
                offset = addr + step - base;
                if (offset >= span)
                    next_addr = base + (offset - span);
                else
                    next_addr = base + offset;
            end else begin
                if ((addr % step) != 0)
                    next_addr = ((addr / step) + 1'b1) * step;
                else
                    next_addr = addr + step;
            end
        end
    endfunction

    function first_unaligned_incr;
        input [ADDR_WIDTH-1:0] addr;
        input [2:0]            size;
        input [7:0]            len;
        input [1:0]            burst;
        input [7:0]            beat;
        reg [ADDR_WIDTH-1:0] step;
        begin
            step = {{(ADDR_WIDTH-1){1'b0}}, 1'b1} << size;
            first_unaligned_incr = (burst == BURST_INCR) && (len != 0) &&
                                   (beat == 0) && ((addr % step) != 0);
        end
    endfunction

    function half_has_strobe;
        input [S_DATA_WIDTH/8-1:0] strb;
        input half;
        integer k;
        begin
            half_has_strobe = 1'b0;
            for (k = 0; k < M_BYTES; k = k + 1)
                if (strb[k + (half ? M_BYTES : 0)])
                    half_has_strobe = 1'b1;
        end
    endfunction

    function read_needs_half;
        input [ADDR_WIDTH-1:0] addr;
        input [2:0] size;
        input half;
        integer start_b;
        integer end_b;
        integer lo;
        integer hi;
        begin
            start_b = addr[5:0];
            end_b = start_b + (1 << size) - 1;
            lo = half ? M_BYTES : 0;
            hi = half ? (S_BYTES - 1) : (M_BYTES - 1);
            read_needs_half = (start_b <= hi) && (end_b >= lo);
        end
    endfunction

    function beat_needs_half;
        input [ADDR_WIDTH-1:0] addr;
        input [2:0] size;
        input [7:0] len;
        input [1:0] burst;
        input [7:0] beat;
        input half;
        integer start_b;
        integer end_b;
        integer lo;
        integer hi;
        reg [ADDR_WIDTH-1:0] step;
        begin
            step = {{(ADDR_WIDTH-1){1'b0}}, 1'b1} << size;
            start_b = addr[5:0];
            if (first_unaligned_incr(addr, size, len, burst, beat))
                end_b = (((addr / step) + 1'b1) * step) - {addr[ADDR_WIDTH-1:6], 6'b000000} - 1;
            else
                end_b = start_b + (1 << size) - 1;
            lo = half ? M_BYTES : 0;
            hi = half ? (S_BYTES - 1) : (M_BYTES - 1);
            beat_needs_half = (start_b <= hi) && (end_b >= lo);
        end
    endfunction

    function [8:0] subbeat_count;
        input [ADDR_WIDTH-1:0] addr;
        input [2:0] size;
        input [7:0] len;
        input [1:0] burst;
        reg [ADDR_WIDTH-1:0] a;
        integer beat;
        begin
            a = addr;
            subbeat_count = 0;
            for (beat = 0; beat < 256; beat = beat + 1) begin
                if (beat <= len) begin
                    if (beat_needs_half(a, size, len, burst, beat[7:0], 1'b0))
                        subbeat_count = subbeat_count + 1'b1;
                    if (beat_needs_half(a, size, len, burst, beat[7:0], 1'b1))
                        subbeat_count = subbeat_count + 1'b1;
                    a = next_addr(a, size, len, burst);
                end
            end
        end
    endfunction

    function [8:0] group_subbeat_count;
        input [ADDR_WIDTH-1:0] addr;
        input [2:0] size;
        input [7:0] len;
        input [1:0] burst;
        input [7:0] beat_start;
        reg [ADDR_WIDTH-1:0] a;
        integer beat;
        begin
            a = addr;
            group_subbeat_count = 0;
            for (beat = 0; beat < 256; beat = beat + 1) begin
                if ((beat_start + beat) <= len) begin
                    if (beat_needs_half(a, size, len, burst, beat_start + beat, 1'b0))
                        group_subbeat_count = group_subbeat_count + 1'b1;
                    if (beat_needs_half(a, size, len, burst, beat_start + beat, 1'b1))
                        group_subbeat_count = group_subbeat_count + 1'b1;
                    if (first_unaligned_incr(a, size, len, burst, beat_start + beat)) begin
                        beat = 256;
                    end else begin
                        a = next_addr(a, size, len, burst);
                    end
                end
            end
        end
    endfunction

    always @(posedge aclk) begin
        if (!aresetn) begin
            aw_wr_ptr <= 0;
            aw_rd_ptr <= 0;
            aw_count <= 0;
            ar_wr_ptr <= 0;
            ar_rd_ptr <= 0;
            ar_count <= 0;
            w_state <= 0;
            r_state <= 0;
            m_awvalid <= 0;
            m_wvalid <= 0;
            m_bready <= 0;
            m_arvalid <= 0;
            m_rready <= 0;
            s_bvalid <= 0;
            s_rvalid <= 0;
            s_rlast <= 0;
            m_awlen <= 0;
            m_awsize <= 3'd5;
            m_awburst <= BURST_INCR;
            m_wlast <= 1'b1;
            m_arlen <= 0;
            m_arsize <= 3'd5;
            m_arburst <= BURST_INCR;
        end else begin
            if (aw_push) begin
                aw_id_q[aw_wr_ptr] <= s_awid;
                aw_addr_q[aw_wr_ptr] <= s_awaddr;
                aw_len_q[aw_wr_ptr] <= s_awlen;
                aw_size_q[aw_wr_ptr] <= s_awsize;
                aw_burst_q[aw_wr_ptr] <= s_awburst;
                aw_wr_ptr <= (aw_wr_ptr == OUTSTANDING-1) ? 0 : aw_wr_ptr + 1;
            end

            if (ar_push) begin
                ar_id_q[ar_wr_ptr] <= s_arid;
                ar_addr_q[ar_wr_ptr] <= s_araddr;
                ar_len_q[ar_wr_ptr] <= s_arlen;
                ar_size_q[ar_wr_ptr] <= s_arsize;
                ar_burst_q[ar_wr_ptr] <= s_arburst;
                ar_wr_ptr <= (ar_wr_ptr == OUTSTANDING-1) ? 0 : ar_wr_ptr + 1;
            end

            if (s_bvalid && s_bready)
                s_bvalid <= 1'b0;
            if (s_rvalid && s_rready)
                s_rvalid <= 1'b0;

            case (w_state)
                2'd0: begin
                    m_awvalid <= 1'b0;
                    m_wvalid <= 1'b0;
                    m_bready <= 1'b0;
                    if (aw_pop) begin
                        w_id <= aw_id_q[aw_rd_ptr];
                        w_addr <= aw_addr_q[aw_rd_ptr];
                        w_len <= aw_len_q[aw_rd_ptr];
                        w_size <= aw_size_q[aw_rd_ptr];
                        w_burst <= aw_burst_q[aw_rd_ptr];
                        w_beat <= 0;
                        w_resp_acc <= 2'b00;
                        w_total_subbeats <= group_subbeat_count(aw_addr_q[aw_rd_ptr], aw_size_q[aw_rd_ptr], aw_len_q[aw_rd_ptr], aw_burst_q[aw_rd_ptr], 8'd0);
                        w_sent_subbeats <= 0;
                        w_group_done <= 1'b0;
                        aw_rd_ptr <= (aw_rd_ptr == OUTSTANDING-1) ? 0 : aw_rd_ptr + 1;
                        w_state <= 3'd4;
                    end
                end
                3'd4: begin
                    m_awid <= w_id;
                    w_total_subbeats <= group_subbeat_count(w_addr, w_size, w_len, w_burst, w_beat);
                    w_sent_subbeats <= 0;
                    w_group_done <= 1'b0;
                    if (beat_needs_half(w_addr, w_size, w_len, w_burst, w_beat, 1'b0))
                        m_awaddr <= {w_addr[ADDR_WIDTH-1:6], 6'b000000};
                    else
                        m_awaddr <= {w_addr[ADDR_WIDTH-1:6], 6'b000000} + M_BYTES;
                    m_awlen <= group_subbeat_count(w_addr, w_size, w_len, w_burst, w_beat) - 1'b1;
                    m_awsize <= 3'd5;
                    m_awburst <= w_burst;
                    m_awvalid <= 1'b1;
                    if (m_awvalid && m_awready) begin
                        m_awvalid <= 1'b0;
                        w_state <= 3'd1;
                    end
                end
                2'd1: begin
                    if (s_wvalid && s_wready) begin
                        w_data_hold <= s_wdata;
                        w_strb_hold <= s_wstrb;
                        w_last_hold <= s_wlast;
                        w_half <= 1'b0;
                        w_have_active <= beat_needs_half(w_addr, w_size, w_len, w_burst, w_beat, 1'b0);
                        w_state <= 3'd2;
                    end
                end
                2'd2: begin
                    if (!w_have_active) begin
                        if (w_half == 1'b0) begin
                            w_half <= 1'b1;
                            w_have_active <= beat_needs_half(w_addr, w_size, w_len, w_burst, w_beat, 1'b1);
                        end else begin
                            if (w_beat == w_len || w_last_hold) begin
                                w_group_done <= 1'b1;
                                m_bready <= 1'b1;
                                w_state <= 3'd3;
                            end else if (w_sent_subbeats == w_total_subbeats) begin
                                w_addr <= next_addr(w_addr, w_size, w_len, w_burst);
                                w_beat <= w_beat + 1'b1;
                                w_group_done <= 1'b0;
                                m_bready <= 1'b1;
                                w_state <= 3'd3;
                            end else begin
                                w_addr <= next_addr(w_addr, w_size, w_len, w_burst);
                                w_beat <= w_beat + 1'b1;
                                w_state <= 3'd1;
                            end
                        end
                    end else begin
                        if (w_half) begin
                            m_wdata <= w_data_hold[511:256];
                            m_wstrb <= w_strb_hold[63:32];
                        end else begin
                            m_wdata <= w_data_hold[255:0];
                            m_wstrb <= w_strb_hold[31:0];
                        end
                        m_wlast <= (w_sent_subbeats == (w_total_subbeats - 1'b1));
                        m_wvalid <= 1'b1;
                        if (m_wvalid && m_wready) begin
                            m_wvalid <= 1'b0;
                            w_sent_subbeats <= w_sent_subbeats + 1'b1;
                            if (w_sent_subbeats == (w_total_subbeats - 1'b1)) begin
                                if (w_half == 1'b1 || !beat_needs_half(w_addr, w_size, w_len, w_burst, w_beat, 1'b1)) begin
                                    if (w_beat == w_len || w_last_hold)
                                        w_group_done <= 1'b1;
                                    else begin
                                        w_addr <= next_addr(w_addr, w_size, w_len, w_burst);
                                        w_beat <= w_beat + 1'b1;
                                        w_group_done <= 1'b0;
                                    end
                                    m_bready <= 1'b1;
                                    w_state <= 3'd3;
                                end else begin
                                    w_half <= 1'b1;
                                    w_have_active <= beat_needs_half(w_addr, w_size, w_len, w_burst, w_beat, 1'b1);
                                end
                            end else
                            if (w_half == 1'b0) begin
                                w_half <= 1'b1;
                                w_have_active <= beat_needs_half(w_addr, w_size, w_len, w_burst, w_beat, 1'b1);
                            end else begin
                                if (w_beat == w_len || w_last_hold) begin
                                    w_group_done <= 1'b1;
                                    m_bready <= 1'b1;
                                    w_state <= 3'd3;
                                end else begin
                                    w_addr <= next_addr(w_addr, w_size, w_len, w_burst);
                                    w_beat <= w_beat + 1'b1;
                                    w_state <= 3'd1;
                                end
                            end
                        end
                    end
                end
                2'd3: begin
                    if (m_bvalid && m_bready) begin
                        w_resp_acc <= worst_resp(w_resp_acc, m_bresp);
                        m_bready <= 1'b0;
                        if (w_group_done) begin
                            s_bid <= w_id;
                            s_bresp <= worst_resp(w_resp_acc, m_bresp);
                            s_bvalid <= 1'b1;
                            w_state <= 3'd0;
                        end else begin
                            w_state <= 3'd4;
                        end
                    end
                end
            endcase

            case (r_state)
                2'd0: begin
                    m_arvalid <= 1'b0;
                    m_rready <= 1'b0;
                    if (ar_pop) begin
                        r_id <= ar_id_q[ar_rd_ptr];
                        r_addr <= ar_addr_q[ar_rd_ptr];
                        r_len <= ar_len_q[ar_rd_ptr];
                        r_size <= ar_size_q[ar_rd_ptr];
                        r_burst <= ar_burst_q[ar_rd_ptr];
                        r_beat <= 0;
                        r_total_subbeats <= subbeat_count(ar_addr_q[ar_rd_ptr], ar_size_q[ar_rd_ptr], ar_len_q[ar_rd_ptr], ar_burst_q[ar_rd_ptr]);
                        r_recv_subbeats <= 0;
                        ar_rd_ptr <= (ar_rd_ptr == OUTSTANDING-1) ? 0 : ar_rd_ptr + 1;
                        r_state <= 3'd1;
                    end
                end
                2'd1: begin
                    m_arid <= r_id;
                    if (read_needs_half(r_addr, r_size, 1'b0))
                        m_araddr <= {r_addr[ADDR_WIDTH-1:6], 6'b000000};
                    else
                        m_araddr <= {r_addr[ADDR_WIDTH-1:6], 6'b000000} + M_BYTES;
                    m_arlen <= r_total_subbeats[7:0] - 1'b1;
                    m_arsize <= 3'd5;
                    m_arburst <= r_burst;
                    m_arvalid <= 1'b1;
                    if (m_arvalid && m_arready) begin
                        m_arvalid <= 1'b0;
                        r_state <= 3'd2;
                    end
                end
                3'd2: begin
                    r_data_acc <= {S_DATA_WIDTH{1'b0}};
                    r_resp_acc <= 2'b00;
                    r_need_low <= read_needs_half(r_addr, r_size, 1'b0);
                    r_need_high <= read_needs_half(r_addr, r_size, 1'b1);
                    r_half <= 1'b0;
                    r_state <= 3'd3;
                end
                3'd3: begin
                    if ((r_half == 1'b0 && !r_need_low) || (r_half == 1'b1 && !r_need_high)) begin
                        if (r_half == 1'b0) begin
                            r_half <= 1'b1;
                        end else begin
                            s_rid <= r_id;
                            s_rdata <= r_data_acc;
                            s_rresp <= r_resp_acc;
                            s_rlast <= (r_beat == r_len);
                            s_rvalid <= 1'b1;
                            r_state <= 3'd4;
                        end
                    end else begin
                        m_rready <= 1'b1;
                    end
                    if (m_rvalid && m_rready) begin
                        if (r_half)
                            r_data_acc[511:256] <= m_rdata;
                        else
                            r_data_acc[255:0] <= m_rdata;
                        r_resp_acc <= worst_resp(r_resp_acc, m_rresp);
                        r_recv_subbeats <= r_recv_subbeats + 1'b1;
                        m_rready <= 1'b0;
                        if (r_half == 1'b0) begin
                            r_half <= 1'b1;
                            r_state <= 3'd3;
                        end else begin
                            s_rid <= r_id;
                            if (r_half)
                                s_rdata <= {m_rdata, r_data_acc[255:0]};
                            else
                                s_rdata <= r_data_acc;
                            s_rresp <= worst_resp(r_resp_acc, m_rresp);
                            s_rlast <= (r_beat == r_len);
                            s_rvalid <= 1'b1;
                            r_state <= 3'd4;
                        end
                    end
                end
                3'd4: begin
                    if (s_rvalid && s_rready) begin
                        if (r_beat == r_len) begin
                            r_state <= 3'd0;
                        end else begin
                            r_addr <= next_addr(r_addr, r_size, r_len, r_burst);
                            r_beat <= r_beat + 1'b1;
                            r_state <= 3'd2;
                        end
                    end
                end
            endcase

            case ({aw_push, aw_pop})
                2'b10: aw_count <= aw_count + 1;
                2'b01: aw_count <= aw_count - 1;
                default: aw_count <= aw_count;
            endcase

            case ({ar_push, ar_pop})
                2'b10: ar_count <= ar_count + 1;
                2'b01: ar_count <= ar_count - 1;
                default: ar_count <= ar_count;
            endcase
        end
    end
endmodule
