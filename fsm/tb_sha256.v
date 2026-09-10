`timescale 1ns / 1ps
`default_nettype none

module tb_sha256_file;

    // Tín hiệu giao tiếp với module Top
    reg          clk;
    reg          reset_n;
    reg  [7:0]   datain;
    reg          datavalid;
    reg          lastbyte;
    wire         readydata;
    wire         hash_done;
    wire [255:0] digest;

    // Các biến quản lý file
    integer      fd_in;
    integer      fd_out;
    integer      status_str;
    integer      status_hash;
    integer      i;
    integer      len;
    integer      test_count;
    integer      pass_count;

    // Bộ đệm đọc file (hỗ trợ chuỗi dài tối đa 255 ký tự)
    reg [8*255:0] input_str;
    reg [255:0]   expected_hash;

    // Khởi tạo Module Top
    sha256_top uut (
        .clk(clk),
        .reset_n(reset_n),
        .datain(datain),
        .datavalid(datavalid),
        .lastbyte(lastbyte),
        .readydata(readydata),
        .hash_done(hash_done),
        .digest(digest)
    );

    // Tạo xung clock chu kỳ 10ns
    always #5 clk = ~clk;

    // Hàm tính toán độ dài thực tế của chuỗi đọc được
    // Trong Verilog, $fscanf("%s") sẽ dồn ký tự về bên phải và chèn 0x00 vào bên trái
    function integer get_str_len(input [8*255:0] s);
        integer k;
        begin
            get_str_len = 0;
            for (k = 0; k < 256; k = k + 1) begin
                if (s[k*8 +: 8] != 8'h00) begin
                    get_str_len = k + 1;
                end
            end
        end
    endfunction

    initial begin
        // Khởi tạo hệ thống
        clk = 0;
        reset_n = 0;
        datain = 8'h00;
        datavalid = 0;
        lastbyte = 0;
        test_count = 0;
        pass_count = 0;

        // Mở file input (r: read) và file output (w: write)
        fd_in = $fopen("input.txt", "r");
        if (fd_in == 0) begin
            $display("LOI NGHiem TRONG: Khong the mo file 'input.txt'!");
            $finish;
        end
        fd_out = $fopen("output_log.txt", "w");

        // Kích hoạt Reset
        #20;
        reset_n = 1;
        #10;

        $display("=========================================================");
        $display(" BAT DAU CHAY AUTO-TEST SHA-256 TU FILE input.txt");
        $display("=========================================================");
        $fdisplay(fd_out, "=========================================================");
        $fdisplay(fd_out, " REPORT TEST SHA-256");
        $fdisplay(fd_out, "=========================================================\n");

        // Vòng lặp đọc đến cuối file
        while (!$feof(fd_in)) begin
            // 1. Đọc dòng chuỗi đầu vào (bỏ qua khoảng trắng/xuống dòng)
            status_str = $fscanf(fd_in, "%s\n", input_str);
            
            if (status_str == 1) begin
                // 2. Đọc dòng Hash dự kiến (dạng Hex)
                status_hash = $fscanf(fd_in, "%h\n", expected_hash);
                
                if (status_hash == 1) begin
                    test_count = test_count + 1;
                    len = get_str_len(input_str);

                    $display("Dang test [%0d]: Chuoi %0d ky tu...", test_count, len);

                    // 3. Đánh thức FSM
                    @(posedge clk);
                    datavalid = 1;
                    wait(readydata == 1);

                    // 4. Bơm từng byte vào Core (đẩy từ trái sang phải)
                    for (i = len - 1; i >= 0; i = i - 1) begin
                        datain = input_str[i*8 +: 8];
                        
                        if (i == 0) lastbyte = 1;
                        else        lastbyte = 0;
                        
                        @(posedge clk);
                    end

                    // 5. Ngừng gửi dữ liệu
                    datavalid = 0;
                    lastbyte = 0;
                    datain = 8'h00;

                    // 6. Đợi mạch xử lý xong
                    wait(hash_done == 1);
                    @(posedge clk);

                    // 7. Kiểm tra kết quả
                    if (digest === expected_hash) begin
                        pass_count = pass_count + 1;
                        $display(" => [PASS] Khop Hash!");
                        $fdisplay(fd_out, "Test %0d: [PASS]", test_count);
                    end else begin
                        $display(" => [FAIL] Khong khop Hash!");
                        $fdisplay(fd_out, "Test %0d: [FAIL]", test_count);
                    end

                    // Ghi log chi tiết vào file
                    $fdisplay(fd_out, "  - Input text : %s", input_str);
                    $fdisplay(fd_out, "  - Expected   : %h", expected_hash);
                    $fdisplay(fd_out, "  - Core Digest: %h\n", digest);
                end
            end
        end

        // 8. Tổng kết
        $display("=========================================================");
        $display(" TONG KET: PASS %0d/%0d TESTCASES", pass_count, test_count);
        $display(" Kiem tra file 'output_log.txt' de xem chi tiet.");
        $display("=========================================================");
        
        $fdisplay(fd_out, "=========================================================");
        $fdisplay(fd_out, " TONG KET: PASS %0d/%0d TESTCASES", pass_count, test_count);
        $fdisplay(fd_out, "=========================================================");

        // Đóng file
        $fclose(fd_in);
        $fclose(fd_out);
        #50;
        $finish;
    end

    // Hỗ trợ xuất file waveform
    initial begin
        $dumpfile("sha256_waveform.vcd");
        $dumpvars(0, tb_sha256_file);
    end

endmodule
