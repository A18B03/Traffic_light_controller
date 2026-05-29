`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:    20:19:21 05/28/26
// Design Name:    
// Module Name:    traffic_controller
// Project Name:   
// Target Device:  
// Tool versions:  
// Description:
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////
module traffic_controller (
  input clk,
  input reset_n,
  output reg red,
  output reg green,
  output reg yellow
);

// State encoding — 4 states
parameter RED_S         = 2'b00;
parameter YELLOW_TO_G   = 2'b01;
parameter GREEN_S       = 2'b10;
parameter YELLOW_TO_R   = 2'b11;

reg [1:0] current_state;
reg [1:0] count;

// Sequential block — state register + counter
always @(posedge clk or negedge reset_n) begin
  if (!reset_n) begin
    current_state <= RED_S;
    count         <= 2'b00;
  end
  else begin
    case (current_state)

      RED_S: begin
        if (count == 2'b10) begin  // 3 cycles done
          current_state <= YELLOW_TO_G;
          count         <= 2'b00;
        end
        else
          count <= count + 1;
      end

      YELLOW_TO_G: begin           // 1 cycle only
        current_state <= GREEN_S;
        count         <= 2'b00;
      end

      GREEN_S: begin
        if (count == 2'b10) begin  // 3 cycles done
          current_state <= YELLOW_TO_R;
          count         <= 2'b00;
        end
        else
          count <= count + 1;
      end

      YELLOW_TO_R: begin           // 1 cycle only
        current_state <= RED_S;
        count         <= 2'b00;
      end

      default: begin
        current_state <= RED_S;
        count         <= 2'b00;
      end

    endcase
  end
end

// Combinational output block — Moore FSM
always @(*) begin
  // Defaults — prevents latches
  red    = 1'b0;
  green  = 1'b0;
  yellow = 1'b0;

  case (current_state)
    RED_S:       red    = 1'b1;
    YELLOW_TO_G: yellow = 1'b1;
    GREEN_S:     green  = 1'b1;
    YELLOW_TO_R: yellow = 1'b1;
    default:     red    = 1'b1;
  endcase
end

endmodule

module tb_traffic;
  reg clk, reset_n;
  wire red, green, yellow;

  traffic_controller uut (
    .clk(clk), .reset_n(reset_n),
    .red(red), .green(green),
    .yellow(yellow)
  );

  always #5 clk = ~clk;

  initial begin
    clk = 0; reset_n = 0;
    #10 reset_n = 1;    // release reset
    #200 $finish;       // run long enough to see full cycle
  end

  initial $monitor("t=%0t | red=%b green=%b yellow=%b",
                    $time, red, green, yellow);
endmodule


module tb_traffic_self_check;

  reg clk, reset_n;
  wire red, green, yellow;

  integer pass_count = 0;
  integer fail_count = 0;

  // DUT
  traffic_controller uut (
    .clk(clk),
    .reset_n(reset_n),
    .red(red),
    .green(green),
    .yellow(yellow)
  );

  // Clock generation (10 ns period)
  always #5 clk = ~clk;

  // Checking task
  task check_output;
    input exp_red, exp_green, exp_yellow;
    input integer test_num;
    begin
      if ((red == exp_red) &&
          (green == exp_green) &&
          (yellow == exp_yellow))
      begin
        $display("Test %0d PASS | r=%b g=%b y=%b",
                 test_num, red, green, yellow);
        pass_count = pass_count + 1;
      end
      else
      begin
        $display("Test %0d FAIL | Expected r=%b g=%b y=%b | Got r=%b g=%b y=%b",
                 test_num,
                 exp_red, exp_green, exp_yellow,
                 red, green, yellow);
        fail_count = fail_count + 1;
      end
    end
  endtask

  initial begin

    // Initialize
    clk = 0;
    reset_n = 0;

    // Apply reset
    #10;
    reset_n = 1;

    // -------------------------
    // RED state (3 cycles)
    // -------------------------
    #15;  // sample during RED
    check_output(1,0,0,1);

    #10;  // still RED
    check_output(1,0,0,2);

    // -------------------------
    // YELLOW_TO_G
    // -------------------------
    #10;
    check_output(0,0,1,3);

    // -------------------------
    // GREEN state
    // -------------------------
    #10;
    check_output(0,1,0,4);

    #10;
    check_output(0,1,0,5);

    #10;
    check_output(0,1,0,6);

    // -------------------------
    // YELLOW_TO_R
    // -------------------------
    #10;
    check_output(0,0,1,7);

    // -------------------------
    // Back to RED
    // -------------------------
    #10;
    check_output(1,0,0,8);

    // Summary
    $display("--------------------------------");
    $display("TOTAL PASS = %0d", pass_count);
    $display("TOTAL FAIL = %0d", fail_count);

    if (fail_count == 0)
      $display("ALL TESTS PASSED");
    else
      $display("SOME TESTS FAILED");

    $display("--------------------------------");

    $finish;
  end

endmodule

