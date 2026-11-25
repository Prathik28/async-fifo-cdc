#!/usr/bin/env python3
"""Draw selected signals from the waveform testbench's VCD as an SVG.

Usage: vcd2svg.py input.vcd output.svg
"""
import sys
from xml.sax.saxutils import escape

WRITE, READ, BAD, INK, MUTE = "#1d4ed8", "#047857", "#b91c1c", "#111827", "#6b7280"
# (signal, colour, kind); None starts a new group.
ROWS = [
    ("wclk", WRITE, "bit"), ("winc", WRITE, "bit"), ("wdata", WRITE, "bus"),
    ("wfull", WRITE, "bit"), ("woverflow", BAD, "bit"), ("wlevel", WRITE, "bus"),
    None,
    ("rclk", READ, "bit"), ("rinc", READ, "bit"), ("rdata", READ, "bus"),
    ("rempty", READ, "bit"), ("runderflow", BAD, "bit"), ("rlevel", READ, "bus"),
]
WIDTH, LEFT, RIGHT, TOP, ROW, HIGH, GAP = 1200, 110, 16, 46, 38, 22, 20


def read_vcd(path):
    """Return ({name: [(time, value), ...]}, first_time, last_time)."""
    ids, changes, now, times = {}, {}, 0, []
    with open(path) as handle:
        for line in handle:
            parts = line.split()
            if not parts:
                continue
            if parts[0] == "$var":
                ids.setdefault(parts[3], []).append(parts[4])
                changes.setdefault(parts[4], [])
                continue
            if parts[0].startswith("#"):
                now = int(parts[0][1:])
                times.append(now)
                continue
            if parts[0][0] in "bB" and len(parts) == 2:
                value, key = parts[0][1:], parts[1]
            elif parts[0][0] in "01xXzZ" and len(parts) == 1:
                value, key = parts[0][0], parts[0][1:]
            else:
                continue
            for name in ids.get(key, []):
                if changes[name] and changes[name][-1][0] == now:
                    changes[name][-1] = (now, value)
                else:
                    changes[name].append((now, value))
    return changes, times[0], times[-1]


def segments(series, start, end):
    """Turn a change list into [(t0, t1, value)] with equal neighbours merged."""
    merged = []
    for time, value in series:
        if not merged or merged[-1][1] != value:
            merged.append((time, value))
    ends = [t for t, _ in merged[1:]] + [end]
    return [(max(t, start), e, v) for (t, v), e in zip(merged, ends) if e > start]


def main(source, target):
    changes, start, end = read_vcd(source)
    missing = [r[0] for r in ROWS if r and r[0] not in changes]
    if missing:
        sys.exit(f"signals missing from VCD: {missing}")

    def x(t):
        return round(LEFT + (WIDTH - LEFT - RIGHT) * (t - start) / (end - start), 2)

    out, y = [], TOP

    def text(tx, ty, s, size=13, colour=INK, anchor="middle", bold=False):
        out.append(f'<text x="{tx}" y="{ty}" font-family="SFMono-Regular,Menlo,Consolas,monospace" '
                   f'font-size="{size}" fill="{colour}" text-anchor="{anchor}" '
                   f'font-weight="{700 if bold else 400}">{escape(s)}</text>')

    empty = segments(changes["rempty"], start, end)
    for row in ROWS:
        if row is None:
            out.append(f'<line x1="12" y1="{y + 6}" x2="{WIDTH - 12}" y2="{y + 6}" '
                       f'stroke="#d1d5db" stroke-dasharray="6 5"/>')
            y += GAP
            continue
        name, colour, kind = row
        low, high, mid = y + HIGH, y, y + HIGH / 2
        text(LEFT - 10, mid + 5, name, 13, colour, "end", True)
        series = segments(changes[name], start, end)
        if kind == "bit":
            if name in ("woverflow", "runderflow"):
                for t0, t1, v in series:
                    if v == "1":
                        out.append(f'<rect x="{x(t0)}" y="{high - 4}" width="{round(x(t1) - x(t0), 2)}" '
                                   f'height="{HIGH + 8}" fill="#fee2e2"/>')
            points = []
            for t0, t1, v in series:
                level = high if v == "1" else low
                points += [f"{x(t0)},{level}", f"{x(t1)},{level}"]
            out.append(f'<polyline points="{" ".join(points)}" fill="none" stroke="{colour}" stroke-width="1.6"/>')
        else:
            if name == "rdata":
                # rdata means something only while rempty is low (first-word fall-through).
                valid = []
                for t0, t1, v in series:
                    for e0, e1, flag in empty:
                        a, b = max(t0, e0), min(t1, e1)
                        if flag == "0" and a < b:
                            valid.append((a, b, v))
                cursor, series = start, []
                for a, b, v in valid:
                    if a > cursor:
                        series.append((cursor, a, None))
                    series.append((a, b, v))
                    cursor = b
                if cursor < end:
                    series.append((cursor, end, None))
            for t0, t1, v in series:
                a, b = x(t0), x(t1)
                s = min(3, (b - a) / 2)
                fill = "#f3f4f6" if v is None else "#ffffff"
                edge = "#9ca3af" if v is None else colour
                out.append(f'<path d="M{a},{mid} L{a + s},{high} L{b - s},{high} L{b},{mid} '
                           f'L{b - s},{low} L{a + s},{low} Z" fill="{fill}" stroke="{edge}" stroke-width="1.3"/>')
                if v is not None and b - a > 18:
                    number = int(v, 2)
                    label = f"{number:02X}" if name.endswith("data") else str(number)
                    text(round((a + b) / 2, 2), mid + 4.5, label, 12)
                elif v is None and b - a > 70:
                    text(round((a + b) / 2, 2), mid + 4.5, "not valid", 11, MUTE)
        y += ROW

    height = y + 26
    head = [
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {WIDTH} {height}" width="{WIDTH}" height="{height}">',
        "<title>async_fifo simulation: fill, overflow, drain and underflow</title>",
        f'<rect width="{WIDTH}" height="{height}" fill="#ffffff"/>',
    ]
    body, out = out, head
    text(12, 24, "Fill, overflow, drain, underflow: depth 4, wclk 10 ns, rclk 16 ns", 15, INK, "start", True)
    text(WIDTH - 12, height - 10, f"Icarus Verilog simulation, {(end - start) / 1000:.0f} ns shown; data in hex",
         11, MUTE, "end")
    with open(target, "w") as handle:
        handle.write("\n".join(out + body + ["</svg>"]) + "\n")


if __name__ == "__main__":
    main(*sys.argv[1:3])
