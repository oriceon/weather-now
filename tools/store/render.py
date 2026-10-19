"""
Renders a QML file to a PNG with a transparent background.

    render.py FILE.qml OUT.png [--frames N --fps F]

With --frames, the root item has to have a `phase` property, 0…1: it is stepped through N values
and each is saved as OUT-0000.png…, with OUT-times.txt, for animate.py.
"""
import argparse
from pathlib import Path

from PySide6.QtCore import QTimer, QUrl, Qt
from PySide6.QtGui import QGuiApplication
from PySide6.QtQuick import QQuickView

parser = argparse.ArgumentParser()
parser.add_argument("qml")
parser.add_argument("out")
parser.add_argument("--frames", type=int, default=0)
parser.add_argument("--fps", type=int, default=24)
arguments = parser.parse_args()

app = QGuiApplication([])
view = QQuickView()
view.setColor(Qt.transparent)
view.setSource(QUrl.fromLocalFile(arguments.qml))

if view.status() != QQuickView.Ready:
    print([error.toString() for error in view.errors()])
    raise SystemExit(1)

view.show()
stem = str(Path(arguments.out).with_suffix(""))
saved = []


def save():
    image = view.grabWindow()

    if not arguments.frames:
        print(arguments.out, image.width(), image.height(), image.save(arguments.out))
        app.quit()
        return

    image.save(f"{stem}-{len(saved):04d}.png")
    saved.append(len(saved) * 1000 // arguments.fps)

    if len(saved) < arguments.frames:
        view.rootObject().setProperty("phase", len(saved) / arguments.frames)
        # The Canvas paints on the next turn of the event loop.
        QTimer.singleShot(60, save)
    else:
        Path(f"{stem}-times.txt").write_text("".join(f"{time}\n" for time in saved))
        print(f"{stem}-0000.png… {len(saved)} frames")
        app.quit()


QTimer.singleShot(800, save)
app.exec()
