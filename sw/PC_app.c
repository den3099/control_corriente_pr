#include <stdio.h>
//#include "platform.h"
#include "xil_printf.h"
#include "xil_exception.h"
#include "xparameters.h"
#include "xintc.h"
#include "xtmrctr.h"
#include "xparameters.h"

// MAPA DE MEMORIA
#define GPIO_BASE_ADDR   0x40000000
#define ADC_BASE_ADDR    0x44A10000
#define PWM_BASE_ADDR    0x80000000
#define UART_BASE_ADDR   0x40600000

/* Timer e INTC se manejan con los drivers de Xilinx; sus IDs salen de
 * xparameters.h [AJUSTAR]                                                 */
#define TMR_DEVICE_ID    0
#define INTC_DEVICE_ID   0
#define TMR_INTR_ID      0            /* numero de interrupcion en el INTC */

// INDICES DE REGISTROS
#define PWM_CTRL_IDX     0
#define PWM_DUTY_IDX     1
#define PWM_EN_BIT       0x1
#define PWM_FSEL_SHIFT   1
#define PWM_FSEL_MASK    0x6
#define PWM_RUN_BIT      0x8

// ADC [VERIFICAR: supuesto, adaptar al mapa de registros de tu IP] */
#define ADC_CTRL_IDX     0            /* offset 0x00: bit0 = start     */
#define ADC_STAT_IDX     1            /* offset 0x04: bit0 = data_valid */
#define ADC_DATA_IDX     2            /* offset 0x08: dato              */

// GPIO
#define GPIO_DATA_IDX      0
#define GPIO_TRI_IDX       1
#define GPIO_LED_DATA_IDX  2
#define GPIO_LED_TRI_IDX   3
#define GPIO_CONFIG_TRI    0

// UART
#define UART_RX_IDX      0
#define UART_TX_IDX      1
#define UART_STAT_IDX    2
#define UART_CTRL_IDX    3
#define UART_RST_TX      0x01
#define UART_RST_RX      0x02
#define UART_RX_VALID    0x01

// VALORES INICIALES Y PARAMETROS
#define CPU_HZ           100000000

// PWM
#define NUM_FSW          3
static const int FSW_HZ[NUM_FSW] = {5000, 10000, 20000};
#define PWM_FSEL_INIT    1
#define PWM_ENABLE_INIT  0
#define PWM_DUTY_INIT    0
#define PWM_RUN_TIMEOUT  1000

#define PR_DESIGN_FSW_IDX 1

#define DUTY_FULL_SCALE  32768.0f
#define DUTY_MAX         29491
#define DUTY_MIN        (-29491)

// ADC / XADC
#define ADC_STATUS_OFFSET  0x04
#define ADC_AUX3_OFFSET    0x24C
#define ADC_EOS_MASK       0x80
#define ADC_DATA_MASK      0xFFF0

#define ADC_TIMEOUT        2000
#define ADC_OFFSET_CNT     8
#define ADC_A_PER_CNT      0.125f

// Controlador PR
#define VDC              24.0f
#define R_LOAD_OHM       4.7f
#define L_LOAD_H         0.0253f
#define PR_FC_HZ         300.0f

#define PR_B0            0.049966796f
#define PR_B2           (-0.049966796f)
#define PR_A1           (-1.998014278f)
#define PR_A2            0.999000664f
#define PR_UMAX          0.9f

// Referencia y proteccion
#define F_REF_HZ         50
#define SINE_MAX         400
static const float AMPL_A[3] = {0.2f, 0.5f, 1.0f};
#define AMPL_INIT_IDX    0
#define AMPL_CHANGE_AT_PEAK 1
#define I_LIMIT_A        1.5f

// Temporizacion
#define NS_PER_CYCLE     (1000000000 / CPU_HZ)
#define TIMER_ALIGN_CYCLES 500

// LED de estado
#define SYS_INIT         0
#define SYS_WORK         1
#define SYS_FAULT        2
#define LED_OFF          0x0
#define LED_ST_INIT      0x1
#define LED_ST_WORK      0x2
#define LED_ST_FAULT     0x4
#define AUTO_START       1

// Botones
#define BTN_MASK         0xF
#define BTN_EXPORT       0x1          /* BTN0: exportar muestras            */
#define BTN_ENABLE       0x2          /* BTN1: iniciar/detener control      */
#define BTN_AMPL         0x4          /* BTN2: ciclar amplitud              */
#define BTN_FSW          0x8          /* BTN3: ciclar frecuencia            */

// Buffer circular
#define LOG_LEN          256

