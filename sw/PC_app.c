#include <stdint.h>
#include "xparameters.h"
#include "xil_exception.h"
#include "xintc.h"
#include "xtmrctr.h"

/* 1 = lazo PR habilitable mediante BTN1; inicio NO es automatico.
 * Para pruebas sin etapa de potencia, usar 0U.
 */
#define HABILITAR_POTENCIA      1U

#define GPIO_BASE              XPAR_XGPIO_0_BASEADDR
#define UART_BASE              XPAR_XUARTLITE_0_BASEADDR
#define TIMER_BASE             XPAR_XTMRCTR_0_BASEADDR
#define INTC_BASE              XPAR_XINTC_0_BASEADDR
#define XADC_BASE              XPAR_XSYSMON_0_BASEADDR
#define PWM_BASE               XPAR_PWM_CONTROLLER_0_BASEADDR
#define CPU_HZ                 XPAR_MICROBLAZE_RISCV_FREQ
#define RAM_LOCAL_BYTES        (XPAR_LMB_BRAM_0_HIGHADDRESS - XPAR_LMB_BRAM_0_BASEADDRESS + 1U)

#if RAM_LOCAL_BYTES != 32768U
#error "Se requieren 32 KiB de memoria local segun el proyecto"
#endif

#ifdef SDT
#define TIMER_ID               TIMER_BASE
#define INTC_ID                INTC_BASE
#else
#define TIMER_ID               XPAR_AXI_TIMER_0_DEVICE_ID
#define INTC_ID                XPAR_MICROBLAZE_RISCV_0_AXI_INTC_DEVICE_ID
#endif

/* Registros PWM: control +0x00, duty firmado Q1.15 +0x04. */
#define PWM_CTRL               0U
#define PWM_DUTY               1U
#define PWM_EN                 1U
#define PWM_RUNNING            0x08U
#define PWM_FSEL_SHIFT         1U
#define DUTY_MAX_Q15           29491L       /* modulacion maxima +/-0.90 */

/* XADC Wizard, VAUX3; registro de datos desplaza 4 bits. */
#define XADC_SR                (0x04U / 4U)
#define XADC_CONVST            (0x0CU / 4U)
#define XADC_VAUX3             (0x24CU / 4U)
#define XADC_EOC               0x20U
#define XADC_CHANNEL_MASK      0x1FU
#define XADC_CHANNEL_VAUX3     0x13U

/* Calibracion nominal y restricciones sobre la senal ANALOGICA. */
#define ADC_CERO               2048L
#define ADC_NUM_MA             625L
#define ADC_DEN_MA             1152L
#define ADC_RAW_MIN            207U         /* ~0.0505 V */
#define ADC_RAW_MAX            3891U        /* ~0.9500 V */
#define ADC_CERO_TOL           96U          /* ~50 mA alrededor del cero */
#define ADC_RANGO_REPOSO       40U          /* dispersion maxima en 8 muestras */
#define CORRIENTE_MAX_MA       1000L

/* AXI UART Lite, 9600 8N1; comunicacion solo bajo peticion por botones. */
#define UART_TX                1U           /* +0x04 */
#define UART_SR                2U           /* +0x08 */
#define UART_TX_FULL           0x08U

/* Canal 1: botones; canal 2: 16 LEDs. */
#define BTN_EXPORT             0x01U
#define BTN_START              0x02U
#define BTN_AMP                0x04U
#define BTN_FREQ               0x08U
#define BTN_MASK               0x1FU
#define LED_LISTO              0x01U
#define LED_MARCHA             0x02U
#define LED_FALLA              0x04U

#define PARADO                  0U
#define ACTIVO                  1U
#define FALLA                   2U
#define ERR_ADC                 1U
#define ERR_SOBRECORRIENTE      2U
#define ERR_PWM                 3U
#define ERR_TIEMPO_ISR          4U
#define ERR_TIMER               5U

