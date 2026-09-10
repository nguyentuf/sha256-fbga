module sha256_top (
    input  wire          clk,
    input  wire          reset_n,

    // Giao tiếp với thiết bị bên ngoài (Host)
    input  wire [7:0]    datain,       // Byte dữ liệu đầu vào
    input  wire          datavalid,    // Tín hiệu báo byte dữ liệu hợp lệ
    input  wire          lastbyte,     // Tín hiệu báo đây là byte cuối cùng của thông điệp
    output wire          readydata,    // Báo hiệu hệ thống sẵn sàng nhận byte tiếp theo

    // Ngõ ra kết quả
    output wire          hash_done,    // Báo hiệu đã băm xong toàn bộ thông điệp
    output wire [255:0]  digest        // Kết quả băm SHA-256
);

    // --- Các dây kết nối nội bộ giữa Padding và Core ---
    wire [511:0] internal_block;
    wire         internal_start;
    wire         internal_last_block;
    wire         internal_digest_update;
    wire         internal_core_done;

    // Trạng thái hoàn thành chung
    wire         pad_done;
    assign hash_done = pad_done & internal_core_done;

    // --- Instance mạch Padding ---
    sha256_padding u_padding (
        .clk        (clk),
        .reset_n    (reset_n),
        
        .datain     (datain),
        .datavalid  (datavalid),
        .lastbyte   (lastbyte),
        .readydata  (readydata),
        
        .block      (internal_block),
        .core_start (internal_start),
        .last_block (internal_last_block),
        .core_ready (internal_digest_update), // Nhận tín hiệu digest_update từ Core
        .pad_done   (pad_done)
    );

    // --- Instance mạch Core ---
    sha256_core u_core (
        .clk            (clk),
        .reset_n        (reset_n),
        
        .start          (internal_start),
        .last_block     (internal_last_block),
        .block          (internal_block),
        
        .done           (internal_core_done),
        .digest_update  (internal_digest_update), // Báo cho padding biết đã nạp xong block
        .digest         (digest)
    );

endmodule
