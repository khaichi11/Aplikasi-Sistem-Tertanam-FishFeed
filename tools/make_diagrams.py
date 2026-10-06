#!/usr/bin/env python3
"""Render the documentation diagrams in docs/images/.

Diagrams use the app's ocean palette and fonts so the docs look like the app.
Usage (from the repository root): python3 tools/make_diagrams.py
"""

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
FONTS = ROOT / "embed/assets/fonts"
OUT = ROOT / "docs/images"
SCALE = 2  # Render at 2x for sharp images on high-density screens.

# Same flat palette as the app: petrol water, amber feed, calm neutrals.
BG = (244, 246, 247)
CARD = (255, 255, 255)
LINE = (227, 232, 234)
INK = (20, 33, 43)
MUTED = (93, 107, 117)
OCEAN = (14, 110, 126)
OCEAN_DEEP = (10, 79, 92)
SKY = (227, 239, 241)
TEAL = (47, 158, 107)
TEAL_SOFT = (227, 243, 234)
CORAL = (217, 154, 30)
CORAL_SOFT = (252, 241, 222)
AMBER = (217, 154, 30)
PURPLE = (93, 107, 117)
BROWN = (138, 90, 59)
AMBER_INK = (138, 90, 14)


def font(name, size):
    return ImageFont.truetype(str(FONTS / f"{name}.ttf"), size * SCALE)


TITLE = font("Poppins-SemiBold", 30)
H2 = font("Poppins-SemiBold", 20)
H3 = font("Poppins-SemiBold", 16)
BODY = font("Inter-Regular", 15)
BODY_BOLD = font("Inter-SemiBold", 15)
SMALL = font("Inter-Regular", 13)
SMALL_BOLD = font("Inter-SemiBold", 13)
MONO = font("Inter-Medium", 14)


