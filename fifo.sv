module fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH = 16
)(
   input logic clk,
   input logic rst_n,
   input logic wr_en,
   input logic [DATA_WIDTH - 1 : 0] wr_data,
   input logic rd_en,
   output logic [DATA_WIDTH - 1 : 0] rd_data,
   output logic rd_valid,
   output logic full,
   output logic empty,
   output logic [$clog2(DEPTH + 1) - 1 : 0] data_count,
   output logic overflow,
   output logic underflow
);

    
    localparam PTR_WIDTH = $clog2(DEPTH);
    localparam COUNT_WIDTH = $clog2(DEPTH + 1);

    logic [DATA_WIDTH - 1 : 0] mem [0 : DEPTH - 1];
    logic [PTR_WIDTH - 1 : 0] read_pointer;
    logic [PTR_WIDTH - 1 : 0] write_pointer;
    logic [COUNT_WIDTH - 1 : 0] next_data_count;
    logic rd_accept;
    logic wr_accept;

    assign rd_accept = rd_en && !empty;
    assign wr_accept = wr_en && (!full || rd_accept);
    assign next_data_count = data_count + wr_accept - rd_accept;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
           read_pointer <= '0;
           write_pointer <= '0;
           data_count <= '0;
           empty <= '1;
           full <= '0;
           rd_data <= '0;
           rd_valid <= '0;
           overflow <= '0;
           underflow <= '0;
        end
        else begin
            if (wr_accept) begin
                mem[write_pointer] <= wr_data;
                write_pointer <= (write_pointer == DEPTH - 1) ? '0 : (write_pointer + 1'b1);
            end

            if (rd_accept) begin
                rd_data <= mem[read_pointer];
                read_pointer <= (read_pointer == DEPTH - 1) ? '0 : (read_pointer + 1'b1);
            end

            data_count <= next_data_count;
            empty <= (next_data_count == 0);
            full <= (next_data_count == DEPTH);

            rd_valid <= rd_accept;
            overflow <= wr_en && !wr_accept;
            underflow <= rd_en && !rd_accept;
        end
        
    end

endmodule
