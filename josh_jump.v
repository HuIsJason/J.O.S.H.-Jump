//Sw[7:0] data_in

//KEY[0] synchronous reset when pressed
//KEY[1] go signal

//LEDR displays result
//HEX0 & HEX1 also displays result

module JOSH_Jump(SW, KEY, CLOCK_50, LEDR, HEX0, HEX1);
    input [9:0] SW;
    input [3:0] KEY;
    input CLOCK_50;
    output [9:0] LEDR;
    output [6:0] HEX0, HEX1;

    wire resetn;
    wire go;

    wire [7:0] data_result;
    assign go = ~KEY[1];
    assign resetn = KEY[0];

    part2 u0(
        .clk(CLOCK_50),
        .resetn(resetn),
        .go(go),
        .data_in(SW[7:0]),
        .data_result(data_result)
    );
      
    assign LEDR[7:0] = data_result;

    hex_decoder H0(
        .hex_digit(data_result[3:0]), 
        .segments(HEX0)
        );
        
    hex_decoder H1(
        .hex_digit(data_result[7:4]), 
        .segments(HEX1)
        );

endmodule

module part2(
    input clk,
    input resetn,
    input go,
    input [7:0] data_in,
    output [7:0] data_result
    );

    // lots of wires to connect our datapath and control
    wire ld_a, ld_b, ld_c, ld_x, ld_r;
    wire ld_alu_out;
    wire [1:0]  alu_select_a, alu_select_b;
    wire alu_op;

    control C0(
        .clk(clk),
        .resetn(resetn),
        
        .go(go),
        
        .ld_alu_out(ld_alu_out), 
        .ld_x(ld_x),
        .ld_a(ld_a),
        .ld_b(ld_b),
        .ld_c(ld_c), 
        .ld_r(ld_r), 
        
        .alu_select_a(alu_select_a),
        .alu_select_b(alu_select_b),
        .alu_op(alu_op)
    );

    datapath D0(
        .clk(clk),
        .resetn(resetn),

        .ld_alu_out(ld_alu_out), 
        .ld_x(ld_x),
        .ld_a(ld_a),
        .ld_b(ld_b),
        .ld_c(ld_c), 
        .ld_r(ld_r), 

        .alu_select_a(alu_select_a),
        .alu_select_b(alu_select_b),
        .alu_op(alu_op),

        .data_in(data_in),
        .data_result(data_result)
    );
                
 endmodule        
                

module control(
    input clk,
    input resetn,
    // user input
    input grav,
    // signals from datapath
    input endgame,
    
    // signals to datapath
    output reg startgame // 0 for menu, 1 for game
    );

    reg [5:0] current_state, next_state; 
    
    localparam  S_MENU        = 2'd0,
                S_MENU_WAIT   = 2'd1,
                S_GAME        = 2'd2;
    
    // state table
    always@(*)
    begin: state_table 
            case (current_state)
                S_MENU: next_state = go ? S_MENU_WAIT : S_MENU;
                S_MENU_WAIT: next_state = S_GAME_START;
                S_GAME: next_state = endgame ? S_MENU : S_GAME;
            default: next_state = S_MENU;
        endcase
    end
   

    // Output logic aka all datapath control signals
    always @(*)
    begin: enable_signals
        // By default make all our signals 0
            startgame = 1'b0;
        case (current_state)
            //S_MENU: begin
            //    startgame = 1'b0;
            //end
            S_GAME: begin
                startgame = 1'b1;
            end
            
        // default:  // don't need default since we already made sure all of our outputs were assigned a value at the start of the always block
        endcase
    end // enable_signals
   
    // current_state registers
    always@(posedge clk)
    begin: state_FFs
        if(!resetn)
            current_state <= S_MENU;
        else
            current_state <= next_state;
    end // state_FFS
endmodule

module datapath(
    input clk,
    input resetn,
    input startgame,
    input grav, // should be connected to a switch input
    output reg endgame
    );
    
    // registers
    reg [99:0] vwall [119:0]; 
    reg [119:0] hwall;
    // top left coordinates of dude
    reg [6:0] hdude = 7'd20; // from 0 to 20
    reg [7:0] vdude = 8'd100; // from 6 to 100
    
    reg [4:0] surr;
    wire inc = 1'b1;
    wire xdude = 4'd4; // if we change this we need to change the collision check to be a for loop
    wire ydude = 4'd6;

    always @(posedge clk) begin
        // 0. resetting
        if (!reset_n) begin
            endgame = 1'b1;
        end
        else begin
            // 1. collision check
            // a. vertical
            if (!grav)  // grav down
                surr = {vwall[hdude][vdude-1'b1], vwall[hdude+1'b1][vdude-1'b1], vwall[hdude+2'd2][vdude-1'b1], vwall[hdude+2'd3][vdude-1'b1]};
            else        // grav up
                surr = {vwall[hdude][vdude+ydude+1'b1], vwall[hdude+1'b1][vdude+ydude+1'b1], vwall[hdude+2'd2][vdude+ydude+1'b1], vwall[hdude+2'd3][vdude+ydude+1'b1]};
            
            // b. horizontal
            if (hwall[1'b1]) begin
                if (~|{vwall[hdude+xdude+1'b1][vdude], vwall[hdude+xdude+1'b1][vdude+1'b1], vwall[hdude+xdude+1'b1][vdude+]})
            end

        end

    end

endmodule

module update_screen(vwall, hwall, vdude, hdude, clk, o)
    input [99:0] vwall [119:0]; // maybe too much? 
    input [119:0] hwall;
    input [99:0] hdude; // group of 4 1s 
    input [119:0] vdude; // 4 pixels wide
    input clk;

    reg [6:0] h_counter, v_counter;

    h_counter = 7'b0010100;
    v_counter = 7'b0001010;

    // get x value
    always @(posedge clk)
        begin 
            if (h_counter < 7'b1111000)
                begin 
                    h_counter <= h_counter + 1;

                end
        end 



endmodule

module clock_divider(div, clock, clock_out, reset_n);
    input clock;
    output clock_out;
    wire q;
    wire qout;
    sync_counter sc(1'b1, clock, reset_n, 1'b0, )

endmodule

module sync_counter(enable, clock, reset_n, startb, endb, inc, q);
	input enable, clock, reset_n, inc;
	input [27:0] startb, endb;
	output reg [27:0] q;
	
	always @(posedge clock)
	begin
		if (reset_n == 1'b0)
			q <= startb;
		else if (enable == 1'b1)
			if (q == endb)
				q <= startb;
			else
				q <= q + inc;
	end
endmodule

module hex_decoder(hex_digit, segments);
    input [3:0] hex_digit;
    output reg [6:0] segments;
   
    always @(*)
        case (hex_digit)
            4'h0: segments = 7'b100_0000;
            4'h1: segments = 7'b111_1001;
            4'h2: segments = 7'b010_0100;
            4'h3: segments = 7'b011_0000;
            4'h4: segments = 7'b001_1001;
            4'h5: segments = 7'b001_0010;
            4'h6: segments = 7'b000_0010;
            4'h7: segments = 7'b111_1000;
            4'h8: segments = 7'b000_0000;
            4'h9: segments = 7'b001_1000;
            4'hA: segments = 7'b000_1000;
            4'hB: segments = 7'b000_0011;
            4'hC: segments = 7'b100_0110;
            4'hD: segments = 7'b010_0001;
            4'hE: segments = 7'b000_0110;
            4'hF: segments = 7'b000_1110;   
            default: segments = 7'h7f;
        endcase
endmodule