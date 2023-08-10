#pragma once

#include "Common.h"
#include "z80.h"
#include "Video.h"
#include "AY8910.h"

// 3579545 Hz -> 59659 cycles / frame
// 7159090 Hz -> 119318 cycles / frame

// 455x262=119210 -> 60.05 Hz
// 51.2us + 1.5us + 4.7us + 6.2us = 63.6 us
// 366 active pixels

#define HCYCLES_PER_LINE (455)
#define HCYCLES_PER_SAMPLE (162)

#define BANK_READONLY (1 << 7)
#define BANK_MAP_RAM (1 << 6)

struct EmuState {
    EmuState();
    void reset();
    bool loadCartridgeROM(const char *path);
    void keyboardTypeIn();

    static uint8_t memRead(size_t param, uint16_t addr);
    static void    memWrite(size_t param, uint16_t addr, uint8_t data);
    static uint8_t ioRead(size_t param, ushort addr);
    static void    ioWrite(size_t param, uint16_t addr, uint8_t data);

    // Emulator state
    Z80Context z80ctx;           // Z80 emulation core state
    Video      video;            // Video
    int        lineHalfCycles;   // Half-cycles for this line
    int        sampleHalfCycles; // Half-cycles for this sample
    uint8_t    keybMatrix[8];    // Keyboard matrix (8 x 6bits)
    uint8_t    handCtrl1;        // Mini-expander - Hand controller 1 state (connected to port 1 of AY-3-8910)
    uint8_t    handCtrl2;        // Mini-expander - Hand controller 2 state (connected to port 1 of AY-3-8910)
    bool       cartridgeInserted;
    size_t     flashRomSize;

    // Virtual typing from command-line argument
    const char *typeInStr;
    int         typeInRelease;
    int         typeInDelay;
    char        typeInChar;

    // IO space
    uint8_t  videoCtrl;         // $E0   : Video control register
    uint16_t videoScrX;         // $E1/E2: Tile map horizontal scroll register
    uint8_t  videoScrY;         // $E3   : Tile map horizontal scroll register
    uint8_t  videoSprSel;       // $E4   : Sprite select
    uint16_t videoSprX[64];     // $E5/E6: Sprite X-position
    uint8_t  videoSprY[64];     // $E7   : Sprite Y-position
    uint16_t videoSprIdx[64];   // $E8/E9: Sprite tile index
    uint8_t  videoSprAttr[64];  // $E9   : Sprite attributes
    uint8_t  videoPalSel;       // $EA   : Palette entry select
    uint16_t videoPalette[64];  // $EB   : Video palette
    uint16_t videoLine;         // $EC   : Current line number
    uint8_t  videoIrqLine;      // $ED   : Line number at which to generate IRQ
    uint8_t  irqMask;           // $EE   : Interrupt mask register
    uint8_t  irqStatus;         // $EF   : Interrupt status register
    uint8_t  bankRegs[4];       // $F0-F3: Banking registers
    AY8910   ay1;               // $F6/F7: AY-3-8910 emulation state
    uint8_t  ay1Addr;           // $F7   : AY-3-8910: Selected address to access via data register
    AY8910   ay2;               // $F8/F9: AY-3-8910 emulation state
    uint8_t  ay2Addr;           // $F9   : AY-3-8910: Selected address to access via data register
    bool     sysCtrlDisableExt; // $FB<0>: Disable access to extended registers
    bool     sysCtrlAyDisable;  // $FB<1>: Disable AY PSGs
    bool     soundOutput;       // $FC<1>: Cassette/Sound output
    bool     cpmRemap;          // $FD<1>: Remap memory for CP/M

    // Memory space
    uint8_t screenRam[1024];      // $3000-33FF: Screen RAM for text mode
    uint8_t colorRam[1024];       // $3400-37FF: Color RAM for text mode
    uint8_t flashRom[256 * 1024]; // Flash memory
    uint8_t mainRam[512 * 1024];  // Main RAM
    uint8_t cartRom[16 * 1024];   // Cartridge ROM
    uint8_t videoRam[16 * 1024];  // Video RAM
    uint8_t charRam[2048];        // Character RAM
};

extern EmuState emuState;
