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

En la etapa de realimentación, la adquisición de señales analógicas se realiza mediante el convertidor analógico-digital integrado XADC de 12 bits configurado en modo de muestreo por eventos, lo cual permite disparar la conversión desde el contador del PWM en un instante alejado de los flancos de conmutación para minimizar el ruido y respetar las latencias antes de actualizar el ciclo de trabajo. El fin de la conversión se notifica mediante la señal EOC y el dato se lee a través del puerto DRP utilizando las señales DADDR, DWE, DEN, DCLK y DO cuando DRDY confirma su disponibilidad. Todo este flujo operativo se gestiona mediante programación embebida en C bajo una ejecución bare-metal sin sistema operativo, utilizando el BSP y controladores de acceso a memoria dentro de una máquina de estados que abarca inicialización, adquisición, cálculo, actualización del PWM y fallo, asegurando que las ISR sean breves y protejan los datos compartidos. Finalmente, la solución completa se verifica mediante testbenches autocomprobables en SystemVerilog con aserciones y simulaciones integrales de la interacción entre el XADC, el controlador y el PWM, contrastando posteriormente en hardware la sincronización, las latencias y la integridad de los datos mediante el uso de osciloscopio e ILA. 
El funcionamiento de los inversores monofásicos en puente H se basa en dos piernas de interruptores que, al activarse en diagonal, aplican tensiones de +V<sub>dc</sub> o -V<sub>dc</sub>, o bien generan un estado de tensión cero para permitir la recirculación de la corriente en la carga. Para evitar cortocircuitos causados por la conducción simultánea en una misma pierna, se introduce un tiempo muerto, mientras que la modulación PWM unipolar compara dos referencias sinusoidales opuestas con una portadora triangular para producir una tensión de salida de tres niveles cuyo valor promedio sigue la referencia, presentando una frecuencia de rizado predominante de 2f<sub>sw</sub>. En cuanto al comportamiento dinámico, las cargas RL alimentadas por estos sistemas se describen mediante la ecuación L di/dt+Ri=v y una función de transferencia de 1/(Ls+R), donde los valores provisionales de R=4,7 Ω y L=10 "mH"  establecen una constante de tiempo aproximada de 2,13 "ms"  y una frecuencia de corte de 74,8 "Hz"  que deberán recalcularse con los datos definitivos.

Para lograr un seguimiento preciso de la corriente sinusoidal de 50 Hz, se utiliza un controlador Proporcional-Resonante (PR), el cual combina la respuesta al error mediante su término proporcional con un incremento de ganancia en la frecuencia objetivo gracias al término resonante. Se emplea una estructura amortiguada para disminuir la sensibilidad ante ligeras desviaciones de frecuencia, y su sintonización debe fijar el cruce del lazo considerando la frecuencia de muestreo, los retardos y el ajuste de parámetros para asegurar el margen de fase y la validación en PLECS. Para ejecutar este controlador en el MicroBlaze V, la ley de control continua se discretiza aplicando Tustin con prewarping en 50 Hz para conservar la estabilidad y la resonancia, considerando un retardo estimado de 1,5T<sub>s</sub> que puede reducir el margen de estabilidad y exigiendo una correcta coordinación entre el muestreo y la portadora para disminuir el impacto del rizado. Finalmente, la validación experimental requiere acondicionar la señal para el rango del XADC, analizar al menos cinco periodos mediante DFT para extraer la componente fundamental, medir por separado el rizado de conmutación y realizar ensayos con diferentes referencias y variaciones de resistencia, destacando que no procede afirmar resultados ni diferencias experimentales al no contarse aún con mediciones.



## Fundamentación teórica
---

## Presentación de resultados
### Módulo Procesador
### Módulo Árbitro
### Módulo PWM

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

### Módulo 
### Módulo 
### Programa del Sistema

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
