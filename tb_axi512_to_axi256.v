`timescale 1ns/1ps

module tb_axi512_to_axi256;
    reg clk;
    reg aresetn;

    reg  [3:0] s_awid;
    reg  [47:0] s_awaddr;
    reg  [7:0] s_awlen;
    reg  [2:0] s_awsize;
    reg  [1:0] s_awburst;
    reg  s_awvalid;
    wire s_awready;
    reg  [511:0] s_wdata;
    reg  [63:0] s_wstrb;
    reg  s_wlast;
    reg  s_wvalid;
    wire s_wready;
    wire [3:0] s_bid;
    wire [1:0] s_bresp;
    wire s_bvalid;
    reg  s_bready;

    reg  [3:0] s_arid;
    reg  [47:0] s_araddr;
    reg  [7:0] s_arlen;
    reg  [2:0] s_arsize;
    reg  [1:0] s_arburst;
    reg  s_arvalid;
    wire s_arready;
    wire [3:0] s_rid;
    wire [511:0] s_rdata;
    wire [1:0] s_rresp;
    wire s_rlast;
    wire s_rvalid;
    reg  s_rready;

    wire [3:0] m_awid;
    wire [47:0] m_awaddr;
    wire [7:0] m_awlen;
    wire [2:0] m_awsize;
    wire [1:0] m_awburst;
    wire m_awvalid;
    reg  m_awready;
    wire [255:0] m_wdata;
    wire [31:0] m_wstrb;
    wire m_wlast;
    wire m_wvalid;
    reg  m_wready;
    reg  [3:0] m_bid;
    reg  [1:0] m_bresp;
    reg  m_bvalid;
    wire m_bready;

    wire [3:0] m_arid;
    wire [47:0] m_araddr;
    wire [7:0] m_arlen;
    wire [2:0] m_arsize;
    wire [1:0] m_arburst;
    wire m_arvalid;
    reg  m_arready;
    reg  [3:0] m_rid;
    reg  [255:0] m_rdata;
    reg  [1:0] m_rresp;
    reg  m_rlast;
    reg  m_rvalid;
    wire m_rready;

    integer errors;
    integer write_count;
    integer read_count;
    integer aw_cmd_count;
    integer ar_cmd_count;
    reg [47:0] seen_awcmdaddr [0:63];
    reg [47:0] seen_waddr [0:63];
    reg [7:0] seen_awlen [0:63];
    reg [1:0] seen_awburst [0:63];
    reg [31:0] seen_wstrb [0:63];
    reg [255:0] seen_wdata [0:63];
    reg seen_wlast [0:63];
    reg [47:0] seen_arcmdaddr [0:63];
    reg [47:0] seen_raddr [0:63];
    reg [7:0] seen_arlen [0:63];
    reg [1:0] seen_arburst [0:63];
    reg write_burst_active;
    reg [3:0] write_burst_id;
    reg [47:0] write_burst_addr;
    reg [7:0] write_burst_len;
    reg [1:0] write_burst_type;
    reg [7:0] write_burst_beat;
    reg [1:0] write_burst_resp;
    reg read_burst_active;
    reg [3:0] read_burst_id;
    reg [47:0] read_burst_addr;
    reg [7:0] read_burst_len;
    reg [1:0] read_burst_type;
    reg [7:0] read_burst_beat;

    initial begin
        $dumpfile("tb_axi512_to_axi256.vcd");
        $dumpvars(0, tb_axi512_to_axi256);
    end

    axi512_to_axi256 dut (
        .aclk(clk), .aresetn(aresetn),
        .s_awid(s_awid), .s_awaddr(s_awaddr), .s_awlen(s_awlen), .s_awsize(s_awsize),
        .s_awburst(s_awburst), .s_awvalid(s_awvalid), .s_awready(s_awready),
        .s_wdata(s_wdata), .s_wstrb(s_wstrb), .s_wlast(s_wlast), .s_wvalid(s_wvalid),
        .s_wready(s_wready), .s_bid(s_bid), .s_bresp(s_bresp), .s_bvalid(s_bvalid),
        .s_bready(s_bready),
        .s_arid(s_arid), .s_araddr(s_araddr), .s_arlen(s_arlen), .s_arsize(s_arsize),
        .s_arburst(s_arburst), .s_arvalid(s_arvalid), .s_arready(s_arready),
        .s_rid(s_rid), .s_rdata(s_rdata), .s_rresp(s_rresp), .s_rlast(s_rlast),
        .s_rvalid(s_rvalid), .s_rready(s_rready),
        .m_awid(m_awid), .m_awaddr(m_awaddr), .m_awlen(m_awlen), .m_awsize(m_awsize),
        .m_awburst(m_awburst), .m_awvalid(m_awvalid), .m_awready(m_awready),
        .m_wdata(m_wdata), .m_wstrb(m_wstrb), .m_wlast(m_wlast), .m_wvalid(m_wvalid),
        .m_wready(m_wready), .m_bid(m_bid), .m_bresp(m_bresp), .m_bvalid(m_bvalid),
        .m_bready(m_bready),
        .m_arid(m_arid), .m_araddr(m_araddr), .m_arlen(m_arlen), .m_arsize(m_arsize),
        .m_arburst(m_arburst), .m_arvalid(m_arvalid), .m_arready(m_arready),
        .m_rid(m_rid), .m_rdata(m_rdata), .m_rresp(m_rresp), .m_rlast(m_rlast),
        .m_rvalid(m_rvalid), .m_rready(m_rready)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    function [255:0] data_for_addr;
        input [47:0] addr;
        integer b;
        begin
            data_for_addr = 0;
            for (b = 0; b < 32; b = b + 1)
                data_for_addr[b*8 +: 8] = addr[7:0] + b;
        end
    endfunction

    function [47:0] next_m_addr;
        input [47:0] addr;
        input [7:0] len;
        input [1:0] burst;
        reg [47:0] step;
        reg [47:0] span;
        reg [47:0] base;
        reg [47:0] offset;
        begin
            step = 48'd32;
            if (burst == 2'b00) begin
                next_m_addr = addr;
            end else if (burst == 2'b10) begin
                span = step * (len + 1);
                base = (addr / span) * span;
                offset = addr + step - base;
                if (offset >= span)
                    next_m_addr = base + (offset - span);
                else
                    next_m_addr = base + offset;
            end else begin
                next_m_addr = addr + step;
            end
        end
    endfunction

    task fail;
        input [1023:0] msg;
        begin
            $display("FAIL: %0s", msg);
            errors = errors + 1;
        end
    endtask

    task reset_dut;
        begin
            aresetn = 0;
            s_awvalid = 0; s_wvalid = 0; s_bready = 1;
            s_arvalid = 0; s_rready = 1;
            m_awready = 1; m_wready = 1; m_arready = 1;
            m_bvalid = 0; m_rvalid = 0; m_bresp = 0; m_rresp = 0;
            write_count = 0; read_count = 0; aw_cmd_count = 0; ar_cmd_count = 0;
            write_burst_active = 0; read_burst_active = 0;
            repeat (5) @(posedge clk);
            aresetn = 1;
            repeat (2) @(posedge clk);
        end
    endtask

    task axi_write_addr;
        input [3:0] id;
        input [47:0] addr;
        input [7:0] len;
        input [2:0] size;
        input [1:0] burst;
        begin
            @(posedge clk);
            s_awid <= id; s_awaddr <= addr; s_awlen <= len; s_awsize <= size;
            s_awburst <= burst; s_awvalid <= 1;
            while (!s_awready) @(posedge clk);
            @(posedge clk);
            s_awvalid <= 0;
        end
    endtask

    task axi_write_data;
        input [511:0] data;
        input [63:0] strb;
        input last;
        begin
            @(posedge clk);
            s_wdata <= data; s_wstrb <= strb; s_wlast <= last; s_wvalid <= 1;
            while (!s_wready) @(posedge clk);
            @(posedge clk);
            s_wvalid <= 0;
        end
    endtask

    task wait_b;
        input [3:0] id;
        input [1:0] resp;
        integer t;
        begin
            t = 0;
            while (!s_bvalid && t < 200) begin
                t = t + 1;
                @(posedge clk);
            end
            if (!s_bvalid) fail("timeout waiting for B");
            if (s_bid !== id) fail("BID mismatch");
            if (s_bresp !== resp) fail("BRESP mismatch");
            @(posedge clk);
        end
    endtask

    task axi_read_addr;
        input [3:0] id;
        input [47:0] addr;
        input [7:0] len;
        input [2:0] size;
        input [1:0] burst;
        begin
            @(posedge clk);
            s_arid <= id; s_araddr <= addr; s_arlen <= len; s_arsize <= size;
            s_arburst <= burst; s_arvalid <= 1;
            while (!s_arready) @(posedge clk);
            @(posedge clk);
            s_arvalid <= 0;
        end
    endtask

    task wait_r;
        input [3:0] id;
        input last;
        input [1:0] resp;
        integer t;
        begin
            t = 0;
            while (!s_rvalid && t < 400) begin
                t = t + 1;
                @(posedge clk);
            end
            if (!s_rvalid) fail("timeout waiting for R");
            if (s_rid !== id) begin
                $display("RID expected %h got %h at %0t", id, s_rid, $time);
                fail("RID mismatch");
            end
            if (s_rlast !== last) fail("RLAST mismatch");
            if (s_rresp !== resp) begin
                $display("RRESP expected %b got %b for id %h at %0t", resp, s_rresp, id, $time);
                fail("RRESP mismatch");
            end
            @(posedge clk);
        end
    endtask

    always @(posedge clk) begin
        if (!aresetn) begin
            m_bvalid <= 0;
            m_rvalid <= 0;
        end else begin
            if (m_awvalid && m_awready) begin
                seen_awcmdaddr[aw_cmd_count] <= m_awaddr;
                seen_awlen[aw_cmd_count] <= m_awlen;
                seen_awburst[aw_cmd_count] <= m_awburst;
                aw_cmd_count <= aw_cmd_count + 1;
                write_burst_active <= 1;
                write_burst_id <= m_awid;
                write_burst_addr <= m_awaddr;
                write_burst_len <= m_awlen;
                write_burst_type <= m_awburst;
                write_burst_beat <= 0;
                write_burst_resp <= 2'b00;
            end

            if (m_wvalid && m_wready) begin
                seen_waddr[write_count] <= write_burst_addr;
                seen_wstrb[write_count] <= m_wstrb;
                seen_wdata[write_count] <= m_wdata;
                seen_wlast[write_count] <= m_wlast;
                write_count <= write_count + 1;
                if (write_burst_addr[11:0] == 12'hEE0)
                    write_burst_resp <= 2'b10;
                if (m_wlast) begin
                    m_bid <= write_burst_id;
                    m_bresp <= (write_burst_addr[11:0] == 12'hEE0) ? 2'b10 : write_burst_resp;
                    m_bvalid <= 1;
                    write_burst_active <= 0;
                end else begin
                    write_burst_addr <= next_m_addr(write_burst_addr, write_burst_len, write_burst_type);
                    write_burst_beat <= write_burst_beat + 1'b1;
                end
            end
            if (m_bvalid && m_bready) begin
                m_bvalid <= 0;
            end

            if (m_arvalid && m_arready) begin
                seen_arcmdaddr[ar_cmd_count] <= m_araddr;
                seen_arlen[ar_cmd_count] <= m_arlen;
                seen_arburst[ar_cmd_count] <= m_arburst;
                ar_cmd_count <= ar_cmd_count + 1;
                read_burst_active <= 1;
                read_burst_id <= m_arid;
                read_burst_addr <= m_araddr;
                read_burst_len <= m_arlen;
                read_burst_type <= m_arburst;
                read_burst_beat <= 0;
            end

            if ((!m_rvalid || (m_rvalid && m_rready)) && read_burst_active) begin
                seen_raddr[read_count] <= read_burst_addr;
                read_count <= read_count + 1;
                m_rid <= read_burst_id;
                m_rdata <= data_for_addr(read_burst_addr);
                m_rresp <= (read_burst_addr[11:0] == 12'hEE0) ? 2'b10 : 2'b00;
                m_rlast <= (read_burst_beat == read_burst_len);
                m_rvalid <= 1;
                if (read_burst_beat == read_burst_len) begin
                    read_burst_active <= 0;
                end else begin
                    read_burst_addr <= next_m_addr(read_burst_addr, read_burst_len, read_burst_type);
                    read_burst_beat <= read_burst_beat + 1'b1;
                end
            end else if (m_rvalid && m_rready) begin
                m_rvalid <= 0;
            end
        end
    end

    initial begin
        errors = 0;
        reset_dut();

        axi_write_addr(4'h1, 48'h0000_0000_1000, 8'd0, 3'd6, 2'b01);
        axi_write_data({256'hBBBB, 256'hAAAA}, 64'hFFFF_FFFF_FFFF_FFFF, 1'b1);
        wait_b(4'h1, 2'b00);
        if (write_count != 2) fail("full write did not split into two writes");
        if (aw_cmd_count != 1 || seen_awcmdaddr[0] != 48'h1000 || seen_awlen[0] != 8'd1 || seen_awburst[0] != 2'b01)
            fail("full write did not use one two-beat output burst");
        if (seen_waddr[0] != 48'h1000 || seen_waddr[1] != 48'h1020) fail("full write addresses wrong");
        if (seen_wstrb[0] != 32'hFFFF_FFFF || seen_wstrb[1] != 32'hFFFF_FFFF) fail("full write strobes wrong");
        if (seen_wlast[0] !== 1'b0 || seen_wlast[1] !== 1'b1) fail("full write WLAST wrong");

        axi_write_addr(4'h2, 48'h0000_0000_1018, 8'd0, 3'd5, 2'b01);
        axi_write_data({256'hCCCC, 256'hDDDD}, 64'h00FF_FFFF_FF00_0000, 1'b1);
        wait_b(4'h2, 2'b00);
        if (write_count != 4) fail("unaligned crossing write did not create two writes");
        if (aw_cmd_count != 2 || seen_awcmdaddr[1] != 48'h1000 || seen_awlen[1] != 8'd1 || seen_awburst[1] != 2'b01)
            fail("unaligned crossing write did not use one two-beat output burst");
        if (seen_waddr[2] != 48'h1000 || seen_waddr[3] != 48'h1020) fail("unaligned write addresses wrong");
        if (seen_wstrb[2] != 32'hFF00_0000 || seen_wstrb[3] != 32'h00FF_FFFF)
            fail("unaligned crossing write strobes wrong");

        axi_write_addr(4'h3, 48'h0000_0000_2000, 8'd1, 3'd6, 2'b01);
        axi_write_data({256'h2, 256'h1}, 64'hFFFF_FFFF_FFFF_FFFF, 1'b0);
        axi_write_data({256'h4, 256'h3}, 64'hFFFF_FFFF_FFFF_FFFF, 1'b1);
        wait_b(4'h3, 2'b00);
        if (write_count != 8) fail("two-beat burst write count wrong");
        if (seen_awcmdaddr[2] != 48'h2000 || seen_awlen[2] != 8'd3 || seen_awburst[2] != 2'b01)
            fail("two-beat full write did not use one four-beat output burst");

        axi_write_addr(4'h4, 48'h0000_0000_3008, 8'd1, 3'd3, 2'b00);
        axi_write_data(512'h55, 64'h0000_0000_0000_FF00, 1'b0);
        axi_write_data(512'h66, 64'h0000_0000_0000_FF00, 1'b1);
        wait_b(4'h4, 2'b00);
        if (seen_awburst[3] != 2'b00) fail("fixed write did not preserve burst type");
        if (seen_waddr[8] != 48'h3000 || seen_waddr[9] != 48'h3000) fail("fixed burst address wrong");

        axi_write_addr(4'hC, 48'h0000_0000_4040, 8'd1, 3'd6, 2'b10);
        axi_write_data({256'h12, 256'h11}, 64'hFFFF_FFFF_FFFF_FFFF, 1'b0);
        axi_write_data({256'h14, 256'h13}, 64'hFFFF_FFFF_FFFF_FFFF, 1'b1);
        wait_b(4'hC, 2'b00);
        if (seen_awburst[4] != 2'b10) fail("wrap write did not preserve burst type");
        if (seen_waddr[10] != 48'h4040 || seen_waddr[11] != 48'h4060 ||
            seen_waddr[12] != 48'h4000 || seen_waddr[13] != 48'h4020)
            fail("wrap burst address progression wrong");

        axi_write_addr(4'h5, 48'h0000_0000_0EE0, 8'd0, 3'd5, 2'b01);
        axi_write_data(512'h77, 64'hFFFF_FFFF_0000_0000, 1'b1);
        wait_b(4'h5, 2'b10);

        axi_write_addr(4'hD, 48'h0000_0000_9018, 8'd1, 3'd6, 2'b01);
        axi_write_data({256'h22, 256'h21}, 64'hFFFF_FFFF_FF00_0000, 1'b0);
        axi_write_data({256'h24, 256'h23}, 64'hFFFF_FFFF_FFFF_FFFF, 1'b1);
        wait_b(4'hD, 2'b00);
        if (aw_cmd_count != 8) fail("unaligned multi-beat write did not split into two output transactions");
        if (seen_awcmdaddr[6] != 48'h9000 || seen_awlen[6] != 8'd1 || seen_awburst[6] != 2'b01 ||
            seen_awcmdaddr[7] != 48'h9040 || seen_awlen[7] != 8'd1 || seen_awburst[7] != 2'b01)
            fail("unaligned multi-beat output AW split wrong");
        if (write_count != 19) fail("unaligned multi-beat write count wrong");
        if (seen_waddr[15] != 48'h9000 || seen_wstrb[15] != 32'hFF00_0000 ||
            seen_waddr[16] != 48'h9020 || seen_wstrb[16] != 32'hFFFF_FFFF ||
            seen_waddr[17] != 48'h9040 || seen_wstrb[17] != 32'hFFFF_FFFF ||
            seen_waddr[18] != 48'h9060 || seen_wstrb[18] != 32'hFFFF_FFFF)
            fail("unaligned multi-beat write strobe/address sequence wrong");
        if (seen_wlast[15] !== 1'b0 || seen_wlast[16] !== 1'b1 ||
            seen_wlast[17] !== 1'b0 || seen_wlast[18] !== 1'b1)
            fail("unaligned multi-beat split WLAST wrong");

        axi_read_addr(4'h6, 48'h0000_0000_4000, 8'd0, 3'd6, 2'b01);
        wait_r(4'h6, 1'b1, 2'b00);
        if (read_count != 2) fail("full read did not split into two reads");
        if (ar_cmd_count != 1 || seen_arcmdaddr[0] != 48'h4000 || seen_arlen[0] != 8'd1 || seen_arburst[0] != 2'b01)
            fail("full read did not use one two-beat output burst");
        if (s_rdata[255:0] !== data_for_addr(48'h4000)) fail("read lower data wrong");
        if (s_rdata[511:256] !== data_for_addr(48'h4020)) fail("read upper data wrong");

        axi_read_addr(4'h7, 48'h0000_0000_5018, 8'd0, 3'd5, 2'b01);
        wait_r(4'h7, 1'b1, 2'b00);
        if (read_count != 4) fail("crossing read did not create two reads");
        if (seen_arcmdaddr[1] != 48'h5000 || seen_arlen[1] != 8'd1 || seen_arburst[1] != 2'b01)
            fail("crossing read did not use one two-beat output burst");

        axi_read_addr(4'hE, 48'h0000_0000_A018, 8'd1, 3'd6, 2'b01);
        wait_r(4'hE, 1'b0, 2'b00);
        wait_r(4'hE, 1'b1, 2'b00);
        if (seen_arcmdaddr[2] != 48'hA000 || seen_arlen[2] != 8'd3 || seen_arburst[2] != 2'b01)
            fail("unaligned multi-beat read did not use one four-beat output burst");
        if (seen_raddr[4] != 48'hA000 || seen_raddr[5] != 48'hA020 ||
            seen_raddr[6] != 48'hA040 || seen_raddr[7] != 48'hA060)
            fail("unaligned multi-beat read address sequence wrong");

        axi_read_addr(4'h8, 48'h0000_0000_6000, 8'd0, 3'd3, 2'b01);
        wait_r(4'h8, 1'b1, 2'b00);
        if (read_count != 9) fail("narrow read count wrong");

        axi_read_addr(4'h9, 48'h0000_0000_0EE0, 8'd0, 3'd5, 2'b01);
        wait_r(4'h9, 1'b1, 2'b10);

        s_rready <= 0;
        axi_read_addr(4'hA, 48'h0000_0000_7000, 8'd0, 3'd6, 2'b01);
        axi_read_addr(4'hB, 48'h0000_0000_8000, 8'd0, 3'd6, 2'b01);
        repeat (5) @(posedge clk);
        s_rready <= 1;
        wait_r(4'hA, 1'b1, 2'b00);
        wait_r(4'hB, 1'b1, 2'b00);

        reset_dut();

        if (errors == 0) begin
            $display("PASS: axi512_to_axi256 self-test completed");
            $finish;
        end else begin
            $display("FAIL: %0d errors", errors);
            $finish(1);
        end
    end
endmodule
