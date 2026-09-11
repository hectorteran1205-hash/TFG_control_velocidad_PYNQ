library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity motor_control_axi is

    generic (

        -- Parameters of Axi Slave Bus Interface S00_AXI
        C_S00_AXI_DATA_WIDTH : integer := 32;
        C_S00_AXI_ADDR_WIDTH : integer := 6
    );

    port (

        ----------------------------------------------------------------
        -- ENTRADAS Y SALIDAS DEL SISTEMA DE CONTROL DEL MOTOR
        ----------------------------------------------------------------

        -- Salidas hacia el driver L298N
        pwm_out   : out std_logic;
        motor_in1 : out std_logic;
        motor_in2 : out std_logic;

        -- Entradas procedentes del encoder
        encoder_a : in std_logic;
        encoder_b : in std_logic;


        ----------------------------------------------------------------
        -- INTERFAZ AXI4-LITE
        ----------------------------------------------------------------

        s00_axi_aclk    : in  std_logic;
        s00_axi_aresetn : in  std_logic;

        s00_axi_awaddr  :
            in std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);

        s00_axi_awprot  :
            in std_logic_vector(2 downto 0);

        s00_axi_awvalid : in  std_logic;
        s00_axi_awready : out std_logic;

        s00_axi_wdata   :
            in std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);

        s00_axi_wstrb   :
            in std_logic_vector((C_S00_AXI_DATA_WIDTH/8)-1 downto 0);

        s00_axi_wvalid  : in  std_logic;
        s00_axi_wready  : out std_logic;

        s00_axi_bresp   : out std_logic_vector(1 downto 0);
        s00_axi_bvalid  : out std_logic;
        s00_axi_bready  : in  std_logic;

        s00_axi_araddr  :
            in std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);

        s00_axi_arprot  :
            in std_logic_vector(2 downto 0);

        s00_axi_arvalid : in  std_logic;
        s00_axi_arready : out std_logic;

        s00_axi_rdata   :
            out std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);

        s00_axi_rresp   : out std_logic_vector(1 downto 0);
        s00_axi_rvalid  : out std_logic;
        s00_axi_rready  : in  std_logic
    );

end motor_control_axi;