// Codigos de retorno de la inicializacion
#define INIT_OK          0
#define INIT_ERR_PWM    -1
#define INIT_ERR_ADC    -2
#define INIT_ERR_BTN    -3
#define INIT_ERR_UART   -4
#define INIT_ERR_IRQ    -5

// PUNTEROS
static volatile int * gpio_base = (volatile int *) GPIO_BASE_ADDR;
static volatile int * adc_base  = (volatile int *) ADC_BASE_ADDR;
static volatile int * pwm_base  = (volatile int *) PWM_BASE_ADDR;
static volatile int * uart_base = (volatile int *) UART_BASE_ADDR;

static XTmrCtr tmr;
static XIntc   intc;

static volatile int sys_state   = SYS_INIT;
static volatile int fsw_idx     = PWM_FSEL_INIT;
static volatile int ampl_idx    = AMPL_INIT_IDX;
static volatile int ampl_pending = -1;
static volatile int pr_enabled  = 0;

#define SINE_QUARTER_LEN (SINE_MAX / 4) 
static int16_t sine_lut[SINE_QUARTER_LEN + 1];
static int   sine_len = 200;
static int   sine_idx = 0;

static int16_t log_mA[LOG_LEN];
static volatile int log_head   = 0;
static volatile int log_count  = 0;
static volatile int log_frozen = 0;

// Botones
static int btn_prev = 0;
static int btn_last = 0;
static int btn_t_change = 0;
static volatile int isr_ticks = 0;
static int debounce_ticks = 0;

static volatile int ts_ticks     = 0;
static volatile int timing_valid = 0;
static unsigned int t_last       = 0;
static volatile int dev_min      = 0;
static volatile int dev_max      = 0;
static volatile int dev_sum      = 0;
static volatile int stat_n       = 0;
static volatile int isr_max      = 0;

// CONTROLADOR PR DISCRETO
static float pr_kp = 0.0f;
static float pr_e1 = 0.0f, pr_e2 = 0.0f;       // e[k-1], e[k-2]
static float pr_y1 = 0.0f, pr_y2 = 0.0f;       // yr[k-1], yr[k-2]


// Kp = sqrt(R^2 + (2*pi*fc*L)^2)
static void pr_design(void)
{
    float x = 2.0f * 3.14159265f * PR_FC_HZ * L_LOAD_H;
    float radicand = R_LOAD_OHM * R_LOAD_OHM + x * x;
    float root;
    int i;

    /* Newton-Raphson: aproxima sqrt(radicand) sin biblioteca matematica. */
    root = (radicand > 1.0f) ? (radicand * 0.1f) : 1.0f;
    for (i = 0; i < 8; i++)
        root = 0.5f * (root + radicand / root);

    pr_kp = root / VDC;
}

// Estados en cero
static void pr_reset(void)
{
    pr_e1 = pr_e2 = 0.0f;
    pr_y1 = pr_y2 = 0.0f;
}

static int pr_step(float iref, float imeas)
{
    float e  = iref - imeas;
    float yr = PR_B0 * e + PR_B2 * pr_e2 - PR_A1 * pr_y1 - PR_A2 * pr_y2;
    float u  = pr_kp * e + yr;
    float d;

    pr_e2 = pr_e1;  pr_e1 = e;
    pr_y2 = pr_y1;  pr_y1 = yr;

    if (u >  PR_UMAX) u =  PR_UMAX;
    if (u < -PR_UMAX) u = -PR_UMAX;

    d = u * DUTY_FULL_SCALE;
    return (int)(d >= 0.0f ? d + 0.5f : d - 0.5f);
}

// FUNCIONES
static void leds_write(int value)
{
    gpio_base[GPIO_LED_DATA_IDX] = value;
}

static void leds_show(int state)
{
    if (state == SYS_WORK)       leds_write(LED_ST_WORK);
    else if (state == SYS_FAULT) leds_write(LED_ST_FAULT);
    else                         leds_write(LED_ST_INIT);
}

static void pwm_write_duty(int duty)
{
    if (duty > DUTY_MAX) duty = DUTY_MAX;
    if (duty < DUTY_MIN) duty = DUTY_MIN;
    pwm_base[PWM_DUTY_IDX] = duty & 0xFFFF;
}

static void pwm_disable(void)
{
    pwm_base[PWM_DUTY_IDX] = 0;
    pwm_base[PWM_CTRL_IDX] = (fsw_idx << PWM_FSEL_SHIFT);
}

static int adc_read(int *raw)
{
    int n;
    int status;
    int data;

    for (n = 0; n < ADC_TIMEOUT; n++) {

        status = adc_base[ADC_STATUS_OFFSET / 4];

        if (status & ADC_EOS_MASK) {

            data = adc_base[ADC_AUX3_OFFSET / 4];

            *raw = (data & ADC_DATA_MASK) >> 4;

            return 1;
        }
    }

    return 0;
}

