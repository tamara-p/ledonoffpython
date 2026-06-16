import neopixel
from machine import Pin
import sys
import select

np = neopixel.NeoPixel(Pin(0), 3)

def set_white():
    np.fill((255, 255, 255))
    np.write()

def turn_off():
    np.fill((0, 0, 0))
    np.write()

turn_off()
print("READY")

# Non-blocking read setup
poll = select.poll()
poll.register(sys.stdin, select.POLLIN)

while True:
    if poll.poll(100):  # check every 100ms
        cmd = sys.stdin.read(1)
        
        if cmd == 'Y':
            print("ON")
            set_white()
        else:
            print("OFF")
            turn_off()