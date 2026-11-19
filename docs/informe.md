# Proyecto 4: Control de corriente en un inversor monofásico mediante un regulador PR discreto sobre MicroBlaze V

**Integrantes**

**Dennis Manuel Arce Alvarez**  

*Escuela de Ingeniería Electrónica*  

*Tecnológico de Costa Rica*  

Carné: 2018151568

**Brayan Díaz Ruiz**  

*Escuela de Ingeniería Electrónica*  

*Tecnológico de Costa Rica*  

Carné: 2018203585

**Joan Franco Sandoval**  

*Escuela de Ingeniería Electrónica*  

*Tecnológico de Costa Rica*  

Carné: 2020248356

**Steven Sancho Orozco**  

*Escuela de Ingeniería Electrónica*  

*Tecnológico de Costa Rica*  

Carné: 2019015506

## Introducción

El proyecto propone desarrollar un sistema de control de corriente para un inversor monofásico en puente H, utilizando una FPGA con un procesador MicroBlaze V de AMD. La arquitectura integra software en C, desarrollado en Vitis, con periféricos digitales conectados en Vivado, incluidos módulos personalizados en SystemVerilog con interfaces AXI4-Lite.

El objetivo es regular la corriente de una carga resistiva-inductiva para seguir una referencia sinusoidal de 50 Hz mediante un controlador proporcional-resonante (PR) discreto. Para ello, el sistema coordina periódicamente la adquisición de corriente, el cálculo del control y la actualización del PWM. Además, almacena las muestras y permite transferirlas a una computadora mediante UART para su análisis.

El desarrollo combina diseño digital, sistemas embebidos, electrónica de potencia y control automático. Su funcionamiento se evaluará mediante simulaciones y pruebas experimentales con una etapa de potencia real.

## Descripción general del sistema

El sistema propuesto está compuesto por una plataforma digital basada en FPGA y una etapa de potencia formada por un inversor monofásico en puente H y una carga RL. La plataforma digital utiliza el procesador MicroBlaze V como unidad de procesamiento principal. Este ejecuta una aplicación en C encargada de realizar el algoritmo de control y coordinar el intercambio de información con los periféricos.

En términos funcionales, el sistema opera mediante un lazo de control realimentado. La corriente que circula por la carga se mide y se convierte en una representación digital. El procesador utiliza esa medición junto con la referencia establecida para calcular la acción de control mediante un regulador PR discreto. El resultado se utiliza para actualizar la modulación PWM que controla la conmutación del puente H y, por consiguiente, la tensión aplicada a la carga.

La ejecución del control se organiza alrededor de una base de tiempo periódica, de modo que las operaciones de medición, cálculo y actualización se realicen de forma coordinada. Adicionalmente, el sistema contempla almacenar las muestras adquiridas en memoria y transmitirlas a una computadora mediante UART cuando el usuario lo solicite.

La integración entre el procesador y los periféricos se plantea mediante una arquitectura de registros mapeados en memoria sobre interfaces AXI4-Lite. Esta organización permite que el software configure y consulte los recursos de hardware a través de direcciones asignadas dentro del sistema.

## Investigación previa

El desarrollo de un sistema embebido de control en tiempo real sobre una FPGA Artix-7 se fundamenta en la integración del procesador soft-core configurable MicroBlaze V, desarrollado por AMD y basado en la arquitectura RISC-V con conjunto de instrucciones RV32I en su versión de 32 bits. Este procesador emplea registros de propósito general y un Program Counter para ejecutar instrucciones aritméticas, lógicas, de transferencia y de salto desde lenguajes de alto nivel como C, incorporando además soporte de interrupciones y excepciones para atender eventos sin depender únicamente de la ejecución secuencial. La construcción de esta arquitectura se lleva a cabo mediante el flujo de diseño de AMD Vivado y Vitis, donde Vivado permite crear un Block Design para interconectar gráficamente los componentes y asignar sus direcciones de memoria, culminando con la síntesis, la implementación para obtener el archivo bitstream y la exportación del hardware en un archivo XSA. Posteriormente, dicho archivo se importa en Vitis para generar la plataforma de desarrollo y programar, compilar y depurar la aplicación embebida mediante sus respectivos controladores.

