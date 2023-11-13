#!/usr/bin/env python3
import argparse
import sys

ROMSIZE = 8192

parser = argparse.ArgumentParser(description="Convert binary file into verilog ROM")
parser.add_argument("input", help="Binary input file", type=argparse.FileType("rb"))
parser.add_argument("output", help="Verilog output file", type=argparse.FileType("w"))
args = parser.parse_args()
f = args.output

# Read input file
data = args.input.read()

# Check size
if len(data) > ROMSIZE:
    print(
        f"Input should be maximum {ROMSIZE} bytes long, but is {len(data)} bytes",
        file=sys.stderr,
    )
    exit(1)

# Pad to expected size
if len(data) < ROMSIZE:
    print(f"Padding ROM from {len(data)} to {ROMSIZE} bytes", file=sys.stderr)
    data = data.ljust(ROMSIZE, b"\xFF")


# Generate one block RAM with data
def genram(num, data):
    print(f"    wire [7:0] rddata_{num:02};", file=f)
    print(f"    wire       p2_wren_{num:02} = (p2_wren && p2_addr[12:11] == 2'd{num});", file=f)
    print("    RAMB16_S9_S9 #(", file=f)

    data_strs = [f"{val:02X}" for val in data]
    for i in range(0, 64):
        print(
            f"        .INIT_{i:02X}(256'h{''.join(list(reversed(data_strs[32*i:32*(i+1)])))}){',' if i<63 else ''}",
            file=f,
        )

    print(f"    ) ram_{num:02}(", file=f)
    print(
        f"        .CLKA(clk), .SSRA(1'b0), .ADDRA(   addr[10:0]), .DOA(rddata_{num:02}), .DOPA(), .DIA(8'b0),      .DIPA(1'b0), .ENA(1'b1), .WEA(1'b0),",
        file=f,
    )
    print(
        f"        .CLKB(clk), .SSRB(1'b0), .ADDRB(p2_addr[10:0]), .DOB(),          .DOPB(), .DIB(p2_wrdata), .DIPB(1'b0), .ENB(1'b1), .WEB(p2_wren_{num:02}));\n",
        file=f,
    )


print(
    """// CAUTION: This file is automatically generated by genrom.py. Don't edit by hand!
module rom(
    input  wire        clk,
    input  wire [12:0] addr,
    output reg   [7:0] rddata,
    
    input  wire [12:0] p2_addr,
    input  wire  [7:0] p2_wrdata,
    input  wire        p2_wren);

    reg [12:0] addr_r;
    always @(posedge clk) addr_r <= addr;
""",
    file=f,
)


for i in range(ROMSIZE // 2048):
    genram(i, data[i * 2048 : (i + 1) * 2048])


print("    always @* case (addr_r[12:11])", file=f)
for i in range(ROMSIZE // 2048):
    print(f"        2'd{i}: rddata <= rddata_{i:02};", file=f)
print("        default: rddata <= 8'hFF;", file=f)
print("    endcase", file=f)
print("\nendmodule", file=f)