/* Regulador PR: Kp=1.996684, Kr=100, wc=5 rad/s, 50 Hz.
 * Coeficientes Q20 discretizados de forma independiente para cada fsw.
 */
#define Q20                     1048576LL
#define KP_Q20                  2093675LL
#define ESTADO_ESCALA           256L
#define ESTADO_LIM              (8000L * ESTADO_ESCALA)
#define U_ESTADO_LIM            (900L * ESTADO_ESCALA)
#define HIST_N                  1024U

static volatile uint32_t *const gpio = (volatile uint32_t *)GPIO_BASE;
static volatile uint32_t *const uart = (volatile uint32_t *)UART_BASE;
static volatile uint32_t *const xadc = (volatile uint32_t *)XADC_BASE;
static volatile uint32_t *const pwm  = (volatile uint32_t *)PWM_BASE;

static XTmrCtr timer;
static XIntc intc;
static const uint16_t fsw[3] = {5000, 10000, 20000};
static const uint16_t fase_paso[3] = {4, 2, 1};
static const int16_t amplitud_mA[3] = {200, 500, 1000};
static const int32_t b0_q20[3] = {104684, 52394, 26207};
static const int32_t a1_q20[3] = {-2090924, -2095070, -2096369};
static const int32_t a2_q20[3] = {1046482, 1047528, 1048052};

/* Cuarto de seno, Q15, fase de 0..399 (400 pasos/ciclo). */
static const int16_t seno_q15[101] = {
       0,   515,  1029,  1544,  2057,  2571,  3084,  3596,  4107,  4617,
    5126,  5634,  6140,  6645,  7148,  7649,  8149,  8646,  9142,  9635,
   10126, 10614, 11099, 11582, 12062, 12539, 13013, 13484, 13952, 14415,
   14876, 15333, 15786, 16235, 16680, 17121, 17557, 17990, 18418, 18841,
   19260, 19674, 20083, 20487, 20886, 21280, 21669, 22053, 22431, 22803,
   23170, 23531, 23886, 24235, 24579, 24916, 25247, 25572, 25891, 26203,
   26509, 26808, 27101, 27387, 27666, 27938, 28204, 28462, 28714, 28958,
   29196, 29426, 29648, 29864, 30072, 30273, 30466, 30652, 30830, 31000,
   31163, 31318, 31466, 31606, 31738, 31862, 31978, 32086, 32187, 32279,
   32364, 32440, 32509, 32569, 32622, 32666, 32702, 32731, 32751, 32763,
   32767
};

/* Datos indispensables para el control y el historial. */
static int16_t hist_ref[HIST_N];
static int16_t hist_i[HIST_N];
static volatile uint16_t hist_pos = 0U, hist_total = 0U;
static volatile uint32_t estado = PARADO, causa = 0U;
static volatile uint32_t interrupciones = 0U;
static volatile uint32_t modo_f = 1U, modo_amp = 0U;
static volatile uint32_t pendiente_amp = 3U; /* 3 = sin cambio pendiente */
static volatile uint32_t rampa_mA = 0U;
static uint32_t rampa_ciclos = 0U;
static uint32_t periodo_ciclos = 10000U;
static uint32_t ultimo_inicio_isr = 0U;
static uint16_t fase = 0U;
static int32_t b0 = 52394, a1 = -2095070, a2 = 1047528;
static int32_t e1 = 0, e2 = 0, y1 = 0, y2 = 0;
static uint8_t hist_salto = 0U;

static void pwm_apagar(void)
{
    pwm[PWM_CTRL] = modo_f << PWM_FSEL_SHIFT;
    pwm[PWM_DUTY] = 0U;
}

static void pr_reiniciar(void)
{
    e1 = e2 = y1 = y2 = 0;
    fase = 0U;
    rampa_mA = 0U;
    rampa_ciclos = 0U;
    pendiente_amp = 3U;
}

static void falla(uint32_t codigo)
{
    pwm_apagar();
    estado = FALLA;
    causa = codigo;
    gpio[2] = LED_FALLA;
}

