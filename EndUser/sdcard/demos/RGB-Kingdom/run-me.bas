10 REM RGB Kingdom Slideshow
15 LOAD"data/color-title.scr",12288
20 IF INKEY$="" GOTO 20
100 REM Set mem map to VRAM
120 LOAD"data/rgb_000000.bm4",@20,0
121 GOSUB 1150
122 LOAD"data/rgb_ffffff.bm4",@20,0
123 GOSUB 1150
124 LOAD"data/rgb_ff0000.bm4",@20,0
125 GOSUB 1150
126 LOAD"data/rgb_0000ff.bm4",@20,0
127 GOSUB 1150
128 LOAD"data/rgb_00ff00.bm4",@20,0
129 GOSUB 1150
130 LOAD"data/rgb_00ffff.bm4",@20,0
131 GOSUB 1150
132 LOAD"data/rgb_ffff00.bm4",@20,0
133 GOSUB 1150
134 LOAD"data/rgb_ff00ff.bm4",@20,0
135 GOSUB 1150
998 CLS
999 END
1000 REM Loops and Subroutines
1150 SET PALETTE 1 TO PEEK$(@20,16000+I,32)
1160 SCREEN 0,3,0,0,0:REM Set Video Reg to Color BM
1170 PAUSE
1180 SCREEN 0,0,0,0,0
1190 RETURN