architecture arch_imp of motor_control_axi is


    --------------------------------------------------------------------
    -- COMPONENTE AXI4-LITE
    --------------------------------------------------------------------

    component motor_control_axi_slave_lite_v1_0_S00_AXI is

        generic (

            C_S_AXI_DATA_WIDTH : integer := 32;
            C_S_AXI_ADDR_WIDTH : integer := 6
        );

        port (

            S_AXI_ACLK    : in std_logic;
            S_AXI_ARESETN : in std_logic;

            S_AXI_AWADDR  :
                in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);

            S_AXI_AWPROT  :
                in std_logic_vector(2 downto 0);

            S_AXI_AWVALID : in  std_logic;
            S_AXI_AWREADY : out std_logic;

            S_AXI_WDATA   :
                in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);

            S_AXI_WSTRB   :
                in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);

            S_AXI_WVALID  : in  std_logic;
            S_AXI_WREADY  : out std_logic;

            S_AXI_BRESP   : out std_logic_vector(1 downto 0);
            S_AXI_BVALID  : out std_logic;
            S_AXI_BREADY  : in  std_logic;

            S_AXI_ARADDR  :
                in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);

            S_AXI_ARPROT  :
                in std_logic_vector(2 downto 0);

            S_AXI_ARVALID : in  std_logic;
            S_AXI_ARREADY : out std_logic;

            S_AXI_RDATA   :
                out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);

            S_AXI_RRESP   : out std_logic_vector(1 downto 0);
            S_AXI_RVALID  : out std_logic;
            S_AXI_RREADY  : in  std_logic;


            ------------------------------------------------------------
            -- REGISTROS DE CONFIGURACIÓN
            -- Procesador -> FPGA
            ------------------------------------------------------------

            reg_control     :
                out std_logic_vector(31 downto 0);

            reg_pwm_period  :
                out std_logic_vector(31 downto 0);

            reg_duty_manual :
                out std_logic_vector(31 downto 0);

            reg_speed_ref   :
                out std_logic_vector(31 downto 0);

            reg_kp          :
                out std_logic_vector(31 downto 0);

            reg_ki          :
                out std_logic_vector(31 downto 0);

            reg_kd          :
                out std_logic_vector(31 downto 0);

            reg_sample_time :
                out std_logic_vector(31 downto 0);


            ------------------------------------------------------------
            -- REGISTROS DE MONITORIZACIÓN
            -- FPGA -> Procesador
            ------------------------------------------------------------

            status_speed :
                in std_logic_vector(31 downto 0);

            status_error :
                in std_logic_vector(31 downto 0);

            status_duty_actual :
                in std_logic_vector(31 downto 0);

            status_encoder_count :
                in std_logic_vector(31 downto 0);

            status_system :
                in std_logic_vector(31 downto 0)
        );

    end component motor_control_axi_slave_lite_v1_0_S00_AXI;



    --------------------------------------------------------------------
    -- SEÑALES PROCEDENTES DE LOS REGISTROS AXI
    --------------------------------------------------------------------

    signal reg_control_i :
        std_logic_vector(31 downto 0);

    signal reg_pwm_period_i :
        std_logic_vector(31 downto 0);

    signal reg_duty_manual_i :
        std_logic_vector(31 downto 0);

    signal reg_speed_ref_i :
        std_logic_vector(31 downto 0);

    signal reg_kp_i :
        std_logic_vector(31 downto 0);

    signal reg_ki_i :
        std_logic_vector(31 downto 0);

    signal reg_kd_i :
        std_logic_vector(31 downto 0);

    signal reg_sample_time_i :
        std_logic_vector(31 downto 0);



    --------------------------------------------------------------------
    -- SEÑALES DEL ENCODER Y MEDIDA DE VELOCIDAD
    --------------------------------------------------------------------

    signal encoder_position_i :
        signed(31 downto 0);

    signal speed_count_i :
        signed(31 downto 0);

    signal sample_tick_i :
        std_logic;



    --------------------------------------------------------------------
    -- SEÑALES DEL CONTROLADOR PID
    --------------------------------------------------------------------

    -- Habilitación interna del PID:
    -- Enable general AND modo automático
    signal pid_enable_i :
        std_logic;

    -- Duty calculado por el PID
    signal pid_duty_i :
        std_logic_vector(31 downto 0);

    -- Error calculado por el PID
    signal pid_error_i :
        signed(31 downto 0);

    -- Pulso de finalización del cálculo PID
    signal pid_update_i :
        std_logic;

    -- Indicadores de saturación
    signal pid_saturation_high_i :
        std_logic;

    signal pid_saturation_low_i :
        std_logic;



    --------------------------------------------------------------------
    -- SELECCIÓN Y LIMITACIÓN DEL DUTY
    --------------------------------------------------------------------

    -- Duty solicitado según el modo de funcionamiento
    signal duty_command_i :
        std_logic_vector(31 downto 0);

    -- Duty finalmente aplicado al PWM
    signal duty_applied_i :
        std_logic_vector(31 downto 0);



    --------------------------------------------------------------------
    -- SEÑALES DE MONITORIZACIÓN HACIA AXI
    --------------------------------------------------------------------

    signal status_speed_i :
        std_logic_vector(31 downto 0);

    signal status_error_i :
        std_logic_vector(31 downto 0);

    signal status_duty_actual_i :
        std_logic_vector(31 downto 0);

    signal status_encoder_count_i :
        std_logic_vector(31 downto 0);

    signal status_system_i :
        std_logic_vector(31 downto 0);