/* UART: si FIFO se llena, abandonar por timeout en vez de congelar main. */
static int uart_char(char c)
{
    uint32_t t0 = XTmrCtr_GetValue(&timer, 1);
    while ((uart[UART_SR] & UART_TX_FULL) != 0U) {
        if ((uint32_t)(XTmrCtr_GetValue(&timer, 1) - t0) > CPU_HZ / 20U)
            return 0;
    }
    uart[UART_TX] = (uint32_t)(uint8_t)c;
    return 1;
}

static void uart_texto(const char *s)
{
    while (*s != '\0') {
        if (!uart_char(*s++)) return;
    }
}

static void uart_u32(uint32_t n)
{
    char digitos[10];
    uint32_t i = 0U;
    do {
        digitos[i++] = (char)('0' + (n % 10U));
        n /= 10U;
    } while (n != 0U);
    while (i != 0U) {
        if (!uart_char(digitos[--i])) return;
    }
}

static void uart_i32(int32_t n)
{
    if (n < 0) {
        uart_texto("-");
        uart_u32((uint32_t)(-(int64_t)n));
    } else {
        uart_u32((uint32_t)n);
    }
}

/* El registro de estado SR entrega EOC y CHANNEL de VAUX3. */
static int adc_esperar(uint16_t *dato, uint32_t timeout_ciclos)
{
    uint32_t t0 = XTmrCtr_GetValue(&timer, 1);
    do {
        uint32_t sr = xadc[XADC_SR];
        if ((sr & XADC_EOC) &&
            ((sr & XADC_CHANNEL_MASK) == XADC_CHANNEL_VAUX3)) {
            *dato = (uint16_t)((xadc[XADC_VAUX3] >> 4) & 0x0FFFU);
            return 1;
        }
    } while ((uint32_t)(XTmrCtr_GetValue(&timer, 1) - t0) < timeout_ciclos);
    return 0;
}

static void adc_disparar_software(void)
{
    (void)xadc[XADC_SR];
    xadc[XADC_CONVST] = 0U;
    xadc[XADC_CONVST] = 1U;
    xadc[XADC_CONVST] = 0U;
}

static int32_t adc_a_mA(uint16_t raw)
{
    return (((int32_t)raw - ADC_CERO) * ADC_NUM_MA) / ADC_DEN_MA;
}

static int16_t seno(uint16_t p)
{
    if (p <= 100U) return seno_q15[p];
    if (p <= 200U) return seno_q15[200U - p];
    if (p <= 300U) return (int16_t)-seno_q15[p - 200U];
    return (int16_t)-seno_q15[400U - p];
}

static int32_t pr_paso(int32_t ref_mA, int32_t real_mA)
{
    int32_t e = (ref_mA - real_mA) * ESTADO_ESCALA;
    int64_t acc = (int64_t)b0 * (e - e2)
                - (int64_t)a1 * y1 - (int64_t)a2 * y2;
    int32_t y = (int32_t)(acc / Q20);
    int64_t u;
    e2 = e1;
    e1 = e;
    if (y > ESTADO_LIM) y = ESTADO_LIM;
    if (y < -ESTADO_LIM) y = -ESTADO_LIM;
    y2 = y1;
    y1 = y;
    u = (int64_t)KP_Q20 * e / Q20 + y;
    if (u > U_ESTADO_LIM) u = U_ESTADO_LIM;
    if (u < -U_ESTADO_LIM) u = -U_ESTADO_LIM;
    return ((int32_t)u * 128L) / 1000L;
}

