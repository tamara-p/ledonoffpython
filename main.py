import neopixel
from machine import Pin, I2C
import sys
import select
import time
import json

# =====================================================
# Configuration
# =====================================================

NUM_PIXELS = 3
PIXEL_PIN = 0

SHT31_ADDR = 0x44

IDLE_POLL_MS = 5000
ACTIVE_POLL_MS = 500

SESSION_TIMEOUT_MS = 90000      # 90 seconds
LED_TIMEOUT_MS = 120000         # 2 minutes

# =====================================================
# NeoPixels
# =====================================================

np = neopixel.NeoPixel(Pin(PIXEL_PIN), NUM_PIXELS)

led_on = False
led_start_time = 0

def leds_on():
    global led_on, led_start_time

    np.fill((255, 255, 255))
    np.write()

    led_on = True
    led_start_time = time.ticks_ms()

def leds_off():
    global led_on

    np.fill((0, 0, 0))
    np.write()

    led_on = False

leds_off()

# =====================================================
# SHT31
# =====================================================

try:
    i2c = I2C(0, scl=Pin(5), sda=Pin(4))
except Exception:
    i2c = None

def read_sensor():

    if i2c is None:
        raise Exception("I2C_NOT_INITIALIZED")

    i2c.writeto(SHT31_ADDR, b'\x24\x00')
    time.sleep_ms(20)

    data = i2c.readfrom(SHT31_ADDR, 6)

    temp_raw = (data[0] << 8) | data[1]
    hum_raw = (data[3] << 8) | data[4]

    temperature = -45 + 175 * temp_raw / 65535
    humidity = 100 * hum_raw / 65535

    return round(temperature, 2), round(humidity, 2)

# =====================================================
# Session State
# =====================================================

session_active = False
last_command_time = 0

# =====================================================
# Serial
# =====================================================

poll = select.poll()
poll.register(sys.stdin, select.POLLIN)

# =====================================================
# Main Loop
# =====================================================

while True:

    try:

        current_time = time.ticks_ms()

        # ---------------------------------------------
        # LED timeout
        # ---------------------------------------------

        if led_on:

            if time.ticks_diff(
                current_time,
                led_start_time
            ) >= LED_TIMEOUT_MS:

                leds_off()

        # ---------------------------------------------
        # Session timeout
        # ---------------------------------------------

        if session_active:

            if time.ticks_diff(
                current_time,
                last_command_time
            ) >= SESSION_TIMEOUT_MS:

                session_active = False
                leds_off()

        # ---------------------------------------------
        # Dynamic polling interval
        # ---------------------------------------------

        poll_time = ACTIVE_POLL_MS if session_active else IDLE_POLL_MS

        if poll.poll(poll_time):

            try:

                line = sys.stdin.readline().strip()

                if not line:
                    continue

                msg = json.loads(line)

            except Exception:

                try:
                    print(json.dumps({
                        "type": "error",
                        "message": "INVALID_JSON"
                    }))
                except:
                    pass

                continue

            cmd = msg.get("cmd", "")

            # -----------------------------------------
            # Start session
            # -----------------------------------------

            if cmd == "start_session":

                session_active = True
                last_command_time = time.ticks_ms()

                print(json.dumps({
                    "type": "status",
                    "message": "SESSION_STARTED"
                }))

            # Ignore other commands if no session active
            elif not session_active:

                print(json.dumps({
                    "type": "error",
                    "message": "NO_ACTIVE_SESSION"
                }))

            # -----------------------------------------
            # Active-session commands
            # -----------------------------------------

            else:

                last_command_time = time.ticks_ms()

                if cmd == "read_sensor":

                    try:

                        temp_c, humidity = read_sensor()

                        print(json.dumps({
                            "type": "sensor",
                            "temp_c": temp_c,
                            "humidity": humidity
                        }))

                    except Exception as e:

                        print(json.dumps({
                            "type": "error",
                            "message": str(e)
                        }))

                elif cmd == "light_on":

                    leds_on()

                    print(json.dumps({
                        "type": "info",
                        "message": "LED_ON"
                    }))
                elif cmd == "light_off":

                    leds_off()

                    print(json.dumps({
                        "type": "info",
                        "message": "LED_OFF"
                    }))

                else:

                    print(json.dumps({
                        "type": "error",
                        "message": "UNKNOWN_COMMAND"
                    }))

        time.sleep_ms(10)

    except Exception:

        try:
            leds_off()
        except:
            pass

        time.sleep_ms(100)