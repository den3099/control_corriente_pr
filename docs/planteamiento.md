# Diseño de Control de corriente en un inversor monofásico mediante un regulador PR discreto sobre MicroBlaze V

## Primer Nivel: Descripción General del Sistema
El primer nivel muestra como el sistema pulsaciones de botones y devuelve al usuario las muestras de corriente guardadas por el sistema y el estado en que se encuentra este por medio de indicadores LED.

![Diagrama de Bloques de Primer Nivel](../design/Diagrama_N1.png)
---

## Segundo Nivel: Arquitectura de Subsistemas
El segundo nivel, expande el sistema completo en 2 subsistemas. El primero, el Subsistema Digital, se encarga de manejar las pulsaciones de los botones, guardar las muestras de corriente provenientes del segundo subsistema, mostrar el estado del sistema por medio de LEDs, y de enviar las muestras a un computador para su posterior visualización. El segundo subsistema, el Subsistema de Potencia, es el encargado de proporcionar las muestras de corriente al subsistema Digital, este se sincroniza con el primer subsistema por medio de una señal producida por el PWM dentro de este último.

![Diagrama de Bloques de Segundo Nivel](../design/Diagrama_N2.png)
---

## Tercer Nivel: 
El tercer nivel detalla el subsitema Digital, este desglosa como el subsistema es controlado por un procesador MicroBlaze V conectado a los periféricos por medio de un módulo "Árbitro & MUX" que decide que periférico recibe las señales de lectura o escritura. El sistema cuenta con una señal de reloj y reinicio general, "clk" y "rst" respectivamente. Tanto el procesador como los periféricos usan el protocolo AXI4(Lite) parra las señales.

![Diagrama de Bloques de Tercer Nivel](../design/Diagrama_N3.png)
---

## Cuarto Nivel:

### Módulo PWM

El periférico PWM se diseñó para generar las cuatro señales de accionamiento del puente H (pwm_AH, pwm_AL, pwm_BH y pwm_BL) a partir de una referencia de modulación suministrada por el sistema de control. Su configuración se realiza mediante una interfaz AXI4-Lite, que permite modificar los parámetros de operación y consultar el estado del periférico.

El diseño contempla dos parámetros principales: la habilitación del generador (enable) y la selección de frecuencia de conmutación (freq_sel). Además, recibe una referencia de modulación de 16 bits con signo (duty_ref), que determina los niveles de comparación para las dos ramas del inversor.

A partir de estos parámetros, el sistema genera una portadora triangular y realiza una modulación unipolar mediante su comparación con las referencias calculadas. Las señales resultantes pasan por una etapa de generación de tiempo muerto de 50 ciclos de reloj, obteniendo las cuatro señales complementarias destinadas al accionamiento del puente H. Cuando el periférico se encuentra deshabilitado, las salidas permanecen en estado bajo.

![Diagrama de Bloques de Tercer Nivel](../design/Diagrama_N4.png)
---

### Procesador MicroBlaze V

El MicroBlaze V coordina el funcionamiento del subsistema digital mediante la ejecución del programa de control en C. Recibe las muestras del ADC, consulta el estado de los botones y calcula la acción del regulador PR para actualizar la referencia del PWM. También almacena las mediciones y organiza su envío por UART. Recibe las señales de reloj, reinicio e interrupción, y se comunica con los periféricos mediante operaciones de lectura y escritura a sus registros mapeados en memoria.

### Módulo Árbitro y MUX

El módulo Árbitro y MUX conecta el procesador con los periféricos. Recibe las direcciones y las solicitudes de lectura o escritura del MicroBlaze V y selecciona el periférico correspondiente según el mapa de memoria. En una escritura, dirige la dirección y el dato al destino seleccionado y devuelve la respuesta al procesador. En una lectura, envía la solicitud al periférico y selecciona el dato que debe regresar al MicroBlaze V. Recibe además las señales de reloj y reinicio para controlar las transacciones en curso.

### Módulo GPIO

El periférico GPIO permite conectar los botones y los indicadores LED con el procesador. Sus entradas reciben el estado lógico de los botones, que queda disponible para consulta mediante registros AXI4-Lite. El programa interpreta estas lecturas y determina la acción correspondiente. Para controlar los LEDs, el procesador escribe en los registros de salida y el GPIO mantiene esos valores en los pines conectados a los indicadores. De esta forma, el usuario puede solicitar acciones y observar el estado del sistema.

### Módulo UART

El periférico UART Lite permite transmitir a la computadora las muestras almacenadas por el sistema. Recibe los bytes que escribe el procesador mediante AXI4-Lite, los guarda temporalmente en un búfer y los transmite de forma serial por la salida tx, con la velocidad configurada. La entrada rx permite recibir información desde el equipo externo cuando se utiliza esta función. El módulo también dispone de registros de estado para que el programa consulte la disponibilidad de los búferes. La salida de transmisión se conecta al puente USB-UART utilizado para la comunicación con la computadora.

### Módulo de interfaz ADC XADC

La interfaz ADC/XADC permite obtener una representación digital de la corriente medida. Recibe una señal analógica acondicionada y una orden de inicio de conversión, que puede provenir del software o del disparo pwm_trigger_o generado por el PWM. Este disparo permite coordinar el instante de adquisición con la conmutación. Al finalizar la conversión, el módulo indica que existe una muestra disponible y presenta el dato para su lectura por el procesador mediante la interfaz AXI4-Lite. 