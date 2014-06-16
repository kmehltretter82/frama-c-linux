#!/bin/sh

echo ""

# _registry_a
cp lin_registry_a.reg registry.conf
../Release/TC_C_121_v1117 < stdin_hello_quit.txt
rm registry.conf
echo ""

# _registry_b
cp lin_registry_b.reg registry.conf
../Release/TC_C_121_v1117 < stdin_hello_quit.txt
rm registry.conf
echo ""

# _registry_c
cp lin_registry_c.reg registry.conf
../Release/TC_C_121_v1117 < stdin_hidden_quit.txt
rm registry.conf
echo ""

# _registry_d
cp lin_registry_d.reg registry.conf
../Release/TC_C_121_v1117 < stdin_encrypted_quit.txt
rm registry.conf
echo ""

# _registry_e
cp lin_registry_e.reg registry.conf
../Release/TC_C_121_v1117 < stdin_hello_quit.txt
rm registry.conf
echo ""