/* Interrupcion de control */
static void control_isr(void *contexto, u8 canal)
{
    uint32_t t0, duracion;
    uint16_t raw;
    int32_t corriente, referencia, duty;
    (void)contexto;
    if (canal != 0U) return;
    ++interrupciones;
    if (estado != ACTIVO) return;

    t0 = XTmrCtr_GetValue(&timer, 1);
    if (ultimo_inicio_isr != 0U &&
        (uint32_t)(t0 - ultimo_inicio_isr) > 2U * periodo_ciclos) {
        falla(ERR_TIEMPO_ISR);
        return;
    }
    ultimo_inicio_isr = t0;
    if (!adc_esperar(&raw, periodo_ciclos / 4U)) {
        falla(ERR_ADC);
        return;
    }
    if (raw < ADC_RAW_MIN || raw > ADC_RAW_MAX) {
        falla(ERR_ADC);
        return;
    }
    corriente = adc_a_mA(raw);
    if (corriente > CORRIENTE_MAX_MA || corriente < -CORRIENTE_MAX_MA) {
        falla(ERR_SOBRECORRIENTE);
        return;
    }

    if (pendiente_amp < 3U && (fase == 0U || fase == 200U)) {
        modo_amp = pendiente_amp;
        pendiente_amp = 3U;
    }
    /* Suavizar escalones de corriente: 10 mA de incremento por ms. */
    rampa_ciclos += periodo_ciclos;
    if (rampa_ciclos >= CPU_HZ / 1000U) {
        uint32_t objetivo = (uint32_t)amplitud_mA[modo_amp];
        rampa_ciclos -= CPU_HZ / 1000U;
        if (rampa_mA + 10U <= objetivo) rampa_mA += 10U;
        else if (rampa_mA < objetivo) rampa_mA = objetivo;
        else if (rampa_mA >= objetivo + 10U) rampa_mA -= 10U;
        else rampa_mA = objetivo;
    }

    referencia = ((int32_t)rampa_mA * seno(fase)) / 32767;
    duty = pr_paso(referencia, corriente);
    if (duty > DUTY_MAX_Q15) duty = DUTY_MAX_Q15;
    if (duty < -DUTY_MAX_Q15) duty = -DUTY_MAX_Q15;
    pwm[PWM_DUTY] = (uint32_t)(duty & 0xFFFF);

    fase = (uint16_t)(fase + fase_paso[modo_f]);
    if (fase >= 400U) fase = 0U;

    ++hist_salto;
    if (hist_salto >= ((modo_f == 2U) ? 2U : 1U)) {
        hist_salto = 0U;
        hist_ref[hist_pos] = (int16_t)referencia;
        hist_i[hist_pos] = (int16_t)corriente;
        hist_pos = (uint16_t)((hist_pos + 1U) & (HIST_N - 1U));
        if (hist_total < HIST_N) ++hist_total;
    }

    duracion = (uint32_t)(XTmrCtr_GetValue(&timer, 1) - t0);
    if (duracion >= periodo_ciclos) falla(ERR_TIEMPO_ISR);
}

static void control_detener(void)
{
    estado = PARADO;
    pwm_apagar();
    pr_reiniciar();
    gpio[2] = LED_LISTO;
}

static void frecuencia_elegir(uint32_t nueva)
{
    uint32_t n;
    if (estado != PARADO || nueva > 2U) return;
    XTmrCtr_Stop(&timer, 0);
    pwm_apagar();
    modo_f = nueva;
    n = CPU_HZ / fsw[nueva];
    periodo_ciclos = n;
    b0 = b0_q20[nueva];
    a1 = a1_q20[nueva];
    a2 = a2_q20[nueva];
    pr_reiniciar();
    hist_salto = 0U;
    ultimo_inicio_isr = 0U;
    pwm_apagar();
    XTmrCtr_SetResetValue(&timer, 0, n - 2U);
    XTmrCtr_Start(&timer, 0);
}

static int adc_verificar_reposo(void)
{
    uint32_t suma = 0U, minimo = 4095U, maximo = 0U;
    uint32_t k, media;
    for (k = 0U; k < 8U; ++k) {
        uint16_t raw;
        adc_disparar_software();
        if (!adc_esperar(&raw, CPU_HZ / 100U)) return 0;
        if (raw < minimo) minimo = raw;
        if (raw > maximo) maximo = raw;
        suma += raw;
    }
    media = suma / 8U;
    if (minimo < ADC_RAW_MIN || maximo > ADC_RAW_MAX) return 0;
    if (maximo - minimo > ADC_RANGO_REPOSO) return 0;
    if (media > (uint32_t)ADC_CERO + ADC_CERO_TOL) return 0;
    if (media + ADC_CERO_TOL < (uint32_t)ADC_CERO) return 0;
    return 1;
}