class Canvas:
    def __init__(self, width, height):
        self.image = Image.new("RGB", (width * SCALE, height * SCALE), BG)
        self.draw = ImageDraw.Draw(self.image)

    @staticmethod
    def s(*values):
        return [v * SCALE for v in values]

    def card(self, x, y, w, h, fill=CARD, outline=LINE, radius=22):
        self.draw.rounded_rectangle(self.s(x, y, x + w, y + h), radius=radius * SCALE,
                                    fill=fill, outline=outline, width=2 * SCALE if outline else 0)

    def text(self, x, y, value, fnt=BODY, fill=INK, anchor="la"):
        self.draw.text(self.s(x, y), value, font=fnt, fill=fill, anchor=anchor)

    def pill(self, x, y, value, fg, bg, fnt=SMALL_BOLD):
        w = self.draw.textlength(value, font=fnt) / SCALE + 24
        self.draw.rounded_rectangle(self.s(x, y, x + w, y + 26), radius=13 * SCALE, fill=bg)
        self.text(x + 12, y + 13, value, fnt, fg, "lm")
        return w

    def arrow(self, points, color, width=3, head=12, dashed=False):
        pts = [(px * SCALE, py * SCALE) for px, py in points]
        for (x1, y1), (x2, y2) in zip(pts, pts[1:]):
            if dashed:
                length = math.hypot(x2 - x1, y2 - y1)
                steps = int(length // (14 * SCALE))
                for i in range(0, steps, 2):
                    a, b = i / steps, min((i + 1) / steps, 1)
                    self.draw.line([(x1 + (x2 - x1) * a, y1 + (y2 - y1) * a),
                                    (x1 + (x2 - x1) * b, y1 + (y2 - y1) * b)],
                                   fill=color, width=width * SCALE)
            else:
                self.draw.line([(x1, y1), (x2, y2)], fill=color, width=width * SCALE)
        (x1, y1), (x2, y2) = pts[-2], pts[-1]
        angle = math.atan2(y2 - y1, x2 - x1)
        h = head * SCALE
        self.draw.polygon([(x2, y2),
                           (x2 - h * math.cos(angle - 0.45), y2 - h * math.sin(angle - 0.45)),
                           (x2 - h * math.cos(angle + 0.45), y2 - h * math.sin(angle + 0.45))],
                          fill=color)

    def icon_circle(self, cx, cy, r, color, symbol):
        self.draw.ellipse(self.s(cx - r, cy - r, cx + r, cy + r), fill=color)
        self.text(cx, cy, symbol, font("Poppins-SemiBold", int(r * 0.9)), CARD, "mm")

    def save(self, name):
        OUT.mkdir(parents=True, exist_ok=True)
        self.image.save(OUT / name, optimize=True)
        print("wrote", OUT / name)


def header(c, title, subtitle):
    c.text(48, 44, title, TITLE)
    c.text(48, 92, subtitle, BODY, MUTED)


def architecture():
    c = Canvas(1400, 720)
    header(c, "Arsitektur FishFeed",
           "Aplikasi dan perangkat tidak terhubung langsung. Semua data lewat Firebase.")
    cols = [
        (48, "Aplikasi FishFeed", "Flutter · Android & iOS", OCEAN, "A",
         ["Dashboard & peringatan", "Beri makan sekarang", "Atur jadwal otomatis",
          "Riwayat & grafik mingguan", "Kelola perangkat"]),
        (520, "Firebase", "Backend cloud", OCEAN_DEEP, "F",
         ["Authentication", "Realtime Database", "  telemetri, perintah, jadwal", "Cloud Firestore",
          "  daftar perangkat pengguna"]),
        (992, "Perangkat ESP32", "Firmware Arduino + FreeRTOS", TEAL, "E",
         ["Sensor pakan (HC-SR04)", "Sensor kekeruhan air", "Pembacaan baterai",
          "Servo katup pakan", "Jam RTC DS3231"]),
    ]
    for x, title, sub, color, symbol, items in cols:
        c.card(x, 150, 360, 420)
        c.icon_circle(x + 52, 206, 28, color, symbol)
        c.text(x + 96, 192, title, H2)
        c.text(x + 96, 222, sub, SMALL, MUTED)
        y = 276
        for item in items:
            if item.startswith("  "):
                c.text(x + 58, y - 8, item.strip(), SMALL, MUTED)
                y += 26
                continue
            c.draw.ellipse(c.s(x + 34, y + 2, x + 44, y + 12), fill=color)
            c.text(x + 58, y - 3, item, BODY)
            y += 40
    for x0, x1 in ((408, 520), (880, 992)):
        c.arrow([(x0 + 8, 300), (x1 - 8, 300)], CORAL, 4, 14)
        c.arrow([(x1 - 8, 420), (x0 + 8, 420)], OCEAN, 4, 14)
    c.pill(414, 262, "perintah", AMBER_INK, CORAL_SOFT)
    c.pill(414, 436, "telemetri", OCEAN, SKY)
    c.pill(886, 262, "perintah", AMBER_INK, CORAL_SOFT)
    c.pill(886, 436, "telemetri", OCEAN, SKY)
    c.card(48, 600, 1304, 76, fill=CORAL_SOFT, outline=None, radius=18)
    c.text(76, 638, "Mode demo:", BODY_BOLD, AMBER_INK, "lm")
    c.text(176, 638, "tanpa konfigurasi Firebase, aplikasi memakai perangkat simulasi di memori. "
           "Tidak ada kunci API di repositori.", BODY, INK, "lm")
    c.save("architecture.png")


def feed_flow():
    c = Canvas(1400, 900)
    header(c, "Alur pemberian pakan",
           "Dari tombol di aplikasi sampai pakan jatuh ke akuarium.")
    lanes = [(250, "Aplikasi", OCEAN), (700, "Firebase", OCEAN_DEEP), (1150, "ESP32", TEAL)]
    for x, title, color in lanes:
        c.card(x - 130, 140, 260, 60, fill=color, outline=None, radius=16)
        c.text(x, 170, title, H3, CARD, "mm")
        c.arrow([(x, 210), (x, 860)], LINE, 2, 1, dashed=True)
    steps = [
        (250, 700, 270, "1", "Tulis perintah", "current_command  ·  status: pending", CORAL),
        (1150, 700, 390, "2", "Cek perintah tiap 10 detik", "membaca status = pending", TEAL),
        (1150, 1150, 500, "3", "Servo membuka katup", "satu porsi pakan dijatuhkan", TEAL),
        (1150, 700, 600, "4", "Tandai selesai", "status = done", TEAL),
        (700, 250, 710, "5", "Aplikasi menerima perubahan", "menampilkan \"Pakan sudah diberikan!\"", OCEAN),
    ]
    for x_from, x_to, y, number, title, detail, color in steps:
        if x_from != x_to:
            c.arrow([(x_from, y), (x_to, y)], color, 3, 12)
            mid = (x_from + x_to) / 2
        else:
            c.draw.ellipse(c.s(x_from - 9, y - 9, x_from + 9, y + 9), fill=color)
            mid = x_from - 170
        box_x = min(max(mid - 210, 40), 1400 - 460)
        c.card(box_x, y + 16, 420, 70, radius=14)
        c.icon_circle(box_x + 30, y + 51, 15, color, number)
        c.text(box_x + 56, y + 30, title, BODY_BOLD)
        c.text(box_x + 56, y + 54, detail.replace("\n", "  "), SMALL, MUTED)
    c.card(48, 818, 1304, 56, fill=TEAL_SOFT, outline=None, radius=16)
    c.text(76, 846, "Jadwal otomatis berjalan di perangkat dengan jam RTC, lalu dicatat ke "
           "activity/{id} sehingga muncul di riwayat aplikasi.", BODY, INK, "lm")
    c.save("feed-flow.png")


def wiring():
    c = Canvas(1400, 860)
    header(c, "Rangkaian perangkat",
           "Sambungan sinyal ESP32. VCC dan GND setiap modul ke catu daya yang sesuai.")
    # ESP32 board.
    bx, by, bw, bh = 120, 170, 300, 600
    c.card(bx, by, bw, bh, fill=(32, 41, 56), outline=None, radius=20)
    c.card(bx + 70, by + 30, 160, 110, fill=(57, 69, 87), outline=None, radius=10)
    c.text(bx + 150, by + 72, "ESP32", H2, CARD, "mm")
    c.text(bx + 150, by + 104, "DevKit V1", SMALL, (190, 200, 215), "mm")
    pins = [("GPIO 21", 260), ("GPIO 22", 320), ("GPIO 5", 400), ("GPIO 18", 460),
            ("GPIO 34", 540), ("GPIO 32", 620), ("GPIO 13", 700)]
    pin_y = {}
    for name, y in pins:
        c.draw.rounded_rectangle(c.s(bx + bw - 26, y - 9, bx + bw + 4, y + 9), radius=4 * SCALE, fill=(212, 175, 55))
        c.text(bx + bw - 40, y, name, SMALL_BOLD, CARD, "rm")
        pin_y[name] = y
    modules = [
        ("RTC DS3231", "Sumber waktu jadwal", PURPLE, [("SDA", "GPIO 21"), ("SCL", "GPIO 22")], 186),
        ("Sensor ultrasonik HC-SR04", "Jarak permukaan pakan", OCEAN, [("TRIG", "GPIO 5"), ("ECHO", "GPIO 18")], 346),
        ("Sensor kekeruhan", "Kejernihan air (NTU)", TEAL, [("AOUT", "GPIO 34")], 506),
        ("Pembagi tegangan baterai", "Persentase baterai", AMBER, [("OUT", "GPIO 32")], 596),
        ("Servo", "Katup penjatuh pakan", BROWN, [("SIGNAL", "GPIO 13")], 686),
    ]
    mx = 820
    for title, sub, color, signals, y in modules:
        h = 140 if len(signals) > 1 else 70
        c.card(mx, y - 10, 500, h)
        c.draw.rounded_rectangle(c.s(mx, y - 10, mx + 10, y - 10 + h), radius=4 * SCALE, fill=color)
        c.text(mx + 30, y + 14, title, H3)
        c.text(mx + 30, y + 40, sub, SMALL, MUTED)
        for i, (label, pin) in enumerate(signals):
            target_y = pin_y[pin]
            ly = y + 14 + i * 40 if len(signals) > 1 else y + 25
            c.text(mx + 480, ly, label, SMALL_BOLD, color, "rm")
            elbow = 600 + i * 30
            c.draw.line(c.s(bx + bw + 4, target_y, elbow, target_y), fill=color, width=4 * SCALE)
            c.draw.line(c.s(elbow, target_y, elbow, ly), fill=color, width=4 * SCALE)
            c.draw.line(c.s(elbow, ly, mx, ly), fill=color, width=4 * SCALE)
            c.draw.ellipse(c.s(mx - 6, ly - 6, mx + 6, ly + 6), fill=color)
    c.card(48, 790, 1304, 52, fill=CORAL_SOFT, outline=None, radius=16)
    c.text(76, 816, "Penting: pin ECHO HC-SR04 bertegangan 5 V. Pasang pembagi tegangan agar aman "
           "untuk ESP32, dan beri servo catu daya 5 V tersendiri.", SMALL, INK, "lm")
    c.save("wiring.png")


def data_structure():
    c = Canvas(1400, 820)
    header(c, "Struktur data Firebase",
           "Kontrak data antara aplikasi dan firmware. Ubah keduanya bersamaan.")
    c.card(48, 150, 820, 620)
    c.icon_circle(92, 196, 22, OCEAN_DEEP, "R")
    c.text(128, 196, "Realtime Database", H2, INK, "lm")
    rows = [
        (0, "devices/{id}", "", None),
        (1, "status/online", "bool · ditulis firmware", TEAL),
        (1, "sensors", "turbidity, distance_cm, battery_percent,", TEAL),
        (2, "", "battery_voltage, timestamp", None),
        (1, "info/name", "nama tampilan · diubah aplikasi", OCEAN),
        (0, "commands/{id}/current_command", "type, status, created_at, initiated_by", CORAL),
        (0, "schedules/{id}", "active · entries/{key}: time, enabled, last_run", CORAL),
        (0, "activity/{id}/{pushId}", "type, mode, timestamp, source", PURPLE),
    ]
    y = 256
    for depth, key, desc, color in rows:
        x = 88 + depth * 36
        if not key:
            y -= 26
        if key:
            if depth:
                c.draw.line(c.s(x - 22, y - 30, x - 22, y), fill=LINE, width=2 * SCALE)
                c.draw.line(c.s(x - 22, y, x - 6, y), fill=LINE, width=2 * SCALE)
            c.text(x, y, key, MONO, INK, "lm")
        if desc:
            dx = 470
            if color:
                c.draw.ellipse(c.s(dx - 18, y - 5, dx - 8, y + 5), fill=color)
            c.text(dx, y, desc, SMALL, MUTED, "lm")
        y += 60 if key else 34
    legend = [(TEAL, "ditulis firmware"), (CORAL, "ditulis aplikasi, dibaca firmware"),
              (PURPLE, "ditulis keduanya"), (OCEAN, "diubah aplikasi")]
    lx = 88
    for color, label in legend:
        c.draw.ellipse(c.s(lx, 726, lx + 12, 738), fill=color)
        c.text(lx + 20, 732, label, SMALL, MUTED, "lm")
        lx += c.draw.textlength(label, font=SMALL) / SCALE + 60
    c.card(900, 150, 452, 300)
    c.icon_circle(944, 196, 22, OCEAN, "F")
    c.text(980, 196, "Cloud Firestore", H2, INK, "lm")
    c.text(940, 256, "users/{uid}", MONO, INK, "lm")
    for i, (field, kind) in enumerate([("email", "string"), ("createdAt", "timestamp"),
                                        ("devices", "map: {id: paired_at, role}")]):
        yy = 306 + i * 44
        c.draw.line(c.s(918, yy - 30, 918, yy), fill=LINE, width=2 * SCALE)
        c.draw.line(c.s(918, yy, 934, yy), fill=LINE, width=2 * SCALE)
        c.text(940, yy, field, MONO, INK, "lm")
        c.text(1080, yy, kind, SMALL, MUTED, "lm")
    c.card(900, 480, 452, 290, fill=SKY, outline=None)
    c.text(928, 520, "Contoh jadwal", H3)
    sample = ['{', '  "active": true,', '  "entries": {', '    "pagi": {', '      "time": "07:00",',
              '      "enabled": true,', '      "last_run": "2026-06-10"', '    }', '  }', '}']
    for i, line in enumerate(sample):
        c.text(928, 556 + i * 21, line, SMALL, OCEAN_DEEP)
    c.save("data-structure.png")


if __name__ == "__main__":
    architecture()
    feed_flow()
    wiring()
    data_structure()
