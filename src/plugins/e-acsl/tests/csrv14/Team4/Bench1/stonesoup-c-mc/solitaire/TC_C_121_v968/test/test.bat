@echo off

echo .

@rem _FileContentsGooda
..\Release\TC_C_121_v968.exe keya_good < stdin_hello_quit.txt
echo .

@rem _FileContentsGoodb
..\Release\TC_C_121_v968.exe keyb_good < stdin_hello_quit.txt
echo .

@rem _FileContentsGoodc
..\Release\TC_C_121_v968.exe keyc_good < stdin_hello_quit.txt
echo .

@rem _FileContentsGoodd
..\Release\TC_C_121_v968.exe keyd_good < stdin_hello_quit.txt
echo .

@rem _FileContentsGoode
..\Release\TC_C_121_v968.exe keye_good < stdin_hello_quit.txt
echo .

@rem _FileContentsBadf
..\Release\TC_C_121_v968.exe keyf_bad < stdin_hello_quit.txt
echo .