static void control_iniciar(void)
{
    uint16_t muestra;
    if (estado != PARADO) return;
    if (!HABILITAR_POTENCIA) {
        uart_texto("BTN1: inicio bloqueado hasta verificar hardware.\r\n");
        return;
    }
    pwm_apagar();
    pr_reiniciar();
    if (!adc_verificar_reposo()) {
        falla(ERR_ADC);
        return;
    }
    (void)xadc[XADC_SR];
    pwm[PWM_DUTY] = 0U;
    pwm[PWM_CTRL] = (modo_f << PWM_FSEL_SHIFT) | PWM_EN;
    if ((pwm[PWM_CTRL] & PWM_RUNNING) == 0U) {
        falla(ERR_PWM);
        return;
    }
    if (!adc_esperar(&muestra, CPU_HZ / 100U)) {
        falla(ERR_ADC);
        return;
    }
    XTmrCtr_Stop(&timer, 0);
    XTmrCtr_SetResetValue(&timer, 0, periodo_ciclos - 2U);
    XTmrCtr_Start(&timer, 0);
    ultimo_inicio_isr = 0U;
    estado = ACTIVO;
    gpio[2] = LED_MARCHA;
}

static int iniciar_interrupciones(void)
{
    if (XTmrCtr_Initialize(&timer, TIMER_ID) != XST_SUCCESS) return 0;
    XTmrCtr_SetOptions(&timer, 0, XTC_INT_MODE_OPTION |
                      XTC_AUTO_RELOAD_OPTION | XTC_DOWN_COUNT_OPTION);
    XTmrCtr_SetResetValue(&timer, 0, 9998U);
    XTmrCtr_SetOptions(&timer, 1, XTC_AUTO_RELOAD_OPTION);
    XTmrCtr_SetResetValue(&timer, 1, 0U);
    XTmrCtr_Start(&timer, 1);
    XTmrCtr_SetHandler(&timer, control_isr, &timer);
    if (XIntc_Initialize(&intc, INTC_ID) != XST_SUCCESS) return 0;
    if (XIntc_Connect(&intc, 0U,
                     (XInterruptHandler)XTmrCtr_InterruptHandler,
                     &timer) != XST_SUCCESS) return 0;
    if (XIntc_Start(&intc, XIN_REAL_MODE) != XST_SUCCESS) return 0;
    XIntc_Enable(&intc, 0U);
    Xil_ExceptionInit();
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
                                 (Xil_ExceptionHandler)XIntc_InterruptHandler,
                                 &intc);
    Xil_ExceptionEnable();
    XTmrCtr_Start(&timer, 0);
    return 1;
}

static int comprobar_timer(void)
{
    uint32_t t0 = XTmrCtr_GetValue(&timer, 1);
    while (interrupciones < 3U) {
        if ((uint32_t)(XTmrCtr_GetValue(&timer, 1) - t0) > CPU_HZ / 10U)
            return 0;
    }
    return 1;
}

/* Antirrebote 20 ms independiente de la frecuencia PWM. */
static uint32_t botones(void)
{
    static uint32_t anterior = 0U, estable = 0U, cambio = 0U;
    uint32_t raw = gpio[0] & BTN_MASK;
    uint32_t ahora = XTmrCtr_GetValue(&timer, 1);
    if (raw != anterior) {
        anterior = raw;
        cambio = ahora;
    } else if (raw != estable && (uint32_t)(ahora - cambio) >= CPU_HZ / 50U) {
        uint32_t evento = raw & ~estable;
        estable = raw;
        return evento;
    }
    return 0U;
}

