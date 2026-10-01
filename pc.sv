module pc (
    input logic clk,
    input logic rst_n,
    input logic pc_sel,
    input logic [31:0] target_pc,
    output logic [31:0] pc_out,
    output logic [31:0] pc_plus_4
);

    logic [31:0] pc_next;

    //increment PC by 4
    assign pc_plus_4 = pc_out + 32'd4;

    //MUX 0: sequential PC update, 1: jump to target
    assign pc_next = (pc_sel) ? target_pc : pc_plus_4;

    //Synchronous logic to update the PC register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_out <= 32'h0000_0000;
        end else begin
            pc_out <= pc_next;
        end
    end
endmodule