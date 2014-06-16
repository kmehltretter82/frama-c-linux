@echo off

echo .

@rem _v922-fileName-a
..\Release\TC_C_121_v922.exe keya_good < stdin_hello_quit.txt
echo .

@rem _v922-fileName-b
..\Release\TC_C_121_v922.exe keyb_good < stdin_hello_quit.txt
echo .

@rem _v922-fileName-c
..\Release\TC_C_121_v922.exe keyc_good < stdin_hello_goodbye_quit.txt
echo .

@rem _v922-fileName-bad-f
..\Release\TC_C_121_v922.exe keyf_bad < stdin_hello_quit.txt
echo .

@rem _fileName_W1_Bad
..\Release\TC_C_121_v922.exe key1_bad_windows < stdin_hello_quit.txt
echo .

