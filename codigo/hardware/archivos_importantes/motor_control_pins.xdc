###############################################################################
# RESTRICCIONES DE PINES - CONTROL DE MOTOR
# Placa: PYNQ-Z2
# Conector utilizado: Pmod B
###############################################################################


###############################################################################
# SALIDA PWM
#
# Pmod B - Pin 1
# FPGA pin W14
#
# Conexión:
# pwm_out -> ENA del L298N
###############################################################################

set_property -dict { PACKAGE_PIN W14 IOSTANDARD LVCMOS33 } [get_ports {pwm_out}]


###############################################################################
# CONTROL DE DIRECCIÓN - IN1
#
# Pmod B - Pin 2
# FPGA pin Y14
#
# Conexión:
# motor_in1 -> IN1 del L298N
###############################################################################

set_property -dict { PACKAGE_PIN Y14 IOSTANDARD LVCMOS33 } [get_ports {motor_in1}]


###############################################################################
# CONTROL DE DIRECCIÓN - IN2
#
# Pmod B - Pin 3
# FPGA pin T11
#
# Conexión:
# motor_in2 -> IN2 del L298N
###############################################################################

set_property -dict { PACKAGE_PIN T11 IOSTANDARD LVCMOS33 } [get_ports {motor_in2}]


###############################################################################
# ENCODER - CANAL A
#
# Pmod B - Pin 4
# FPGA pin T10
#
# Conexión:
# Canal A del encoder -> encoder_a
###############################################################################

set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 } [get_ports {encoder_a}]


###############################################################################
# ENCODER - CANAL B
#
# Pmod B - Pin 7
# FPGA pin V16
#
# Conexión:
# Canal B del encoder -> encoder_b
###############################################################################

set_property -dict { PACKAGE_PIN V16 IOSTANDARD LVCMOS33 } [get_ports {encoder_b}]