#!/bin/sh

echo ""

# _env_a
export SEKEY=olxbeulckxseouzgeoul8349
../Release/TC_C_121_v1017 < stdin_hello_quit.txt
echo ""

# _env_b
export SEKEY=adafafsacasdw41rfq24y3ew
../Release/TC_C_121_v1017 < stdin_hello_quit.txt
echo ""

# _env_c
export SEKEY=aex9340ktvox9sazuj0k03se
../Release/TC_C_121_v1017 < stdin_hidden_quit.txt
echo ""

# _env_d
export SEKEY=ydb945bkix40kxvz30kxzaui
../Release/TC_C_121_v1017 < stdin_encrypted_quit.txt
echo ""

# _env_e
export SEKEY=adafafsacasdw41rfq24y3eaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
../Release/TC_C_121_v1017 < stdin_hello_quit.txt
echo ""

# _env_p
export SEKEY=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
../Release/TC_C_121_v1017 < stdin_hello_quit.txt
echo ""

# _env_p2
export SEKEY=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
../Release/TC_C_121_v1017 < stdin_hello_quit.txt
echo ""

