import QtQuick

QtObject {
    enum FormFactor {
        Planar,
        MediaCenter,
        Horizontal,
        Vertical,
        Application
    }

    enum BackgroundHints {
        NoBackground = 0,
        StandardBackground = 1,
        TranslucentBackground = 2,
        ShadowBackground = 4,
        ConfigurableBackground = 8,
        DefaultBackground = 1
    }
}
