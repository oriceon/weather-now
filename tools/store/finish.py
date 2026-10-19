"""Crops the desktop stand-in off a viewer screenshot and makes the corners outside the widget transparent."""
import sys
from PySide6.QtCore import QRectF, Qt
from PySide6.QtGui import QGuiApplication, QImage, QPainter, QPainterPath

app = QGuiApplication(sys.argv[:1])
source, target, margin, radius = sys.argv[1], sys.argv[2], int(sys.argv[3]), float(sys.argv[4])
image = QImage(source).convertToFormat(QImage.Format_ARGB32)
cropped = image.copy(margin, margin, image.width() - 2 * margin, image.height() - 2 * margin)
result = QImage(cropped.size(), QImage.Format_ARGB32)
result.fill(Qt.transparent)
painter = QPainter(result)
painter.setRenderHint(QPainter.Antialiasing)
path = QPainterPath()
path.addRoundedRect(QRectF(0, 0, cropped.width(), cropped.height()), radius, radius)
painter.setClipPath(path)
painter.drawImage(0, 0, cropped)
painter.end()
print(target, result.width(), result.height(), result.save(target))
