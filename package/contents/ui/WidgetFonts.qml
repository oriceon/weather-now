import QtQuick

/**
 * Inter, the font of the widget unless another one is chosen, comes with it, so that it looks the
 * same on every desktop: the weights the text is drawn in, and the display cut of the big
 * temperature. Made by tools/fonts/subset.py. A font loaded like this belongs to the whole Plasma
 * process, under its own name, and shows up in the font dialog of the settings too.
 */
QtObject {
    /** The family of the text; empty until it is loaded, and if it cannot be. */
    readonly property string text: regular.status === FontLoader.Ready ? regular.name : ""
    /** The family of the big numbers; empty likewise. */
    readonly property string display: displaySemiBold.status === FontLoader.Ready ? displaySemiBold.name : ""

    readonly property FontLoader regular: FontLoader {
        source: "../fonts/Inter-Regular.ttf"
    }
    readonly property FontLoader semiBold: FontLoader {
        source: "../fonts/Inter-SemiBold.ttf"
    }
    readonly property FontLoader bold: FontLoader {
        source: "../fonts/Inter-Bold.ttf"
    }
    readonly property FontLoader displaySemiBold: FontLoader {
        source: "../fonts/InterDisplay-SemiBold.ttf"
    }
}
