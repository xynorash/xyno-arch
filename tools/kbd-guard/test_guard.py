#!/usr/bin/env python3
"""Test xyno-kbd-guard against a VIRTUAL keyboard (never touches the real one)."""
import fcntl, json, os, select, struct, subprocess, sys, time

D = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, D)
import importlib.machinery, importlib.util
loader = importlib.machinery.SourceFileLoader("guard", os.path.join(D, "..", "..", "system", "usr", "local", "bin", "xyno-kbd-guard"))
spec = importlib.util.spec_from_loader("guard", loader)
g = importlib.util.module_from_spec(spec); loader.exec_module(g)

NAME = "TEST Chatter Keyboard"
# F13..F18: harmless keys, so the desktop ignores them even though it sees the virtual keyboard
KEY_A, KEY_B, KEY_C, KEY_D, KEY_E, KEY_F = 183, 184, 185, 186, 187, 188
LED_NUML, LED_CAPSL = 0, 1


def make_test_keyboard():
    fd = os.open("/dev/uinput", os.O_RDWR | os.O_NONBLOCK)
    for ev in (g.EV_SYN, g.EV_KEY, g.EV_MSC, g.EV_LED):
        fcntl.ioctl(fd, g.UI_SET_EVBIT, ev)
    for k in range(183, 195):
        fcntl.ioctl(fd, g.UI_SET_KEYBIT, k)
    fcntl.ioctl(fd, g.UI_SET_MSCBIT, 4)
    for l in (LED_NUML, LED_CAPSL):
        fcntl.ioctl(fd, g.UI_SET_LEDBIT, l)
    setup = struct.pack("HHHH", 3, 0x1a2c, 0x6004, 1) + NAME.encode().ljust(80, b"\0") + struct.pack("I", 0)
    fcntl.ioctl(fd, g.UI_DEV_SETUP, setup)
    fcntl.ioctl(fd, g.UI_DEV_CREATE)
    time.sleep(0.5)
    return fd


def emit(fd, code, val):
    ev = g.EVENT
    os.write(fd, ev.pack(0, 0, g.EV_MSC, 4, code) + ev.pack(0, 0, g.EV_KEY, code, val) + ev.pack(0, 0, g.EV_SYN, 0, 0))


def drain(fd, wait=0.3):
    out = []
    end = time.time() + wait
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.05)
        if r:
            try:
                data = os.read(fd, 24 * 64)
            except BlockingIOError:
                continue
            for i in range(0, len(data) - 23, 24):
                _, _, typ, code, val = g.EVENT.unpack(data[i:i + 24])
                out.append((typ, code, val))
    return out


def keys_only(evs):
    return [(c, v) for t, c, v in evs if t == g.EV_KEY and v != 2]  # ignore kernel autorepeat


def scenario(tx, rx, steps):
    """steps: list of (delay_s_before, code, val)."""
    drain(rx, 0.1)
    for delay, code, val in steps:
        time.sleep(delay)
        emit(tx, code, val)
    return keys_only(drain(rx, 0.4))


def check(name, got, want):
    ok = got == want
    print(("PASS " if ok else "FAIL ") + name)
    if not ok:
        print("   want:", want)
        print("   got :", got)
    return ok


