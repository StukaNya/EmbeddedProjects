//------------------------------------------------------------------------------ 
// Copyright (c) 2004 Xilinx, Inc. 
// All Rights Reserved 
//------------------------------------------------------------------------------ 
//   ____  ____ 
//  /   /\/   / 
// /___/  \  /   Vendor: Xilinx 
// \   \   \/    Author: John F. Snow, Advanced Product Division, Xilinx, Inc.
//  \   \        Filename: $RCSfile: colorbars.v,rcs $
//  /   /        Date Last Modified:  $Date: 2004-08-27 12:43:08-06 $
// /___/   /\    Date Created: May 27, 2004 
// \   \  /  \ 
//  \___\/\___\ 
// 
//
// Revision History: 
// $Log: colorbars.v,rcs $
// Revision 1.1  2004-08-27 12:43:08-06  jsnow
// New header.
//
//------------------------------------------------------------------------------ 
//
//     XILINX IS PROVIDING THIS DESIGN, CODE, OR INFORMATION "AS IS"
//     SOLELY FOR USE IN DEVELOPING PROGRAMS AND SOLUTIONS FOR
//     XILINX DEVICES.  BY PROVIDING THIS DESIGN, CODE, OR INFORMATION
//     AS ONE POSSIBLE IMPLEMENTATION OF THIS FEATURE, APPLICATION
//     OR STANDARD, XILINX IS MAKING NO REPRESENTATION THAT THIS
//     IMPLEMENTATION IS FREE FROM ANY CLAIMS OF INFRINGEMENT,
//     AND YOU ARE RESPONSIBLE FOR OBTAINING ANY RIGHTS YOU MAY REQUIRE
//     FOR YOUR IMPLEMENTATION.  XILINX EXPRESSLY DISCLAIMS ANY
//     WARRANTY WHATSOEVER WITH RESPECT TO THE ADEQUACY OF THE
//     IMPLEMENTATION, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OR
//     REPRESENTATIONS THAT THIS IMPLEMENTATION IS FREE FROM CLAIMS OF
//     INFRINGEMENT, IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
//     FOR A PARTICULAR PURPOSE.
//
//------------------------------------------------------------------------------ 
/*
This colorbar generator will generate color bars for the SMPTE 125M video
standard which specifies 525 line 4:2:2 component digital video. All video is
generated at 10-bit resolution.

The color bars comply with SMPTE EG-1 standard color bars with the exception of
the bottom band which simply contains one white bar and one black bar. The
upper two bands are EG-1 compliant containing 7 color bars each. The top band
contains the following bars, in order from left to right across the screen:
white, yellow, cyan, green, magenta, red, and blue. The middle band contains
the following bars from left to right: blue, black, magenta, black, cyan,
black, white.

This module generates all the correct TRS characters to mark the start of
active video (SAV) and the end of active video (EAV). Each TRS character is
four words long. The format of the TRS is shown below:
    
    word 1:     0x3ff
    word 2:     0x000
    word 3:     0x000
    word 4:     XYZ (see below)

The XYZ word specifies the field, horizontal blanking, and vertical blanking
and contains some error detection bits. The legal values for the XYZ word are
listed below:

    F V H   XYZ (hex)
    0 0 0   0x200
    0 0 1   0x274
    0 1 0   0x29c
    0 1 1   0x2d8
    1 0 0   0x31c
    1 0 1   0x368
    1 1 0   0x3b0
    1 1 1   0x3c4

F is 1 for even fields and 0 for odd fields. V is 1 during the vertical
blanking period, 0 otherwise. H is 1 during the horizontal blanking period, 0
otherwise.

The module is driven by two counters, the line_counter that counts vertical
lines from 1 to 525 and the pixel_counter that counts horizontal pixels from 0
to 1715.

For convenience in debugging video applications, the module also outputs the
H, V, and F bits.

This generator basically consits of two ROM based state machines, one for the
vertical direction and one for the horizontal direction. Changing the ROM
contents and the associated video timing parameters will affect the test
pattern that is generated.

The vertical state machine is responsible for controlling the generation of the
V and F bits and for determining when the transitions occur between the various
color bar bands on the screen.

The vertical state machine is driven by the v_evnt_cntr counter and a ROM
called v_evnt_rom. The v_evnt_cntr generates the address into the ROM. There is
also a line counter called v_counter which contains the current line number. The
output of the v_next_evnt field of the ROM is continuously compared to the
current value of the v_counter. When a match occurs, the v_evnt_cntr is
incremented and the vertical state machine moves to the next state. The
v_evnt_rom generates the V and F bits, the clr_v signal that causes both the
v_counter and the v_evnt_cntr to reset at the end of the current line, and the
vband values which specifies which vertical region (color bar band) is
currently active.

It should be noted that the v_next_evnt field of the vertical state machine's
ROM contains the line number immediately before the event transition. For
example, if it is desired for the state machine to generate a new set of
outputs on line number 4, then the v_next_evnt field must be set to 3. When the
v_counter reaches line 3 a match occurs which causes the v_evnt_cntr to be
incremented at the beginning of line 4, generating a new set of outputs from
the v_evnt_rom. The same is true for the horizontal state machine described
below.

The horizontal state machine is responsible for controlling the generation of
the H bit, for incrementing the v_counter at the beginning of the horizontal
blanking period, for determining when to generate the TRS symbols, and for
determining which color bar should be generated.

The horizontal state machine has a structure virtually identical to the
vertical state machine with a h_evnt_cntr, h_rom, and h_counter. The
output of the h_rom are the H bit, a trs signal which indicates when a TRS
symbol is to be generated, an inc_v signal which causes the v_counter to
increment, a clr_h signal which resets the h_counter (but not, in this case,
the h_evnt_cntr), and the h_region value which specifies which horizontal region
of the screen (color bar) is currently active. Note that the clr_h signal does 
not reset the h_evnt_cntr. This means that h_evnt_cntr must always cycle through
exactly 16 states across one line. If there are not 16 events required per
line, dummy states must be inserted for padding.

The contents of the horizontal and vertical state machine ROMs are basically
all controlled by the horizontal and vertical parameters. Changing these
parameters will change the number of lines, horizontal pixels, and color bar
positions.

The h_region and vband values generated by the two state machines are used as 
the address into the color ROM which determines which of eight colors should be
generated for the current pixel. The color generated by the color ROM is used
as an address into the video ROM which generates the actual YCbCr component
video values.

When a TRS symbol is being generated, the address into the video ROM consists
of the F, V, and H bits. The video ROM generates the correct XYZ word for the
TRS symbol.

It is important to note that this colorbar generator produces does not have a
low pass filter on the video output. Therefore, the edge rates of the
transitions between color bars are too high to meet normal video standards. This
colorbar generator is intended to be used in conjunction with a low pass video
filter that will remove the high frequency content. 
*/

