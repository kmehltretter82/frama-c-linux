################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../src/random_lw.c \
../src/regfuncs.c \
../src/solitaire.c 

OBJS += \
./src/random_lw.o \
./src/regfuncs.o \
./src/solitaire.o 

C_DEPS += \
./src/random_lw.d \
./src/regfuncs.d \
./src/solitaire.d 


# Each subdirectory must supply rules for building sources it contributes
src/%.o: ../src/%.c
	@echo 'Building file: $<'
	@echo 'Invoking: GCC C Compiler'
	$(SS_CC) -O0 -Wall $(SS_CFLAGS) -c -fmessage-length=0 -MMD -MP -MF"$(@:%.o=%.d)" -MT"$(@:%.o=%.d)" -o"$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '


