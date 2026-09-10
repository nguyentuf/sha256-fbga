module sha256_padding (
    input  wire          clk,
    input  wire          reset_n,

    // Giao tiếp Host
    input  wire [7:0]    datain,
    input  wire          datavalid,
    input  wire          lastbyte,
    output reg           readydata,

    // Giao tiếp Core
    output reg [511:0]   block,
    output reg           core_start,
    output reg           last_block,
    input  wire          core_ready,

    // Tín hiệu hoàn tất
    output reg           pad_done
);

    localparam [2:0] IDLE      = 3'd0,
                     RCV_DATA  = 3'd1,
                     PAD_80    = 3'd2,
                     PAD_00    = 3'd3,
                     PAD_LEN   = 3'd4,
                     LOAD_CORE = 3'd5,
                     WAIT_CORE = 3'd6,
                     FINISH    = 3'd7;

    reg [2:0] current_state, next_state;
    reg [2:0] ret_state_reg, ret_state_next;
    
    reg [5:0]  bytecnt_reg, bytecnt_next;
    reg [63:0] totalbit_reg, totalbit_next;
    reg [511:0] block_next;

    reg       write_en;
    reg [7:0] data_to_write;
    integer i;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            current_state <= IDLE;
            ret_state_reg <= IDLE;
            bytecnt_reg   <= 6'd0;
            totalbit_reg  <= 64'd0;
            block         <= 512'd0;
        end else begin
            current_state <= next_state;
            ret_state_reg <= ret_state_next;
            bytecnt_reg   <= bytecnt_next;
            totalbit_reg  <= totalbit_next;
            block         <= block_next;
        end
    end

    always @(*) begin
        next_state     = current_state;
        ret_state_next = ret_state_reg;
        bytecnt_next   = bytecnt_reg;
        totalbit_next  = totalbit_reg;
        block_next     = block;

        readydata  = 1'b0;
        pad_done   = 1'b0;
        core_start = 1'b0;
        last_block = 1'b0;
        write_en   = 1'b0;
        data_to_write = 8'h00;

        case (current_state)
            IDLE: begin
                readydata     = 1'b0;
                bytecnt_next  = 6'd0;
                totalbit_next = 64'd0;
                if (datavalid) next_state = RCV_DATA;
            end

            RCV_DATA: begin
                readydata = 1'b1;
                if (datavalid) begin
                    write_en      = 1'b1;
                    data_to_write = datain;
                    totalbit_next = totalbit_reg + 8;

                    if (bytecnt_reg == 63) begin
                        if (lastbyte) begin
                            next_state     = LOAD_CORE;
                            ret_state_next = PAD_80;
                        end else begin
                            next_state     = LOAD_CORE;
                            ret_state_next = RCV_DATA;
                        end
                        bytecnt_next = 6'd0;
                    end else begin
                        if (lastbyte) next_state = PAD_80;
                        bytecnt_next = bytecnt_reg + 1'b1;
                    end
                end
            end

            PAD_80: begin
                write_en      = 1'b1;
                data_to_write = 8'h80;
                if (bytecnt_reg == 63) begin
                    next_state     = LOAD_CORE;
                    ret_state_next = PAD_00;
                    bytecnt_next   = 6'd0;
                end else begin
                    next_state   = PAD_00;
                    bytecnt_next = bytecnt_reg + 1'b1;
                end
            end

            PAD_00: begin
                write_en      = 1'b1;
                data_to_write = 8'h00;
                if (bytecnt_reg == 63) begin
                    next_state     = LOAD_CORE;
                    ret_state_next = PAD_00;
                    bytecnt_next   = 6'd0;
                end else if (bytecnt_reg == 55) begin
                    next_state   = PAD_LEN;
                    bytecnt_next = bytecnt_reg + 1'b1;
                end else begin
                    bytecnt_next = bytecnt_reg + 1'b1;
                end
            end

            PAD_LEN: begin
                write_en = 1'b1;
                case (bytecnt_reg)
                    6'd56: data_to_write = totalbit_reg[63:56];
                    6'd57: data_to_write = totalbit_reg[55:48];
                    6'd58: data_to_write = totalbit_reg[47:40];
                    6'd59: data_to_write = totalbit_reg[39:32];
                    6'd60: data_to_write = totalbit_reg[31:24];
                    6'd61: data_to_write = totalbit_reg[23:16];
                    6'd62: data_to_write = totalbit_reg[15:8];
                    6'd63: data_to_write = totalbit_reg[7:0];
                    default: data_to_write = 8'h00;
                endcase

                if (bytecnt_reg == 63) begin
                    next_state     = LOAD_CORE;
                    ret_state_next = FINISH;
                    bytecnt_next   = 6'd0;
                end else begin
                    bytecnt_next = bytecnt_reg + 1'b1;
                end
            end

            LOAD_CORE: begin
                core_start = 1'b1;
                next_state = WAIT_CORE;
            end

            WAIT_CORE: begin
                if (ret_state_reg == FINISH) last_block = 1'b1; 
                if (core_ready) next_state = ret_state_reg;
            end

            FINISH: begin
                pad_done   = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase

        if (write_en) begin
            for (i = 0; i < 64; i = i + 1) begin
                if (i[5:0] == bytecnt_reg) begin
                    block_next[ (63 - i)*8 +: 8 ] = data_to_write;
                end
            end
        end
    end
endmodule