static void delay_cycles(unsigned int cycles)
{
    unsigned int t = XTmrCtr_GetValue(&tmr, 1);
    while ((XTmrCtr_GetValue(&tmr, 1) - t) < cycles) { }
}

static void fault_trip(void)
{
    pwm_disable();
    pr_reset();
    sys_state = SYS_FAULT;
    leds_show(SYS_FAULT);
}

static void timing_reset(void)
{
    timing_valid = 0;
    dev_min  = 0x7FFFFFFF;
    dev_max  = -0x7FFFFFFF;
    dev_sum  = 0;
    stat_n   = 0;
    isr_max  = 0;
}

static void sine_build(int len)
{
    int i;
    int quarter;

    if (len > SINE_MAX) len = SINE_MAX;
    if (len < 4) len = 4;

    quarter = len / 4;
    for (i = 0; i <= quarter; i++) {
        float x = (float)i / (2.0f * (float)quarter);
        float product = x * (1.0f - x);
        float value = (16.0f * product) / (5.0f - 4.0f * product);

        if (value > 1.0f) value = 1.0f;
        sine_lut[i] = (int16_t)(value * 32767.0f + 0.5f);
    }

    sine_len = len;
    sine_idx = 0;
}

static float sine_get(int idx)
{
    int quarter = sine_len / 4;
    int16_t sample;

    if (idx < quarter)
        sample = sine_lut[idx];
    else if (idx < 2 * quarter)
        sample = sine_lut[2 * quarter - idx];
    else if (idx < 3 * quarter)
        sample = (int16_t)(-sine_lut[idx - 2 * quarter]);
    else
        sample = (int16_t)(-sine_lut[4 * quarter - idx]);

    return (float)sample / 32767.0f;
}

// ISR DEL LAZO DE CONTROL
static void control_isr(void *ref, u8 tmr_num)
{
    float meas_A, ref_A;
    int raw, duty, dev, dur;
    unsigned int t0;

    (void) ref; (void) tmr_num;
    t0 = XTmrCtr_GetValue(&tmr, 1);
    isr_ticks++;
    if (sys_state != SYS_WORK) { timing_valid = 0; return; }

    if (timing_valid) {
        dev = (int)(t0 - t_last) - ts_ticks;
        if (dev < dev_min) dev_min = dev;
        if (dev > dev_max) dev_max = dev;
        dev_sum += dev;
        stat_n++;
    }
    timing_valid = 1;
    t_last = t0;

    if (!adc_read(&raw)) { fault_trip(); return; }

    meas_A = (float)(raw - ADC_OFFSET_CNT) * ADC_A_PER_CNT;

    if (meas_A > I_LIMIT_A || meas_A < -I_LIMIT_A) { fault_trip(); return; }

#if AMPL_CHANGE_AT_PEAK
    if (ampl_pending >= 0 && sine_idx == sine_len / 4) {
        ampl_idx = ampl_pending;
        ampl_pending = -1;
    }
#endif
    ref_A = AMPL_A[ampl_idx] * sine_get(sine_idx);
    sine_idx++;
    if (sine_idx >= sine_len) sine_idx = 0;

    if (pr_enabled) duty = pr_step(ref_A, meas_A);
    else            duty = 0;
    pwm_write_duty(duty);

    if (!log_frozen) {
        log_mA[log_head] = (int)(meas_A * 1000.0f);
        log_head = (log_head + 1) & (LOG_LEN - 1);
        if (log_count < LOG_LEN) log_count++;
    }

    dur = (int)(XTmrCtr_GetValue(&tmr, 1) - t0);
    if (dur > isr_max) isr_max = dur;
}

// CONTROL
static void control_stop(void)
{
    sys_state = SYS_INIT;
    pwm_disable();
    pr_reset();
    leds_show(SYS_INIT);
}

static void control_start(void)
{
    int n;

    pr_reset();
    timing_reset();
    sine_idx = 0;
    ampl_pending = -1;
    pwm_write_duty(PWM_DUTY_INIT);

    XTmrCtr_Stop(&tmr, 0);
    pwm_base[PWM_CTRL_IDX] = (fsw_idx << PWM_FSEL_SHIFT) | PWM_EN_BIT;

    for (n = 0; n < PWM_RUN_TIMEOUT; n++)
        if (pwm_base[PWM_CTRL_IDX] & PWM_RUN_BIT) break;
    if (n == PWM_RUN_TIMEOUT) {
        XTmrCtr_Start(&tmr, 0);
        fault_trip();
        return;
    }

    delay_cycles(TIMER_ALIGN_CYCLES);
    sys_state = SYS_WORK;
    leds_show(SYS_WORK);
    XTmrCtr_Start(&tmr, 0);

    if (!pr_enabled)
        xil_printf("Aviso: el PR esta disenado solo para fsw=%d Hz; PWM con duty=0\r\n",
                   FSW_HZ[PR_DESIGN_FSW_IDX]);
}

