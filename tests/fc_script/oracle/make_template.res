Preparing template: result/GNUmakefile
Running ptests: setting up mock files...
warning: result/GNUmakefile already exists. Overwrite? [y/N] Main target name: Source files (default: **/*.c): The following sources were matched (relative to result):
  ../for-find-fun.c
  ../for-find-fun2.c
  ../main.c	# defines 'main'
  ../main2.c
  ../main3.c	# defines 'main'

warning: 'main' seems to be defined multiple times.
Is this ok? [Y/n] compile_commands.json exists, add option -json-compilation-database? [Y/n] Add stub for function main (only needed if it uses command-line arguments)? [y/N] Please define the architectural model (machdep) of the target machine.
Known machdeps: x86_16 x86_32 x86_64 gcc_x86_16 gcc_x86_32 gcc_x86_64 ppc_32 msvc_x86_64
Please enter the machdep [x86_32]: 'invalid_machdep' is not a standard machdep. Proceed anyway? [y/N]Please enter the machdep [x86_32]: warning: result/fc_stubs.c already exists. Overwrite? [y/N] Wrote to: result/path.mk
Created stub for main function: result/fc_stubs.c
Template created: result/GNUmakefile
Frama-C not in path, adding path.mk to result
Running ptests: cleaning up after tests...