Para la comunicación interna entre el hardware y el software, el sistema emplea el protocolo AXI4-Lite bajo una arquitectura maestro-esclavo, en la cual el MicroBlaze V actúa como maestro frente a los periféricos esclavos mediante transferencias individuales de 32 bits. Esta interfaz organiza la comunicación en cinco canales independientes de lectura y escritura sincronizados mediante las señales de control VALID y READY, lo que permite al procesador acceder a registros mapeados en memoria para configurar y monitorear módulos específicos. Bajo este esquema se diseñan periféricos IP personalizados en lenguajes como Verilog o VHDL, como es el caso del controlador PWM, al cual se le dota de una interfaz esclava AXI4-Lite con registros dedicados para ajustar la frecuencia, el ciclo de trabajo y su habilitación, validando previamente su funcionamiento y temporización antes de integrarlo al diseño general.

El cumplimiento de los requisitos temporales del lazo de control se resuelve combinando la gestión periódica por software con la precisión de la lógica programable de la FPGA. Para ello, se utiliza el periférico AXI Timer para generar interrupciones repetitivas que establecen una base de tiempo constante, permitiendo que una rutina de servicio de interrupción (ISR) coordine la adquisición de corriente, el cálculo de la ley de control y la actualización de referencias dentro del período de muestreo. Simultáneamente, las tareas críticas de alta precisión se delegan al hardware, implementando mediante contadores y lógica digital una modulación PWM unipolar para puente H. Esta técnica compara referencias desfasadas con una portadora para generar tres niveles de tensión y mejorar la distribución de armónicos, incorporando además un tiempo muerto entre transistores complementarios de una misma rama para evitar el cortocircuito por conducción simultánea o shoot-through.

En la etapa de realimentación, se plantea realizar la adquisición de señales analógicas mediante el convertidor analógico-digital integrado XADC de 12 bits configurado en modo de muestreo por eventos, lo cual permite disparar la conversión desde el contador del PWM en un instante alejado de los flancos de conmutación para minimizar el ruido y respetar las latencias antes de actualizar el ciclo de trabajo. El fin de la conversión se notifica mediante la señal EOC y el dato se lee a través del puerto DRP utilizando las señales DADDR, DWE, DEN, DCLK y DO cuando DRDY confirma su disponibilidad. Todo este flujo operativo se gestiona mediante programación embebida en C bajo una ejecución bare-metal sin sistema operativo, utilizando el BSP y controladores de acceso a memoria dentro de una máquina de estados de inicialización, operación y fallo; durante la operación, la ISR coordina adquisición, cálculo y actualización del PWM, asegurando que las ISR sean breves y protejan los datos compartidos. Finalmente, se prevé verificar la solución completa mediante testbenches autocomprobables en SystemVerilog con aserciones y simulaciones integrales de la interacción entre el XADC, el controlador y el PWM, contrastando posteriormente en hardware la sincronización, las latencias y la integridad de los datos mediante el uso de osciloscopio e ILA.

El funcionamiento de los inversores monofásicos en puente H se basa en dos piernas de interruptores que, al activarse en diagonal, aplican tensiones de +V<sub>dc</sub> o -V<sub>dc</sub>, o bien generan un estado de tensión cero para permitir la recirculación de la corriente en la carga. Para evitar cortocircuitos causados por la conducción simultánea en una misma pierna, se introduce un tiempo muerto, mientras que la modulación PWM unipolar compara dos referencias sinusoidales opuestas con una portadora triangular para producir una tensión de salida de tres niveles cuyo valor promedio sigue la referencia, presentando una frecuencia de rizado predominante de 2f<sub>sw</sub>. En cuanto al comportamiento dinámico, las cargas RL alimentadas por estos sistemas se describen mediante la ecuación L di/dt+Ri=v y una función de transferencia de 1/(Ls+R), donde los valores nominales del firmware, R=4,7 Ω y L=25,3 mH, establecen una constante de tiempo aproximada de 5,38 ms y una frecuencia de corte de 29,6 Hz. Estos parámetros deben contrastarse con la carga utilizada.

Para lograr un seguimiento preciso de la corriente sinusoidal de 50 Hz, se utiliza un controlador Proporcional-Resonante (PR), el cual combina la respuesta al error mediante su término proporcional con un incremento de ganancia en la frecuencia objetivo gracias al término resonante. Se emplea una estructura amortiguada para disminuir la sensibilidad ante ligeras desviaciones de frecuencia, y su sintonización debe fijar el cruce del lazo considerando la frecuencia de muestreo, los retardos y el ajuste de parámetros para asegurar el margen de fase y la validación en PLECS. Para ejecutar este controlador en el MicroBlaze V, la ley de control continua puede discretizarse mediante Tustin con prewarping en 50 Hz; el procedimiento y los coeficientes deben verificarse para el período seleccionado, considerando un retardo estimado de 1,5T<sub>s</sub> que puede reducir el margen de estabilidad y exigiendo una correcta coordinación entre el muestreo y la portadora para disminuir el impacto del rizado. Finalmente, la validación experimental requiere acondicionar la señal para el rango del XADC, analizar al menos cinco periodos mediante DFT para extraer la componente fundamental, medir por separado el rizado de conmutación y realizar ensayos con diferentes referencias y variaciones de resistencia, destacando que no procede afirmar resultados ni diferencias experimentales al no contarse aún con mediciones.

