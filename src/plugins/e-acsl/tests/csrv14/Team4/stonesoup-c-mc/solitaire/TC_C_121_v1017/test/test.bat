@echo off

echo .

@rem _env_a
set SEKEY=olxbeulckxseouzgeoul8349
..\Release\TC_C_121_v1017.exe < stdin_hello_quit.txt
echo .

@rem _env_b
set SEKEY=adafafsacasdw41rfq24y3ew
..\Release\TC_C_121_v1017.exe < stdin_hello_quit.txt
echo .

@rem _env_c
set SEKEY=aex9340ktvox9sazuj0k03se
..\Release\TC_C_121_v1017.exe < stdin_hidden_quit.txt
echo .

@rem _env_d
set SEKEY=ydb945bkix40kxvz30kxzaui
..\Release\TC_C_121_v1017.exe < stdin_encrypted_quit.txt
echo .

@rem _env_e
set SEKEY=adafafsacasdw41rfq24y3eaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
..\Release\TC_C_121_v1017.exe < stdin_hello_quit.txt
echo .

@rem _env_p
set SEKEY=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
..\Release\TC_C_121_v1017.exe < stdin_hello_quit.txt
echo .

@rem _env_p2
set SEKEY=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
..\Release\TC_C_121_v1017.exe < stdin_hello_quit.txt
echo .

