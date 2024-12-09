### Midi to Serial UART

This project provides a simple cicuit diagram for converting standard midi output signals into serial UART signals, capable of being received by our AgonLight2 (or other micro controllers).

Assembly code is included as well as a binary to monitor serial signals being received by Agon. Note that the baud rate is set at 31250 for midi signals. You can adjust this in the source code for other purposes.

Parts required:

- 1N4148 switching signal diode 		

- DIN-5 jack (MIDI), or wire direct to a 5 PIN plug 	

- 6N138 Optoisolator

- 220 ohm Resistor 		

- 470 ohm Resistor 		

- 10k ohm Resistor 	

- vero board or similar


![](./midicircuit.png)