## Fundamentación teórica

El MicroBlaze V es un procesador configurable basado en RISC-V que ejecuta el programa embebido. La memoria local almacena instrucciones, variables y muestras; los periféricos se controlan mediante registros mapeados en memoria. Vivado define el hardware y exporta la plataforma XSA; Vitis utiliza esa información para generar el BSP y compilar el ejecutable ELF. [1], [2]

AXI4-Lite separa las transferencias en cinco canales: dirección de escritura (AW), datos de escritura (W), respuesta de escritura (B), dirección de lectura (AR) y datos de lectura (R). Cada transferencia se acepta cuando coinciden VALID y READY. El interconector decodifica la dirección y devuelve al procesador la respuesta del periférico seleccionado. [3]

El regulador PR calcula una acción de control a partir del error entre referencia y corriente medida. Su implementación discreta conserva errores y estados anteriores, limita la salida y entrega al PWM una referencia con signo en formato Q1.15. El temporizador establece el período de ejecución; su coincidencia con la portadora y el disparo del ADC requieren una sincronización explícita. [7]

---

## Presentación de resultados

### Módulo Procesador

El MicroBlaze V ejecuta la aplicación en C y coordina la lectura de corriente, el regulador PR y la escritura del PWM. Recibe reloj, reinicio, instrucciones y datos desde memoria y, en la arquitectura requerida por el programa, la interrupción del temporizador a través del controlador de interrupciones. Emite direcciones, datos y solicitudes de lectura o escritura hacia los periféricos.

El archivo de configuración recibido habilita las interfaces locales LMB de instrucciones y datos, con direcciones y datos de 32 bits. Sin embargo, presenta `C_D_AXI=0`, `C_USE_INTERRUPT=0` y `C_USE_ICACHE=0`: el acceso AXI de datos y las interrupciones requeridos por el firmware deben habilitarse; la caché debe ajustarse según los requisitos del proyecto. Los 100 MHz utilizados en los cálculos del programa son un valor nominal que debe coincidir con el reloj implementado. [1]

### Módulo Árbitro

El bloque «Árbitro & MUX» del diagrama conecta el procesador con GPIO, UART, ADC y PWM. En el código recibido se implementa mediante `traductor_direcciones` y `mux_lectura`; por tanto, esta parte también contiene lógica personalizada. Recibe `clk`, `rst` y los cinco canales AXI4-Lite del maestro; distribuye solicitudes y devuelve los datos y las respuestas del periférico seleccionado.

La selección se realiza con los 16 bits superiores de la dirección. Se conserva el destino durante la transacción y las direcciones no mapeadas producen una respuesta `DECERR`.

| Periférico | Dirección base |
| --- | --- |
| GPIO | `0x40010000` |
| ADC | `0x40020000` |
| PWM | `0x40030000` |
| UART | `0x40040000` |

Este mapa coincide con el firmware. Faltan las rutas y direcciones de Timer e INTC, utilizados por el programa. Además, debe verificarse la compatibilidad de escritura con las IP: el traductor habilita W después de aceptar AW, mientras que un esclavo AXI puede esperar ambos canales antes de aceptar la dirección. [3]

### Módulo PWM

El periférico PWM, implementado en `PWM_CONTROLLER`, genera las cuatro señales de accionamiento del puente H, `pwm_AH`, `pwm_AL`, `pwm_BH` y `pwm_BL`. Recibe del MicroBlaze V una referencia de modulación mediante AXI4-Lite, junto con los parámetros de habilitación y frecuencia. Su funcionamiento depende del reloj `clk`, del reinicio `rst` y de la configuración escrita por el programa de control.

Internamente, integra cinco submódulos.

- **`AXI_LITE_INTERFACE`** recibe las solicitudes de lectura y escritura del procesador y permite acceder al banco de registros.

- **`PWM_REGISTERS`** almacena la habilitación, la selección de frecuencia y la referencia. También permite consultar `running`, que indica una configuración habilitada con frecuencia válida.

- **`PWM_FREQUENCY_GENERATOR`** genera una portadora triangular mediante un contador ascendente y descendente. Con un reloj de 100 MHz, permite seleccionar frecuencias de 5, 10 y 20 kHz.

