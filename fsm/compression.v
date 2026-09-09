module compression(
    input  wire         clk,
    input  wire         reset_n,
    input  wire         init,
    input  wire         ready,
    input  wire         digest_update,
    input  wire         done, 
    input  wire [31:0]  W_i,
    input  wire [31:0]  K_i,
    output wire [255:0] digest
);
    reg [31:0] H0, H1, H2, H3, H4, H5, H6, H7;
    reg [31:0] a, b, c, d, e, f, g, h;

    wire [31:0] Ch = (e & f) ^ (~e & g);
    wire [31:0] Maj = (a & b) ^ (a & c) ^ (b & c);
    
    wire [31:0] sum0 = {a[1:0], a[31:2]} ^ {a[12:0], a[31:13]} ^ {a[21:0], a[31:22]};
    wire [31:0] sum1 = {e[5:0], e[31:6]} ^ {e[10:0], e[31:11]} ^ {e[24:0], e[31:25]};

    wire [31:0] T1 = h + sum1 + Ch + K_i + W_i;
    wire [31:0] T2 = sum0 + Maj;

    assign digest = {H0, H1, H2, H3, H4, H5, H6, H7};

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            H0 <= 32'h6a09e667; H1 <= 32'hbb67ae85; H2 <= 32'h3c6ef372; H3 <= 32'ha54ff53a;
            H4 <= 32'h510e527f; H5 <= 32'h9b05688c; H6 <= 32'h1f83d9ab; H7 <= 32'h5be0cd19;
            a <= 0; b <= 0; c <= 0; d <= 0; e <= 0; f <= 0; g <= 0; h <= 0;
        end else begin
            if (init) begin
                a <= H0; b <= H1; c <= H2; d <= H3;
                e <= H4; f <= H5; g <= H6; h <= H7;
            end else if (ready) begin
                h <= g;
                g <= f;
                f <= e;
                e <= d + T1;
                d <= c;
                c <= b;
                b <= a;
                a <= T1 + T2;
            end else if (digest_update) begin
                H0 <= H0 + a;
                H1 <= H1 + b;
                H2 <= H2 + c;
                H3 <= H3 + d;
                H4 <= H4 + e;
                H5 <= H5 + f;
                H6 <= H6 + g;
                H7 <= H7 + h;
            end
        end
    end
endmodule