def main():
    results = []
    tx = make_test_keyboard()
    print("virtual keyboard created")

    # ---------------- filter mode ----------------
    proc = subprocess.Popen([sys.executable, os.path.join(D, "..", "..", "system", "usr", "local", "bin", "xyno-kbd-guard"), "--name", NAME, "--mode", "filter",
                             "--threshold-ms", "30", "--no-notify", "--window-s", "2"],
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    time.sleep(1.5)
    node = g.find_event_node(NAME + " (debounced)")
    print("debounced device node:", node)
    if not node:
        print(proc.stdout.read() if proc.poll() is not None else "guard running but no clone found")
        proc.terminate(); return 1
    rx = os.open(node, os.O_RDWR | os.O_NONBLOCK)

    results.append(check("normal press/release passes", scenario(tx, rx, [(0, KEY_A, 1), (0.10, KEY_A, 0)]),
                         [(KEY_A, 1), (KEY_A, 0)]))
    results.append(check("single bounce (15 ms) is removed",
                         scenario(tx, rx, [(0.2, KEY_B, 1), (0.04, KEY_B, 0), (0.015, KEY_B, 1), (0.03, KEY_B, 0)]),
                         [(KEY_B, 1), (KEY_B, 0)]))
    results.append(check("bounce chain (10-12 ms gaps) collapses to one press",
                         scenario(tx, rx, [(0.2, KEY_C, 1), (0.03, KEY_C, 0), (0.01, KEY_C, 1), (0.01, KEY_C, 0),
                                           (0.012, KEY_C, 1), (0.04, KEY_C, 0)]),
                         [(KEY_C, 1), (KEY_C, 0)]))
    results.append(check("deliberate double press (80 ms gap) is kept",
                         scenario(tx, rx, [(0.2, KEY_D, 1), (0.09, KEY_D, 0), (0.08, KEY_D, 1), (0.09, KEY_D, 0)]),
                         [(KEY_D, 1), (KEY_D, 0), (KEY_D, 1), (KEY_D, 0)]))
    results.append(check("overlapping different keys (rollover) pass",
                         scenario(tx, rx, [(0.2, KEY_E, 1), (0.02, KEY_F, 1), (0.05, KEY_E, 0), (0.02, KEY_F, 0)]),
                         [(KEY_E, 1), (KEY_F, 1), (KEY_E, 0), (KEY_F, 0)]))
    results.append(check("held key then re-press well after release is kept",
                         scenario(tx, rx, [(0.2, KEY_A, 1), (0.5, KEY_A, 0), (0.2, KEY_A, 1), (0.1, KEY_A, 0)]),
                         [(KEY_A, 1), (KEY_A, 0), (KEY_A, 1), (KEY_A, 0)]))

    # LED forwarding: compositor writes LED to the clone -> must reach the (virtual) real keyboard
    drain(tx, 0.1)
    # Caps Lock LED: the desktop sets NumLock itself on every new keyboard, which would mask this write
    os.write(rx, g.EVENT.pack(0, 0, g.EV_LED, LED_CAPSL, 1) + g.EVENT.pack(0, 0, g.EV_SYN, 0, 0))
    leds = [(t, c, v) for t, c, v in drain(tx, 0.5) if t == g.EV_LED]
    results.append(check("LED state is forwarded to the real keyboard", (g.EV_LED, LED_CAPSL, 1) in leds, True))

    time.sleep(2.5)  # let a reporting window elapse
    proc.terminate()
    out = proc.communicate(timeout=10)[0]
    print("--- guard output (filter mode):"); print(out.strip())
    results.append(check("guard logged the chatter it removed", "chatter:" in out and "stopped; keyboard released" in out, True))
    os.close(rx)

    # ---------------- monitor mode: must NOT alter events ----------------
    time.sleep(0.5)
    proc = subprocess.Popen([sys.executable, os.path.join(D, "..", "..", "system", "usr", "local", "bin", "xyno-kbd-guard"), "--name", NAME, "--mode", "monitor",
                             "--no-notify", "--window-s", "2"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    time.sleep(1.0)
    ev_node = g.find_event_node(NAME)
    obs = os.open(ev_node, os.O_RDONLY | os.O_NONBLOCK)  # nothing grabbed: another reader still sees raw events
    drain(obs, 0.1)
    for delay, code, val in [(0.2, KEY_B, 1), (0.04, KEY_B, 0), (0.015, KEY_B, 1), (0.03, KEY_B, 0)]:
        time.sleep(delay); emit(tx, code, val)
    raw = keys_only(drain(obs, 0.4))
    results.append(check("monitor mode leaves the raw stream untouched (second reader still sees all 4 events)", raw,
                         [(KEY_B, 1), (KEY_B, 0), (KEY_B, 1), (KEY_B, 0)]))
    time.sleep(2.5)
    state = json.load(open(g.STATE_FILE))
    results.append(check("monitor counted exactly 1 false repeat", (state["bounces_total"], state["mode"]), (1, "monitor")))
    proc.terminate(); proc.communicate(timeout=10)
    os.close(obs); os.close(tx)

    print("\n%d/%d checks passed" % (sum(results), len(results)))
    return 0 if all(results) else 1


if __name__ == "__main__":
    sys.exit(main())
