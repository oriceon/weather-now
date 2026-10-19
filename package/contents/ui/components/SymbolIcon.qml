import QtQuick

/** A Meteocons icon that is not a weather condition: wind, humidity, a phase of the moon… */
Image {
    /** File name of the icon in contents/icons/static, without extension. */
    required property string name

    source: `../../icons/static/${name}.svg`
    sourceSize: Qt.size(width, height)
    fillMode: Image.PreserveAspectFit
}