begin


    --------------------------------------------------------------------
    -- INSTANCIA DEL ESCLAVO AXI4-LITE
    --------------------------------------------------------------------

    motor_control_axi_slave_lite_v1_0_S00_AXI_inst :
        motor_control_axi_slave_lite_v1_0_S00_AXI

        generic map (

            C_S_AXI_DATA_WIDTH =>
                C_S00_AXI_DATA_WIDTH,

            C_S_AXI_ADDR_WIDTH =>
                C_S00_AXI_ADDR_WIDTH
        )

        port map (

            S_AXI_ACLK    => s00_axi_aclk,
            S_AXI_ARESETN => s00_axi_aresetn,

            S_AXI_AWADDR  => s00_axi_awaddr,
            S_AXI_AWPROT  => s00_axi_awprot,
            S_AXI_AWVALID => s00_axi_awvalid,
            S_AXI_AWREADY => s00_axi_awready,

            S_AXI_WDATA   => s00_axi_wdata,
            S_AXI_WSTRB   => s00_axi_wstrb,
            S_AXI_WVALID  => s00_axi_wvalid,
            S_AXI_WREADY  => s00_axi_wready,

            S_AXI_BRESP   => s00_axi_bresp,
            S_AXI_BVALID  => s00_axi_bvalid,
            S_AXI_BREADY  => s00_axi_bready,

            S_AXI_ARADDR  => s00_axi_araddr,
            S_AXI_ARPROT  => s00_axi_arprot,
            S_AXI_ARVALID => s00_axi_arvalid,
            S_AXI_ARREADY => s00_axi_arready,

            S_AXI_RDATA   => s00_axi_rdata,
            S_AXI_RRESP   => s00_axi_rresp,
            S_AXI_RVALID  => s00_axi_rvalid,
            S_AXI_RREADY  => s00_axi_rready,


            ------------------------------------------------------------
            -- Configuración
            ------------------------------------------------------------

            reg_control     => reg_control_i,
            reg_pwm_period  => reg_pwm_period_i,
            reg_duty_manual => reg_duty_manual_i,
            reg_speed_ref   => reg_speed_ref_i,

            reg_kp          => reg_kp_i,
            reg_ki          => reg_ki_i,
            reg_kd          => reg_kd_i,

            reg_sample_time => reg_sample_time_i,


            ------------------------------------------------------------
            -- Monitorización
            ------------------------------------------------------------

            status_speed =>
                status_speed_i,

            status_error =>
                status_error_i,

            status_duty_actual =>
                status_duty_actual_i,

            status_encoder_count =>
                status_encoder_count_i,

            status_system =>
                status_system_i
        );



    --------------------------------------------------------------------
    -- DECODIFICADOR DEL ENCODER EN CUADRATURA
    --------------------------------------------------------------------

    quadrature_encoder_inst :
        entity work.quadrature_encoder

        port map (

            clk =>
                s00_axi_aclk,

            resetn =>
                s00_axi_aresetn,

            encoder_a =>
                encoder_a,

            encoder_b =>
                encoder_b,

            position_count =>
                encoder_position_i
        );



    --------------------------------------------------------------------
    -- MEDICIÓN DE VELOCIDAD
    --------------------------------------------------------------------

    speed_measurement_inst :
        entity work.speed_measurement

        port map (

            clk =>
                s00_axi_aclk,

            resetn =>
                s00_axi_aresetn,

            enable =>
                reg_control_i(0),

            position_count =>
                encoder_position_i,

            sample_period_count =>
                reg_sample_time_i,

            speed_count =>
                speed_count_i,

            sample_tick =>
                sample_tick_i
        );



    --------------------------------------------------------------------
    -- HABILITACIÓN DEL PID
    --------------------------------------------------------------------

    -- CONTROL[0] = Enable
    -- CONTROL[2] = modo automático

    pid_enable_i <=
        reg_control_i(0) and reg_control_i(2);



    --------------------------------------------------------------------
    -- CONTROLADOR PID
    --------------------------------------------------------------------

    pid_controller_inst :
        entity work.pid_controller

        port map (

            clk =>
                s00_axi_aclk,

            resetn =>
                s00_axi_aresetn,

            enable =>
                pid_enable_i,

            sample_tick =>
                sample_tick_i,

            reset_pid =>
                reg_control_i(3),

            speed_ref =>
                reg_speed_ref_i,

            speed_measured =>
                speed_count_i,

            kp =>
                reg_kp_i,

            ki =>
                reg_ki_i,

            kd =>
                reg_kd_i,

            pwm_period =>
                reg_pwm_period_i,

            duty_out =>
                pid_duty_i,

            error_out =>
                pid_error_i,

            pid_update =>
                pid_update_i,

            saturation_high =>
                pid_saturation_high_i,

            saturation_low =>
                pid_saturation_low_i
        );



    --------------------------------------------------------------------
    -- SELECCIÓN MANUAL / AUTOMÁTICO
    --------------------------------------------------------------------

    -- CONTROL[2] = 0 -> Duty manual
    -- CONTROL[2] = 1 -> Duty calculado por PID

    duty_command_i <=
        reg_duty_manual_i
        when reg_control_i(2) = '0'
        else pid_duty_i;



    --------------------------------------------------------------------
    -- LIMITACIÓN FINAL DEL DUTY
    --------------------------------------------------------------------

    -- Motor deshabilitado:
    -- duty aplicado = 0

    -- Si se solicita un duty mayor que el periodo:
    -- se limita al 100 %.

    duty_applied_i <=

        (others => '0')

        when reg_control_i(0) = '0'

        else reg_pwm_period_i

        when unsigned(duty_command_i) >
             unsigned(reg_pwm_period_i)

        else duty_command_i;



    --------------------------------------------------------------------
    -- GENERADOR PWM
    --------------------------------------------------------------------

    pwm_generator_inst :
        entity work.pwm_generator

        port map (

            clk =>
                s00_axi_aclk,

            resetn =>
                s00_axi_aresetn,

            enable =>
                reg_control_i(0),

            period_count =>
                reg_pwm_period_i,

            duty_count =>
                duty_applied_i,

            pwm_out =>
                pwm_out
        );



    --------------------------------------------------------------------
    -- CONTROL DEL SENTIDO DE GIRO
    --------------------------------------------------------------------

    -- CONTROL[0] = Enable
    -- CONTROL[1] = Dirección

    motor_in1 <=
        '1'
        when (
            reg_control_i(0) = '1' and
            reg_control_i(1) = '0'
        )
        else '0';


    motor_in2 <=
        '1'
        when (
            reg_control_i(0) = '1' and
            reg_control_i(1) = '1'
        )
        else '0';



    --------------------------------------------------------------------
    -- REGISTROS DE MONITORIZACIÓN
    --------------------------------------------------------------------

    -- Velocidad medida
    status_speed_i <=
        std_logic_vector(speed_count_i);


    -- Error del PID.
    -- En modo manual se devuelve cero.
    status_error_i <=
        std_logic_vector(pid_error_i)
        when reg_control_i(2) = '1'
        else (others => '0');


    -- Duty realmente aplicado al PWM
    status_duty_actual_i <=
        duty_applied_i;


    -- Posición acumulada del encoder
    status_encoder_count_i <=
        std_logic_vector(encoder_position_i);



    --------------------------------------------------------------------
    -- REGISTRO DE ESTADO
    --------------------------------------------------------------------

    -- bit 0 = Enable
    -- bit 1 = Dirección
    -- bit 2 = Modo
    -- bit 3 = Reset PID
    -- bit 4 = Saturación superior
    -- bit 5 = Saturación inferior
    -- bits 31..6 = reservados

    status_system_i <=

        (31 downto 6 => '0') &

        pid_saturation_low_i &
        pid_saturation_high_i &

        reg_control_i(3) &
        reg_control_i(2) &
        reg_control_i(1) &
        reg_control_i(0);


end arch_imp;