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



## Fundamentación teórica
---

## Presentación de resultados
### Módulo Procesador
### Módulo Árbitro
### Módulo 
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