static void control_reconfigure(int idx)
{
    sys_state = SYS_INIT;
    XTmrCtr_Stop(&tmr, 0);

    fsw_idx = idx;
    pwm_disable();

    ts_ticks = CPU_HZ / FSW_HZ[idx];
    XTmrCtr_SetResetValue(&tmr, 0, ts_ticks);
    sine_build(FSW_HZ[idx] / F_REF_HZ);
    pr_enabled = (idx == PR_DESIGN_FSW_IDX);
    debounce_ticks = FSW_HZ[idx] / 50;
    pr_reset();
    timing_reset();

    XTmrCtr_Start(&tmr, 0);
    leds_show(SYS_INIT);
}

// INICIALIZACION
static int pwm_init(void)
{
    int ctrl;
    pwm_base[PWM_DUTY_IDX] = PWM_DUTY_INIT;
    pwm_base[PWM_CTRL_IDX] = (PWM_FSEL_INIT << PWM_FSEL_SHIFT)
                           | (PWM_ENABLE_INIT ? PWM_EN_BIT : 0);
    ctrl = pwm_base[PWM_CTRL_IDX];
    if (ctrl & PWM_EN_BIT)  return INIT_ERR_PWM;
    if (ctrl & PWM_RUN_BIT) return INIT_ERR_PWM;
    if (((ctrl & PWM_FSEL_MASK) >> PWM_FSEL_SHIFT) != PWM_FSEL_INIT)
        return INIT_ERR_PWM;
    return INIT_OK;
}

static void leds_init(void)
{
#if GPIO_CONFIG_TRI
    gpio_base[GPIO_LED_TRI_IDX] = 0x0;
#endif
    leds_write(LED_OFF);
    leds_show(SYS_INIT);
}

static int adc_init(void)
{
    volatile int status;

    // Comprobar acceso al registro de estado del XADC
    status = adc_base[ADC_STATUS_OFFSET / 4];

    (void)status;

    return INIT_OK;
}

static int buttons_init(void)
{
#if GPIO_CONFIG_TRI
    gpio_base[GPIO_TRI_IDX] = BTN_MASK;
#endif
    btn_prev = btn_last = gpio_base[GPIO_DATA_IDX] & BTN_MASK;
    if (btn_prev != 0) return INIT_ERR_BTN;
    return INIT_OK;
}

static int uart_init(void)
{
    uart_base[UART_CTRL_IDX] = UART_RST_TX | UART_RST_RX;
    if (uart_base[UART_STAT_IDX] & UART_RX_VALID) return INIT_ERR_UART;
    return INIT_OK;
}

static int interrupts_init(void)
{
    int st;

    st = XTmrCtr_Initialize(&tmr, TMR_DEVICE_ID);
    if (st != XST_SUCCESS) return INIT_ERR_IRQ;
    XTmrCtr_SetOptions(&tmr, 0, XTC_INT_MODE_OPTION | XTC_AUTO_RELOAD_OPTION
                                | XTC_DOWN_COUNT_OPTION);
    XTmrCtr_SetHandler(&tmr, control_isr, &tmr);

    XTmrCtr_SetOptions(&tmr, 1, 0);
    XTmrCtr_SetResetValue(&tmr, 1, 0);
    XTmrCtr_Start(&tmr, 1);

    st = XIntc_Initialize(&intc, INTC_DEVICE_ID);
    if (st != XST_SUCCESS) return INIT_ERR_IRQ;
    st = XIntc_Connect(&intc, TMR_INTR_ID,
                       (XInterruptHandler) XTmrCtr_InterruptHandler, &tmr);
    if (st != XST_SUCCESS) return INIT_ERR_IRQ;
    st = XIntc_Start(&intc, XIN_REAL_MODE);
    if (st != XST_SUCCESS) return INIT_ERR_IRQ;
    XIntc_Enable(&intc, TMR_INTR_ID);

    Xil_ExceptionInit();
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
                                 (Xil_ExceptionHandler) XIntc_InterruptHandler,
                                 &intc);
    Xil_ExceptionEnable();
    return INIT_OK;
}