- **`UNIPOLAR_MODULATOR`** utiliza `duty_ref`, una referencia de 16 bits con signo en formato Q1.15, para calcular los umbrales de ambas ramas. Al compararlos con la portadora obtiene `raw_pwm_A` y `raw_pwm_B`.

- **`DEAD_TIME_GENERATOR`** procesa estas señales e inserta un intervalo con ambas salidas de cada rama en bajo antes de activar la salida correspondiente. El tiempo muerto se fija en 50 ciclos, equivalentes a 500 ns a 100 MHz.

La configuración se organiza en dos registros, cuyos offsets se suman a la dirección base del periférico.

| Offset | Registro | Campos |
| --- | --- | --- |
| `0x00` | Control y estado | `enable` en el bit 0, `freq_sel` en los bits [2:1] y `running` de solo lectura en el bit 3. |
| `0x04` | Referencia | `duty_ref` en los bits [15:0]. |

Una vez habilitado, el PWM continúa funcionando con la referencia almacenada mientras el procesador realiza otras tareas. Sus salidas se entregan a la interfaz de accionamiento del puente H. Cuando se deshabilita o se activa `rst`, las cuatro salidas permanecen en bajo.

En la versión recibida quedan pendientes la incorporación de `pwm_trigger_o`, la saturación de escrituras y la validación de los cambios de frecuencia durante la operación.

### Módulo GPIO

AXI GPIO relaciona el programa con los botones y los LED. Recibe reloj, reinicio, accesos AXI4-Lite y las señales de los botones; entrega al procesador su estado y mantiene las salidas de los LED. El firmware espera una configuración de dos canales: canal 1 de entrada para cuatro botones y canal 2 de salida para los indicadores.

Sus registros son `GPIO_DATA` y `GPIO_TRI`, en los offsets `0x00` y `0x04`, y sus equivalentes del segundo canal en `0x08` y `0x0C`. Un bit TRI en uno configura entrada y en cero, salida. Como `GPIO_CONFIG_TRI=0`, las direcciones deben quedar correctamente configuradas en la IP. El antirrebote se realiza por software. [5]

### Módulo UART

AXI UART Lite conecta el procesador con la computadora. Recibe bytes mediante AXI4-Lite y los transmite por `tx`; por `rx` puede recibir información externa. Sus FIFO almacenan temporalmente los datos y sus registros permiten consultar el estado y reiniciar los búferes. Requiere reloj, reinicio y parámetros de transmisión coincidentes con la aplicación de PC. [4]

Los offsets esperados son `RX=0x00`, `TX=0x04`, `STATUS=0x08` y `CONTROL=0x0C`. El firmware reinicia las FIFO y exporta mediante `xil_printf`, por lo que la salida estándar del BSP debe asignarse a esta UART. La transmisión llega al PC a través del puente USB-UART de la tarjeta. El programa actual envía encabezados, parámetros y líneas `índice,corriente_mA`; no transmite directamente una gráfica.

### Módulo ADC/XADC

La interfaz ADC/XADC proporciona al procesador la medición de corriente. En una implementación con XADC recibe la señal analógica acondicionada, reloj, reinicio y la configuración del convertidor; entrega muestras digitales de 12 bits y señales de fin de conversión o disponibilidad. El acceso AXI permite configurar el bloque y consultar los datos. [6]

El firmware presupone una interfaz simplificada:

| Offset | Función esperada por el programa |
| --- | --- |
| `0x00` | Control; bit 0 de inicio de conversión. |
| `0x04` | Estado; bit 0 de dato disponible. |
| `0x08` | Muestra adquirida. |

Este mapa es provisional y no corresponde directamente al banco de registros estándar del XADC: requiere una interfaz adaptadora o modificar el acceso del programa. También deben ajustarse `ADC_MASK=0xF`, el desplazamiento de cero y la escala de corriente a la resolución y calibración reales. El código selecciona disparo por hardware, pero el PWM recibido todavía no implementa `pwm_trigger_o`; la adquisición sincronizada queda pendiente de integración.

### Módulo Temporizador

AXI Timer proporciona la base de tiempo del control. Recibe reloj, reinicio y configuración por AXI; entrega una interrupción al INTC y valores de cuenta al programa. El firmware utiliza el contador 0 en modo descendente, recarga automática e interrupción periódica, y el contador 1 como contador libre para medir intervalos y duración de la ISR. [7]

