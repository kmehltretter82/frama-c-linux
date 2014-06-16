@echo off

echo .

@rem _registry_a
@regedit registry_a.reg
..\Release\TC_C_121_v1032.exe < stdin_hello_quit.txt
echo .

@rem _registry_b
@regedit registry_b.reg
..\Release\TC_C_121_v1032.exe < stdin_hello_quit.txt
echo .

@rem _registry_c
@regedit registry_c.reg
..\Release\TC_C_121_v1032.exe < stdin_hidden_quit.txt
echo .

@rem _registry_d
@regedit registry_d.reg
..\Release\TC_C_121_v1032.exe < stdin_encrypted_quit.txt
echo .

@rem _registry_e
@regedit registry_e.reg
..\Release\TC_C_121_v1032.exe < stdin_hello_quit.txt
echo .