`timescale 1ns / 1ns

module colorbars (
    clk,
    rst,
    ce,
    q,
    h_sync,
    v_sync,
    field
);

//-----------------------------------------------------------------------------
// Parameter definitions
//

//
// This group of parameters defines the bit widths of various fields in the
// module. Note that if the VID_WIDTH parameter is changed, the video component
// values for the various colors will need to be modified accordingly.
//
parameter VID_WIDTH     = 8;                   // Width of video components
parameter HCNT_WIDTH    = 11;                   // Width of h_counter
parameter VCNT_WIDTH    = 10;                   // Width of v_counter
parameter HRGN_WIDTH    = 4;                    // Width of h_region counter
parameter VRGN_WIDTH    = 4;                    // Width of v_region counter
parameter COLOR_WIDTH   = 3;                    // Width of color code
parameter VBAND_WIDTH   = 2;                    // Width of vband code

parameter V_EVNT_WIDTH  = VCNT_WIDTH;           // Width of v_next_evnt
parameter H_EVNT_WIDTH  = HCNT_WIDTH - 2;       // Width of h_next_evnt
parameter VROM_WIDTH    = V_EVNT_WIDTH + VBAND_WIDTH + 3; // Width of v_rom
parameter HROM_WIDTH    = H_EVNT_WIDTH + 4;     // Width of h_rom
 
parameter VID_MSB       = VID_WIDTH - 1;        // MS bit # of video data path
parameter HCNT_MSB      = HCNT_WIDTH - 1;       // MS bit # of h_counter
parameter VCNT_MSB      = VCNT_WIDTH - 1;       // MS bit # of v_counter
parameter HRGN_MSB      = HRGN_WIDTH - 1;       // MS bit # of h_region counter
parameter VRGN_MSB      = VRGN_WIDTH - 1;       // MS bit # of v_region counter
parameter COLOR_MSB     = COLOR_WIDTH - 1;      // MS bit # of color code
parameter VBAND_MSB     = VBAND_WIDTH - 1;      // MS bit # of vband code
parameter V_EVNT_MSB    = V_EVNT_WIDTH - 1;     // MS bit # of v_next_evnt
parameter H_EVNT_MSB    = H_EVNT_WIDTH - 1;     // MS bit # of h_next_evnt
parameter VROM_MSB      = VROM_WIDTH - 1;       // MS bit # of v_rom
parameter HROM_MSB      = HROM_WIDTH - 1;       // MS bit # of h_rom

//
// This group of parameters controls the total number of lines (both fields) and
// specifies where the odd and even lines begin and where the vertical blanking
// periods begin and end.
//
parameter V_TOTAL       = 525;                  // total lines (two fields)
parameter V_O_FLD_START = 4;                    // first line of odd field
parameter V_O_ACT_START = 20;                   // first active video line, odd field
parameter V_O_BNK_START = 264;                  // first v blanking line, odd field
parameter V_E_FLD_START = 266;                  // first line of even field
parameter V_E_ACT_START = 283;                  // first active video line, even field
parameter V_E_BNK_START = 1;                    // first v blanking line, even field

//
// This group of parameters controls where the three vertical bands of the
// color bar pattern begin for each of the two fields.
//
parameter BAND1_START_E = V_E_ACT_START;        // first line of top band, even field
parameter BAND1_START_O = V_O_ACT_START;        // first line of top band, odd field
parameter BAND2_START_E = V_E_ACT_START + 163;  // first line of middle band, even field
parameter BAND2_START_O = V_O_ACT_START + 163;  // first line of middle band, odd field
parameter BAND3_START_E = V_E_ACT_START + 182;  // first line of bottom band, even field
parameter BAND3_START_O = V_O_ACT_START + 183;  // first line of bottom band, odd field

//
// This group of parameters controls the total number of clocks per line and
// positions of the two TRS symbols.
//
parameter H_TOTAL       = 1716;                 // total clocks on the line
parameter H_EAV_START   = 1440;                 // EAV start pixel
parameter H_SAV_START   = 1712;                 // SAV start pixel
                                               
//
// This group of parameters controls the starting horizontal position of each
// horizontal region. The line is divided up into 12 regions which correspond
// to possible places for a color bar to begin or end when implementing the
// SMPTE EG-1 color bars. Some color bars will span several horizontal regions.
//
parameter BAR0_START    = 0;
parameter BAR1_START    = 208;
parameter BAR2_START    = 260;
parameter BAR3_START    = 416;
parameter BAR4_START    = 520;
parameter BAR5_START    = 624;
parameter BAR6_START    = 780;
parameter BAR7_START    = 832;
parameter BAR8_START    = 1040;
parameter BAR9_START    = 1108;
parameter BARA_START    = 1180;
parameter BARB_START    = 1248;

// 
// This group of parameters specifies the Y, Cb, and Cr values for each of the
// colors used in the color bars.
//
parameter GRAY_Y    = 721,  GRAY_CB     = 512,  GRAY_CR     = 512;  // 75% white
parameter YELLOW_Y  = 674,  YELLOW_CB   = 176,  YELLOW_CR   = 543;
parameter CYAN_Y    = 581,  CYAN_CB     = 589,  CYAN_CR     = 176;
parameter GREEN_Y   = 534,  GREEN_CB    = 253,  GREEN_CR    = 207;
parameter MAGENTA_Y = 251,  MAGENTA_CB  = 771,  MAGENTA_CR  = 817;
parameter RED_Y     = 204,  RED_CB      = 435,  RED_CR      = 848;
parameter BLUE_Y    = 111,  BLUE_CB     = 848,  BLUE_CR     = 481;
parameter BLACK_Y   =  64,  BLACK_CB    = 512,  BLACK_CR    = 512;

//
// This set of parameters specifies the encoding of the color values stored in
// color ROM.
//
parameter [COLOR_WIDTH - 1:0]
    GRAY    = 3'b000,
    YELLOW  = 3'b001,
    CYAN    = 3'b010,
    GREEN   = 3'b011,
    MAGENTA = 3'b100,
    RED     = 3'b101,
    BLUE    = 3'b110,
    BLACK   = 3'b111;

//
// The set of parameters specifies the encoding of the vband signals.
//
parameter [VBAND_WIDTH - 1:0]
    BAND_V_BLANK = 2'b00,                           // vertical blanking band
    BAND1        = 2'b01,                           // top band
    BAND2        = 2'b10,                           // middle band
    BAND3        = 2'b11;                           // bottom band

//-----------------------------------------------------------------------------
// Signal definitions
//

// IO definitions
input                   clk;            // clock input
input                   rst;            // reset input
input                   ce;             // clock enable input
output  [VID_MSB:0]     q;              // video output
output                  h_sync;         // horizontal sync
output                  v_sync;         // vertical sync
output                  field;          // field (0 = odd, 1 = even)

// internal registers
reg     [VID_MSB:0]     q;              // video output register
reg                     h_sync;         // output register for H bit
reg                     v_sync;         // output register for V bit
reg                     field;          // output register for F bit
reg     [HCNT_MSB:0]    h_counter;      // horizontal counter
reg     [VCNT_MSB:0]    v_counter;      // vertical counter
reg     [VRGN_MSB:0]    v_region;       // vertical region counter
reg     [HRGN_MSB:0]    h_region;       // horizontal region counter

// internal signals
reg     [VID_MSB:0]     out;            // data before output register
reg     [COLOR_MSB:0]   color_out;      // output of color ROM
reg     [COLOR_MSB:0]   color_fvh;      // ms address bits of video ROM
reg     [1:0]           comp;           // ls address bits of video ROM
wire    [VBAND_MSB:0]   vband;          // ms address bits of color ROM
wire                    f;              // field bit
wire                    v;              // vertical blanking bit
wire                    h;              // horizontal blanking bit
wire                    inc_v;          // signal to increment the v_counter
wire                    clr_v;          // signal to clear the v_counter
wire                    clr_h;          // signal to clear the h_counter
wire                    trs;            // indicates when TRS symbol is being generated
wire    [1:0]           trs_word;       // indicates which word of TRS symbol is being generated
reg     [VID_MSB:0]     video_out;      // output of video ROM
wire    [H_EVNT_MSB:0]  h_next_evnt;    // h_counter value of next horizontal event
reg     [HROM_MSB:0]    h_rom;          // output of horizontal event ROM
wire    [V_EVNT_MSB:0]  v_next_evnt;    // v_counter value of next vertical event
reg     [VROM_MSB:0]    v_rom;          // output of vertical event ROM
wire                    v_evnt_match;   // output of vertical event comparator
wire                    h_evnt_match;   // output of horizontal event comparator


//
// video ROM
//
// The video ROM generates the actual component video values based on the
// "color" input value or the TRS symbol's XYZ word based on the FVH bits.
// The ROM is organized into eight blocks of four words. Each block corresponds
// to a color value (or a FVH value). The first word in each block is the CB
// component. The second word is the Y component. The third word is the CR
// component. And, the fourth word is the XYZ word.
//
always @ (color_fvh or comp)
    case({color_fvh, comp})
        0 : video_out = GRAY_CB;
        1 : video_out = GRAY_Y;
        2 : video_out = GRAY_CR;
        3 : video_out = 8'b1_0_0_0_0000 << (VID_WIDTH - 8);
        4 : video_out = YELLOW_CB;
        5 : video_out = YELLOW_Y;
        6 : video_out = YELLOW_CR;
        7 : video_out = 8'b1_0_0_1_1101 << (VID_WIDTH - 8);
        8 : video_out = CYAN_CB;
        9 : video_out = CYAN_Y;
        10: video_out = CYAN_CR;
        11: video_out = 8'b1_0_1_0_1011 << (VID_WIDTH - 8);
        12: video_out = GREEN_CB;
        13: video_out = GREEN_Y;
        14: video_out = GREEN_CR;
        15: video_out = 8'b1_0_1_1_0110 << (VID_WIDTH - 8);
        16: video_out = MAGENTA_CB;
        17: video_out = MAGENTA_Y;
        18: video_out = MAGENTA_CR;
        19: video_out = 8'b1_1_0_0_0111 << (VID_WIDTH - 8);
        20: video_out = RED_CB;
        21: video_out = RED_Y;
        22: video_out = RED_CR;
        23: video_out = 8'b1_1_0_1_1010 << (VID_WIDTH - 8);
        24: video_out = BLUE_CB;
        25: video_out = BLUE_Y;
        26: video_out = BLUE_CR;
        27: video_out = 8'b1_1_1_0_1100 << (VID_WIDTH - 8);
        28: video_out = BLACK_CB;
        29: video_out = BLACK_Y;
        30: video_out = BLACK_CR;
        31: video_out = 8'b1_1_1_1_0001 << (VID_WIDTH - 8);
    endcase

//
// color ROM
//
// The color ROM converts the vband and h_region values into a color value.
// It determines the correct color to output based on which region of the
// screen is currently active.
//
always @ (vband or h_region)
    case({vband,h_region})  
        // First 16 locations are in the vertical blanking period
        0 : color_out = BLACK;
        1 : color_out = BLACK;
        2 : color_out = BLACK;
        3 : color_out = BLACK;
        4 : color_out = BLACK;
        5 : color_out = BLACK;
        6 : color_out = BLACK;
        7 : color_out = BLACK;
        8 : color_out = BLACK;
        9 : color_out = BLACK;
        10: color_out = BLACK;
        11: color_out = BLACK;
        12: color_out = BLACK;
        13: color_out = BLACK;
        14: color_out = BLACK;
        15: color_out = BLACK;

        // Locations 16 thru 31 are in the top color band
        16: color_out = BLACK;
        17: color_out = BLACK;
        18: color_out = BLACK;
        19: color_out = GRAY;
        20: color_out = YELLOW;
        21: color_out = YELLOW;
        22: color_out = CYAN;
        23: color_out = CYAN;
        24: color_out = GREEN;
        25: color_out = GREEN;
        26: color_out = MAGENTA;
        27: color_out = RED;
        28: color_out = RED;
        29: color_out = RED;
        30: color_out = BLUE;
        31: color_out = BLUE;

        // Locations 32 thru 47 are in the middle color band
        32: color_out = BLACK;
        33: color_out = BLACK;
        34: color_out = BLACK;
        35: color_out = BLUE;
        36: color_out = BLACK;
        37: color_out = BLACK;
        38: color_out = MAGENTA;
        39: color_out = MAGENTA;
        40: color_out = BLACK;
        41: color_out = BLACK;
        42: color_out = CYAN;
        43: color_out = BLACK;
        44: color_out = BLACK;
        45: color_out = BLACK;
        46: color_out = GRAY;
        47: color_out = GRAY;

        // Locations 48 through 63 are in the bottom color band
        48: color_out = BLACK;
        49: color_out = BLACK;
        50: color_out = BLACK;
        51: color_out = GRAY;
        52: color_out = GRAY;
        53: color_out = GRAY;
        54: color_out = GRAY;
        55: color_out = GRAY;
        56: color_out = GRAY;
        57: color_out = BLACK;
        58: color_out = BLACK;
        59: color_out = BLACK;
        60: color_out = BLACK;
        61: color_out = BLACK;
        62: color_out = BLACK;
        63: color_out = BLACK;
    endcase

//
// vertical state machine
//

// generate the line counter comparator
assign v_evnt_match = (v_counter == v_next_evnt);

//
// v_region counter
//
// This is counter holds the current state value of the vertical state machine.
// It increments at the end of line as indicated by the inc_v signal from the
// horizontal state machine if the current contents of the v_counter match
// the v_next_evnt ROM's output.
//
always @ (posedge clk or posedge rst)
    if (rst)
        v_region <= 15;
    else
        if (ce)
            begin
                if ((h_counter[1:0] == 2'b11) && inc_v) 
                    begin
                        if (clr_v)
                            v_region <= 0;
                        else if (v_evnt_match)
                            v_region <= v_region + 1;
                    end
            end
        
//
// v_envt_rom
//
// This ROM generates the control outputs for the vertical state machine.
// It also generates the line number of the next vertical event. 
//
always @ (v_region)
    case(v_region)
        //                     next_evnt      v f clr   band
        0 :     v_rom <= {V_O_FLD_START-1, 3'b1_1_0, BAND_V_BLANK}; // start v blank
        1 :     v_rom <= {V_O_ACT_START-1, 3'b1_0_0, BAND_V_BLANK}; // start fld 1
        2 :     v_rom <= {BAND2_START_O-1, 3'b0_0_0, BAND1};        // start band 1
        3 :     v_rom <= {BAND3_START_O-1, 3'b0_0_0, BAND2};        // start band 2
        4 :     v_rom <= {V_O_BNK_START-1, 3'b0_0_0, BAND3};        // start band 3
        5 :     v_rom <= {V_E_FLD_START-1, 3'b1_0_0, BAND_V_BLANK}; // start v blank
        6 :     v_rom <= {V_E_ACT_START-1, 3'b1_1_0, BAND_V_BLANK}; // start fld 2
        7 :     v_rom <= {BAND2_START_E-1, 3'b0_1_0, BAND1};        // start band 1
        8 :     v_rom <= {BAND3_START_E-1, 3'b0_1_0, BAND2};        // start band 2
        9 :     v_rom <= {V_TOTAL-1,       3'b0_1_0, BAND3};        // start band 3
        10:     v_rom <= {V_TOTAL,         3'b0_1_1, BAND3};        // last line fld 2
        default:v_rom <= {V_TOTAL,         3'b0_1_1, BAND3};        // default
    endcase

//
// assign the individual fields from the v_envt_rom output
//
assign v_next_evnt  = v_rom[V_EVNT_MSB + VBAND_WIDTH + 3:VBAND_WIDTH + 3];
assign v            = v_rom[VBAND_WIDTH + 2];
assign f            = v_rom[VBAND_WIDTH + 1];
assign clr_v        = v_rom[VBAND_WIDTH];
assign vband        = v_rom[VBAND_MSB:0];

//
// horizontal state machine
//

// generate the h_counter comparator
assign h_evnt_match = (h_counter[HCNT_MSB:2] == h_next_evnt);


// h_region counter
//
// The h_region counter contains the current state of the horizontal state 
// machine. This counter increments when the contents of the h_counter match 
// the h_next_evnt value generated by the h_rom.
//
always @ (posedge clk or posedge rst)
    if (rst)
        h_region <= 15;
    else
        if (ce)
            if ((h_counter[1:0] == 2'b11) && h_evnt_match)
                h_region <= h_region + 1;
        
//
// h_rom
//
// Based on the current horizontal state contained in the h_region counter, this
// ROM generates the control signals for the horzintal state machine. It also
// generates the horizontal count value to match against the h_counter for the
// next state transition.
//
always @ (h_region)
    case(h_region)  
        //               next event           h t i c
        //                                      r n l
        //                                      s c r
        //                                        v h  
        0 :   h_rom <= { H_EAV_START/4,    4'b1_1_0_0}; // EAV
        1 :   h_rom <= {(H_SAV_START/4)-1, 4'b1_0_0_0}; // h blanking
        2 :   h_rom <= {(H_TOTAL    /4)-1, 4'b0_1_0_1}; // SAV
        3 :   h_rom <= {(BAR1_START /4)-1, 4'b0_0_0_0}; // BAR 0
        4 :   h_rom <= {(BAR2_START /4)-1, 4'b0_0_0_0}; // BAR 1
        5 :   h_rom <= {(BAR3_START /4)-1, 4'b0_0_0_0}; // BAR 2
        6 :   h_rom <= {(BAR4_START /4)-1, 4'b0_0_0_0}; // BAR 3                
        7 :   h_rom <= {(BAR5_START /4)-1, 4'b0_0_0_0}; // BAR 4
        8 :   h_rom <= {(BAR6_START /4)-1, 4'b0_0_0_0}; // BAR 5
        9 :   h_rom <= {(BAR7_START /4)-1, 4'b0_0_0_0}; // BAR 6
        10:   h_rom <= {(BAR8_START /4)-1, 4'b0_0_0_0}; // BAR 7
        11:   h_rom <= {(BAR9_START /4)-1, 4'b0_0_0_0}; // BAR 8
        12:   h_rom <= {(BARA_START /4)-1, 4'b0_0_0_0}; // BAR 9
        13:   h_rom <= {(BARB_START /4)-1, 4'b0_0_0_0}; // BAR A
        14:   h_rom <= {(H_EAV_START/4)-2, 4'b0_0_0_0}; // BAR B
        15:   h_rom <= {(H_EAV_START/4)-1, 4'b0_0_1_0}; // last active sample
    endcase

assign h_next_evnt  = h_rom[H_EVNT_WIDTH + 3:4];
assign h            = h_rom[3];
assign trs          = h_rom[2];
assign inc_v        = h_rom[1];
assign clr_h        = h_rom[0];

//
// v_counter
//
// The v_counter keeps track of the current line number. It increments during
// the generation of the EAV signal since SMPTE 125M specifies that each line
// begins with the EAV symbol (although the pixel counter is not 0 at this
// point). To match the SMPTE 125M specification, the count of the first line is
// zero, not one. On reset, the line counter is set to the last line. It will
// increment to the first line one the first clock after the reset is negated.
//
always @ (posedge clk or posedge rst)
    if (rst)
        v_counter <= V_TOTAL;           
    else if (ce)
        if ((h_counter[1:0] == 2'b11) && inc_v)
            begin
                if (clr_v)
                    v_counter <= 1;
                else
                    v_counter <= v_counter + 1;
            end

//
// h_counter
//
// The h_counter keeps track of the current vertical position on the screen.
// The h_counter counts from 0 (which is the first active video position) to
// the maximum count for the line (which corresponds to last word of the SAV).
// On reset, the h_counter is set to the EAV position so that an EAV is
// the first thing generated after reset.
//
always @ (posedge clk or posedge rst)
    if (rst)
        h_counter <= H_EAV_START-1;
    else if (ce)
        begin
            if (clr_h && (h_counter[1:0] == 2'b11))
                h_counter <= 0;
            else
                h_counter <= h_counter + 1;
        end

//
// This logic implements a mux on the output of the color ROM. If a TRS is to
// be generated, the FVH bits are output instead of the color_out value.
always @ (color_out or trs or f or v or h)
    if (trs)
        color_fvh <= {f,v,h};
    else
        color_fvh <= color_out;

//
// This logic generates the two LS address bits into the video ROM. These
// bits determine which video component should be generated (Y, Cb, or Cr). If
// a TRS is being generated, these bits force the video ROM to generated the
// XYZ word.
//
always @ (trs or h_counter)
    casex ({trs, h_counter[1:0]})
        3'b1xx : comp <= 2'b11;         // TRS
        3'b000 : comp <= 2'b00;         // Cb
        3'b001 : comp <= 2'b01;         // Y
        3'b010 : comp <= 2'b10;         // Cr
        3'b011 : comp <= 2'b01;         // Y
    endcase

//
// This logic implements a mux on the output of the video ROM. Normally, the 
// output of the video ROM is sent to the output register. If a TRS is being
// generated, this MUX can force the output to be all zeros or all ones as
// required.
//
assign trs_word = h_counter[1:0];

always @ (trs or trs_word or video_out)
    casex ({trs,trs_word})
        3'b0xx : out <= video_out;
        3'b100 : out <= {VID_WIDTH{1'b1}};  // 0x3FF
        3'b101 : out <= {VID_WIDTH{1'b0}};  // 0x000
        3'b110 : out <= {VID_WIDTH{1'b0}};  // 0x000
        3'b111 : out <= video_out;
    endcase
//
// This code implements the output registers.
//
reg [7:0] cnt = 8'h00;

always @ (posedge clk or posedge rst)
	 if (rst)
        begin
            q <= {VID_WIDTH{1'b0}};
            h_sync <= 0;
            v_sync <= 0;
            field  <= 0;
        end
    else if (ce)
        begin
				cnt <= cnt + 1;
				q <= (trs) ? out : out + cnt;
            h_sync <= h | trs;
            v_sync <= v;
            field <=  f;
        end

endmodule