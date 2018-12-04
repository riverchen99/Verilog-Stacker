module ScoreDisplay(rst, clk, pA_score, pB_score, highscore, highscore_disp, seg, an);
  input clk, rst, highscore_disp;
  input [3:0] pA_score, pB_score, highscore;
  output reg [6:0] seg;
  output reg [3:0] an;
 
  function [6:0] numToSegments;
        input [3:0] in;
        begin
            case(in)
                4'b0000: numToSegments = 7'b1000000; // "0"            
                4'b0001: numToSegments = 7'b1111001; // "1"
                4'b0010: numToSegments = 7'b0100100; // "2"                                              
                4'b0011: numToSegments = 7'b0110000; // "3"                                              
                4'b0100: numToSegments = 7'b0011001; // "4"                                              
                4'b0101: numToSegments = 7'b0010010; // "5"                                              
                4'b0110: numToSegments = 7'b0000010; // "6"                                              
                4'b0111: numToSegments = 7'b1111000; // "7"                                              
                4'b1000: numToSegments = 7'b0000000; // "8"                                      
                4'b1001: numToSegments = 7'b0010000; // "9"                        
                default: numToSegments = 7'b1111111; // all off
            endcase
        end
    endfunction
 
  reg [1:0] count = 0;
 
  always @ (posedge clk) begin
    if (rst) begin
      seg <= 0;
      an <= 0;
      count <= 0;
    end
    else begin
      case(count)
        0: begin
          if (highscore_disp) begin
            seg <= numToSegments(highscore%10);
          end else begin
            seg <= numToSegments(pB_score%10);
          end
          an <= 4'b1110;
        end
        1: begin
          if (highscore_disp) begin
            seg <= numToSegments(highscore/10);
          end else begin
            seg <= numToSegments(pB_score/10);
          end        
          an <= 4'b1101;
        end
        2: begin
          if (highscore_disp) begin
            seg <= 7'b0010010; //"S"
          end else begin
            seg <= numToSegments(pA_score%10);
          end
          an <= 4'b1011;
        end
        3: begin
          if (highscore_disp) begin
            seg <= 7'b0001001; //"H"
          end else begin
            seg <= numToSegments(pA_score/10);
          end
          an <= 4'b0111;
        end
      endcase
      count <= count + 1;
    end
  end
endmodule