/* Diagnostico minimo por UART bajo peticion, solamente PWM detenido. */
static void adc_informar(void)
{
    uint32_t k, suma = 0U, minimo = 4095U, maximo = 0U, n = 0U;
    for (k = 0U; k < 8U; ++k) {
        uint16_t raw;
        adc_disparar_software();
        if (!adc_esperar(&raw, CPU_HZ / 100U)) break;
        suma += raw;
        if (raw < minimo) minimo = raw;
        if (raw > maximo) maximo = raw;
        ++n;
    }
    uart_texto("ADC n="); uart_u32(n);
    if (n != 0U) {
        uart_texto(" media="); uart_u32(suma/n);
        uart_texto(" min="); uart_u32(minimo);
        uart_texto(" max="); uart_u32(maximo);
        uart_texto(" Iestim_mA="); uart_i32(adc_a_mA((uint16_t)(suma/n)));
    }
    if (n != 8U) uart_texto(" ERROR CONVERSION");
    uart_texto("\r\n");
}

static void exportar(void)
{
    uint16_t n = hist_total;
    uint16_t inicio = (uint16_t)((hist_pos - n) & (HIST_N - 1U));
    uint16_t k;
    uart_texto("k,Iref_mA,Iadc_mA\r\n");
    for (k = 0U; k < n; ++k) {
        uint16_t pos = (uint16_t)((inicio + k) & (HIST_N - 1U));
        uart_u32(k); uart_texto(",");
        uart_i32(hist_ref[pos]); uart_texto(",");
        uart_i32(hist_i[pos]); uart_texto("\r\n");
    }
    uart_texto("Muestras="); uart_u32(n);
    uart_texto("\r\n");
    hist_pos = hist_total = 0U;
}

int main(void)
{
    uint32_t eventos;
    pwm_apagar();
    gpio[1] = 0xFFFFFFFFU; /* 5 botones de entrada */
    gpio[3] = 0U;          /* 16 LEDs de salida */
    gpio[2] = LED_LISTO;

    if (!iniciar_interrupciones() || !comprobar_timer()) {
        falla(ERR_TIMER);
        while (1) { } /* falla enclavada; reiniciar para rearmar */
    }

    while (1) {
        eventos = botones();
        if (eventos & BTN_START) {
            if (estado == ACTIVO) {
                control_detener();
                uart_texto("PR detenido; PWM apagado.\r\n");
            } else if (estado == PARADO) {
                control_iniciar();
                if (estado == ACTIVO)
                    uart_texto("PR activo.\r\n");
                else if (estado == FALLA) {
                    uart_texto("FALLA ARRANQUE codigo=");
                    uart_u32(causa);
                    uart_texto("\r\n");
                }
            } else {
                uart_texto("FALLA enclavada codigo=");
                uart_u32(causa);
                uart_texto("\r\n");
            }
        }
        if ((eventos & BTN_AMP) && estado != FALLA) {
            uint32_t op = (pendiente_amp < 3U) ? pendiente_amp : modo_amp;
            op = (op + 1U) % 3U;
            if (estado == ACTIVO) pendiente_amp = op;
            else modo_amp = op;
            uart_texto("Referencia pico ");
            uart_u32(amplitud_mA[op]);
            uart_texto(" mA\r\n");
        }
        if ((eventos & BTN_FREQ) && estado == PARADO) {
            frecuencia_elegir((modo_f + 1U) % 3U);
            uart_texto("Frecuencia PWM ");
            uart_u32(fsw[modo_f]);
            uart_texto(" Hz\r\n");
        }
        if (eventos & BTN_EXPORT) {
            if (estado == ACTIVO) {
                uart_texto("Detenga el control para exportar.\r\n");
            } else if (estado == FALLA) {
                uart_texto("FALLA codigo="); uart_u32(causa);
                uart_texto("\r\n");
            } else if (hist_total > 0U) {
                exportar();
            } else {
                adc_informar();
            }
        }
    }
}