static int system_init(void)
{
    int st;
    st = pwm_init();        if (st != INIT_OK) return st;
    leds_init();
    st = adc_init();        if (st != INIT_OK) return st;
    st = buttons_init();    if (st != INIT_OK) return st;
    st = uart_init();       if (st != INIT_OK) return st;
    pr_design();
    pr_reset();
    st = interrupts_init(); if (st != INIT_OK) return st;
    return INIT_OK;
}

static int buttons_poll(void)
{
    int raw = gpio_base[GPIO_DATA_IDX] & BTN_MASK;
    int edges = 0;

    if (raw != btn_last) {
        btn_last = raw;
        btn_t_change = isr_ticks;
    } else if ((isr_ticks - btn_t_change) >= debounce_ticks && raw != btn_prev) {
        edges = raw & ~btn_prev;
        btn_prev = raw;
    }
    return edges;
}

static void print_timing(void)
{
    int n = stat_n;
    int avg, jit;

    xil_printf("--- TEMPORIZACION DEL LAZO ---\r\n");
    if (n < 1) {
        xil_printf("Sin datos (el control no ha corrido)\r\n");
        return;
    }
    avg = ts_ticks + dev_sum / n;
    jit = dev_max - dev_min;
    xil_printf("Ts nominal   = %d ciclos (%d ns)\r\n", ts_ticks, ts_ticks * NS_PER_CYCLE);
    xil_printf("Periodos     = %d\r\n", n);
    xil_printf("Periodo medio= %d ciclos (%d ns)\r\n", avg, avg * NS_PER_CYCLE);
    xil_printf("Desviacion   = min %d, max %d ciclos\r\n", dev_min, dev_max);
    xil_printf("Jitter p-p   = %d ciclos (%d ns)\r\n", jit, jit * NS_PER_CYCLE);
    xil_printf("ISR (peor)   = %d ciclos (%d ns) = %d %% de Ts\r\n",
               isr_max, isr_max * NS_PER_CYCLE, (isr_max * 100) / ts_ticks);
    if (isr_max + TIMER_ALIGN_CYCLES >= ts_ticks)
        xil_printf("ATENCION: la ISR no termina antes del siguiente valle\r\n");
}

static void export_samples(void)
{
    int n, start, k;

    log_frozen = 1;
    n = log_count;
    start = (log_head - n) & (LOG_LEN - 1);

    xil_printf("\r\n--- MUESTRAS DE CORRIENTE [mA] ---\r\n");
    xil_printf("fsw=%d Hz, Ts=%d us, N=%d, Iref_pico=%d mA\r\n",
               FSW_HZ[fsw_idx], 1000000 / FSW_HZ[fsw_idx], n,
               (int)(AMPL_A[ampl_idx] * 1000.0f));
    for (k = 0; k < n; k++)
        xil_printf("%d,%d\r\n", k, log_mA[(start + k) & (LOG_LEN - 1)]);
    xil_printf("--- FIN ---\r\n");
    print_timing();

    log_head = 0;  log_count = 0;               /* nuevo historico */
    log_frozen = 0;
}

// MAIN
int main()
{
    int st, ev, next;

    //init_platform();

    st = system_init();
    if (st != INIT_OK) {
        fault_trip();
        xil_printf("ERROR de inicializacion, codigo = %d\r\n", st);
        while (1) { }
    }

    control_reconfigure(PWM_FSEL_INIT);
    xil_printf("Inicializacion OK. fsw=%d Hz, muestras/periodo=%d\r\n",
               FSW_HZ[fsw_idx], sine_len);
    xil_printf("Kp = %d x1e-6 (esperado 1996684 con R=4.7, L=25.3 mH)\r\n",
               (int)(pr_kp * 1000000.0f));
    xil_printf("BTN0=exportar BTN1=iniciar/detener BTN2=amplitud BTN3=fsw\r\n");

#if AUTO_START
    control_start();
#endif

    while (1) {
        ev = buttons_poll();

        if (ev & BTN_ENABLE) {
            if (sys_state == SYS_WORK) control_stop();
            else                       control_start();
        }
        if (ev & BTN_AMPL) {
            next = ((ampl_pending >= 0 ? ampl_pending : ampl_idx) + 1) % 3;
#if AMPL_CHANGE_AT_PEAK
            if (sys_state == SYS_WORK) ampl_pending = next;
            else                       ampl_idx = next;
#else
            ampl_idx = next;
#endif
        }
        if (ev & BTN_FSW)  control_reconfigure((fsw_idx + 1) % NUM_FSW);
        if (ev & BTN_EXPORT) export_samples();
    }

    //cleanup_platform();
    return 0;
}