Los períodos nominales son 200, 100 y 50 µs para las selecciones de 5, 10 y 20 kHz. La frecuencia del reloj, la recarga y el identificador del periférico deben coincidir con la plataforma exportada. Las mediciones previstas por el código no constituyen resultados experimentales disponibles.

### Módulo Controlador de interrupciones

AXI Interrupt Controller (INTC) recibe la interrupción del temporizador y presenta la solicitud `irq` al procesador. Recibe además reloj, reinicio y accesos AXI4-Lite para habilitar fuentes, consultar eventos pendientes y reconocer su atención. El controlador concentra las solicitudes; el procesador ejecuta la ISR correspondiente. [8]

El programa inicializa `XIntc`, conecta el manejador de AXI Timer y habilita las interrupciones del procesador. Los identificadores `TMR_DEVICE_ID`, `INTC_DEVICE_ID` y `TMR_INTR_ID` deben revisarse contra `xparameters.h`; no quedan determinados únicamente por el diagrama recibido.


### Programa del Sistema

El archivo en C corresponde al firmware destinado a Vitis para ejecutarse en el MicroBlaze V. Utiliza el BSP, registros mapeados en memoria y los controladores `XTmrCtr` y `XIntc`. Se compila en un ELF para la plataforma exportada desde Vivado; este ejecutable se carga en la memoria accesible al procesador, junto con la configuración FPGA correspondiente. [2]

La inicialización configura periféricos, estados del PR y temporización. El programa distingue `SYS_INIT`, `SYS_WORK` y `SYS_FAULT`, indicados mediante LED. En operación, la ISR adquiere la corriente, calcula la referencia y el PR, escribe el PWM y almacena la muestra. Un fallo de adquisición o una corriente superior al límite configurado deshabilitan las salidas.

| Parámetro | Implementación recibida |
| --- | --- |
| Referencia | 50 Hz; amplitud seleccionable de 0,2, 0,5 o 1 A pico. |
| Frecuencia inicial | 10 kHz; también permite seleccionar 5 y 20 kHz. |
| Regulador PR | Habilitado únicamente para 10 kHz, según sus coeficientes actuales. |
| Referencia PWM | Q1.15, limitada por software aproximadamente a ±0,9. |
| Protección de corriente | Límite configurado de 1,5 A; depende de la calibración del ADC. |
| Histórico | Búfer circular de 2048 muestras, expresadas en mA. |

El lazo principal atiende los botones: BTN0 exporta muestras, BTN1 inicia o detiene, BTN2 cambia amplitud y BTN3 cambia frecuencia. La exportación congela la escritura del histórico mientras lo transmite por UART y luego lo reinicia. En 5 y 20 kHz el código escribe referencia de modulación cero; esto no equivale a deshabilitar el PWM.

`cambios1.txt` propone guardar el histórico en `int16_t`, reconstruir la senoide desde una tabla de un cuarto de período y sustituir `sinf` y `sqrtf` por aproximaciones. Estos cambios aún no están aplicados en el archivo principal recibido y se consideran una propuesta de reducción de memoria y dependencia de funciones matemáticas.

## Análisis de resultados

### Módulo Procesador

### Módulo Árbitro

### Módulo

### Módulo

### Módulo

### Programa del Sistema

---

### Conclusión

---

### Referencias

[1] AMD. [MicroBlaze V Processor Reference Guide (UG1629): Core Configurability](https://docs.amd.com/r/2025.1-English/ug1629-microblaze-v-user-guide/MicroBlaze-V-Core-Configurability).

[2] AMD. [MicroBlaze V Embedded Design Tutorial (UG1711): Exporting a Hardware Description](https://docs.amd.com/r/2025.1-English/ug1711-microblaze-v-embedded-design/Exporting-a-Hardware-Description).

[3] AMD. [Vivado Design Suite: AXI Reference Guide (UG1037)](https://docs.amd.com/v/u/en-US/ug1037-vivado-axi-reference-guide).

[4] AMD. [AXI UART Lite (PG142)](https://docs.amd.com/v/u/en-US/pg142-axi-uartlite).

[5] AMD. [AXI GPIO (PG144): Register Space](https://docs.amd.com/r/en-US/pg144-axi-gpio/Register-Space).

[6] AMD. [XADC Wizard (PG091)](https://docs.amd.com/api/khub/documents/fiHyFFFNQOuYbS0gDdL34A/content).

[7] AMD. [AXI Timer (PG079): Functional Description](https://docs.amd.com/r/en-US/pg079-axi-timer/Functional-Description).

[8] AMD. [AXI Interrupt Controller (PG099)](https://docs.amd.com/v/u/en-US/pg099-axi-intc).
