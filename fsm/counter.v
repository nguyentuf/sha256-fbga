module counter(
    input  wire        clk,
    input  wire        reset_n,
    input  wire        ready,
    output wire [5:0]  round_idx
);
    reg [5:0] round_idx_reg;
    reg [5:0] round_idx_next;

    assign round_idx = round_idx_reg;

    always @* begin
        if(ready) round_idx_next = round_idx_reg + 1'b1;
        else      round_idx_next = 6'd0;
    end

    always @(posedge clk or negedge reset_n) begin
        if(!reset_n) round_idx_reg <= 6'd0;
        else         round_idx_reg <= round_idx_next;
    end
endmodule
