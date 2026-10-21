pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../../code/dates.mjs" as Dates
import "../../code/i18n.mjs" as I18n
import "../../code/links.mjs" as Links
import "../../code/radar.mjs" as Radar

/**
 * The rain radar around the place: the images of the last two hours, one after another, over the
 * relief of the land with its coasts, borders and the names of places; see code/radar.mjs. The
 * images load one by one, the newest first, within the requests RainViewer allows in a minute, and
 * only while the map is on screen. The wheel or the buttons bring it closer or farther; the slider
 * stops on one image.
 *
 * What came is kept: a new index brings only its newest image, and a map resized within its tiles
 * only moves them. Images do not stay in the cache of Qt once they are let go, so each one dropped
 * would be asked for again.
 */
Item {
    id: map

    required property real latitude
    required property real longitude
    /** What to add to UTC for the clock of the place. */
    required property int utcOffsetSeconds
    required property string language
    required property var typography
    /** Loads and moves only while true: while the map is on screen. */
    property bool active: true
    /** Whether the map has been on screen at all: before, not even its tiles are asked for. */
    property bool opened: false
    property int zoom: Radar.DEFAULT_ZOOM

    /** `{ host, frames }`, see parseRadarIndex(); null until it has come. */
    property var radarIndex: null
    property double indexLoadedAt: 0
    property bool failed: false
    /** How many images have been let load, of those in `layers`. */
    property int admitted: 0
    /** The image on screen. */
    property int shown: 0
    property bool playing: true

    readonly property var frames: radarIndex !== null ? radarIndex.frames : []
    readonly property var centre: Radar.tileOf(latitude, longitude, zoom)
    /**
     * The tiles of the map and of the radar, laid out for the size the map had then, `laidOut`: a
     * new size that needs no other tiles only shifts them, see `shiftX`, and asks for nothing.
     */
    property var mapTiles: []
    property var radarTiles: []
    property size laidOut: Qt.size(0, 0)
    readonly property real shiftX: Math.round((width - laidOut.width) / 2)
    readonly property real shiftY: Math.round((height - laidOut.height) / 2)
    readonly property bool complete: frames.length > 0 && admitted >= frames.length
    readonly property real gridUnit: Kirigami.Units.gridUnit * typography.size / Kirigami.Theme.defaultFont.pointSize

    function loadIndex(): void {
        const request = new XMLHttpRequest();

        // The minute is spent, by this radar or another on the desktop: a moment later, then.
        if (!Radar.spend(1)) {
            indexRetry.start();

            return;
        }

        request.onreadystatechange = () => {
            if (request.readyState !== XMLHttpRequest.DONE) {
                return;
            }

            try {
                map.takeIndex(Radar.parseRadarIndex(JSON.parse(request.responseText)));
                map.indexLoadedAt = Date.now();
                map.failed = false;
            } catch (error) {
                map.failed = map.radarIndex === null;
                // Not ten minutes later, with the next index: a moment later, as when the minute was spent.
                indexRetry.start();
            }
        };

        request.open("GET", Radar.RADAR_INDEX_URL);
        request.send();
    }

    /**
     * The images of a new index, in `layers`, the ones already there kept with their tiles: every
     * ten minutes, one new image comes and the oldest goes.
     */
    function takeIndex(index: var): void {
        const paths = index.frames.map(frame => frame.path);

        if (radarIndex === null || radarIndex.host !== index.host) {
            layers.clear();
        }

        for (let row = layers.count - 1; row >= 0; row--) {
            if (paths.indexOf(layers.get(row).path) === -1) {
                layers.remove(row);
            }
        }

        // What is left is in the order of the index: the new ones go in between, where they belong.
        index.frames.forEach((frame, row) => {
            if (row >= layers.count || layers.get(row).path !== frame.path) {
                layers.insert(row, { path: frame.path, admitted: false });
            }
        });

        radarIndex = index;
        admitted = 0;

        for (let row = 0; row < layers.count; row++) {
            admitted += layers.get(row).admitted ? 1 : 0;
        }

        shown = frames.length - 1;
        admitNext();
    }

    /** Lets go of every image, as another zoom or another stretch of the map needs other tiles. */
    function forgetImages(): void {
        for (let row = 0; row < layers.count; row++) {
            layers.setProperty(row, "admitted", false);
        }

        admitted = 0;
        shown = frames.length - 1;
    }

    /** Lets the newest image not yet in load, if the minute has room for its tiles. */
    function admitNext(): void {
        if (!active || admitted >= layers.count) {
            return;
        }

        for (let row = layers.count - 1; row >= 0; row--) {
            if (!layers.get(row).admitted) {
                if (Radar.spend(radarTiles.length)) {
                    layers.setProperty(row, "admitted", true);
                    admitted++;
                }

                return;
            }
        }
    }

    /** The tiles for the size and the zoom of the map now; the images go only when the tiles change. */
    function layOut(): void {
        if (!opened || width <= 0 || height <= 0) {
            return;
        }

        const tiles = Radar.tilesAround({ x: centre.x / 2, y: centre.y / 2 }, zoom - 1, width, height, Radar.RADAR_TILE);
        const ground = Radar.tilesAround(centre, zoom, width, height, Radar.MAP_TILE);

        if (Radar.tileKeys(tiles) === Radar.tileKeys(radarTiles) && Radar.tileKeys(ground) === Radar.tileKeys(mapTiles)) {
            return;
        }

        forgetImages();
        laidOut = Qt.size(width, height);
        mapTiles = ground;
        radarTiles = tiles;
        admitNext();
    }

    function zoomBy(step: int): void {
        const next = Math.max(Radar.MIN_ZOOM, Math.min(Radar.MAX_ZOOM, zoom + step));

        if (next !== zoom) {
            // Before the zoom changes: the images let in, and the map, would otherwise ask at once for
            // the tiles of the old zoom at the new one.
            forgetImages();
            mapTiles = [];
            radarTiles = [];
            zoom = next;
            layOut();
        }
    }

    clip: true
    Accessible.role: Accessible.Graphic
    Accessible.name: I18n.t(language, "rain.radar")

    onActiveChanged: {
        opened = opened || active;
        layOut();

        if (active && (radarIndex === null || Date.now() - indexLoadedAt > Radar.INDEX_LIFETIME)) {
            loadIndex();
        }
    }
    Component.onCompleted: {
        if (active) {
            opened = true;
            layOut();
            loadIndex();
        }
    }
    onWidthChanged: resized.restart()
    onHeightChanged: resized.restart()
    onCentreChanged: resized.restart()

    ListModel {
        id: layers
    }

    Timer {
        id: indexRetry

        interval: 30 * 1000

        onTriggered: {
            if (map.active) {
                map.loadIndex();
            }
        }
    }

    // A new size may bring new tiles at the edges: looked at once it has settled.
    Timer {
        id: resized

        interval: 400

        onTriggered: map.layOut()
    }

    // Ten minutes out of sight, the images are let go: by then a new index brings others anyway.
    Timer {
        interval: Radar.INDEX_LIFETIME
        running: !map.active && map.admitted > 0

        onTriggered: map.forgetImages()
    }

    // The next image loads a moment after the one before it.
    Timer {
        interval: 900
        repeat: true
        running: map.active && map.frames.length > 0 && !map.complete

        onTriggered: map.admitNext()
    }

    // RainViewer adds an image every ten minutes.
    Timer {
        interval: Radar.INDEX_LIFETIME
        repeat: true
        running: map.active

        onTriggered: map.loadIndex()
    }

    // Once all have come, the images play in turn, lingering on the newest.
    Timer {
        interval: map.shown === map.frames.length - 1 ? 1800 : 550
        repeat: true
        running: map.active && map.playing && map.complete

        onTriggered: map.shown = (map.shown + 1) % map.frames.length
    }

    // The sea, until the relief has come.
    Rectangle {
        anchors.fill: parent
        color: "#0c1a2b"
    }

    component Laid: Item {
        x: map.shiftX
        y: map.shiftY
    }

    Laid {
        Repeater {
            model: map.mapTiles

            delegate: Image {
                required property var modelData

                x: modelData.left
                y: modelData.top
                width: Radar.MAP_TILE
                height: Radar.MAP_TILE
                asynchronous: true
                source: Radar.mapTileUrl("relief", map.zoom, modelData)
            }
        }
    }

    // Darker, so that the rain stands out.
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.3
    }

    Laid {
        Repeater {
            model: map.mapTiles

            delegate: Image {
                required property var modelData

                x: modelData.left
                y: modelData.top
                width: Radar.MAP_TILE
                height: Radar.MAP_TILE
                asynchronous: true
                opacity: 0.8
                source: Radar.mapTileUrl("borders", map.zoom, modelData)
            }
        }
    }

    // One layer for each image, only the one shown is seen; those let load wait in the others.
    Laid {
        Repeater {
            model: layers

            delegate: Item {
                id: frame

                required property int index
                required property string path
                required property bool admitted

                visible: index === map.shown

                Repeater {
                    model: frame.admitted ? map.radarTiles : []

                    delegate: Image {
                        required property var modelData

                        x: modelData.left
                        y: modelData.top
                        width: Radar.RADAR_TILE
                        height: Radar.RADAR_TILE
                        asynchronous: true
                        opacity: 0.85
                        source: Radar.radarTileUrl(map.radarIndex, { path: frame.path }, map.zoom - 1, modelData)
                    }
                }
            }
        }
    }

    Laid {
        Repeater {
            model: map.mapTiles

            delegate: Image {
                required property var modelData

                x: modelData.left
                y: modelData.top
                width: Radar.MAP_TILE
                height: Radar.MAP_TILE
                asynchronous: true
                source: Radar.mapTileUrl("names", map.zoom, modelData)
            }
        }
    }

    // The place, in the middle, with a ring that spreads from it.
    Item {
        x: map.width / 2
        y: map.height / 2

        Rectangle {
            id: ring

            property real spread: 0

            anchors.centerIn: parent
            width: 10 + spread * 26
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: "#ffffff"
            opacity: 1 - spread

            NumberAnimation on spread {
                running: map.active && Kirigami.Units.longDuration > 1
                from: 0
                to: 1
                duration: 2000
                loops: Animation.Infinite
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 10
            height: 10
            radius: 5
            color: Kirigami.Theme.highlightColor
            border.width: 2
            border.color: "#ffffff"
        }
    }

    // A step of the zoom for each notch of a wheel; a touchpad, which sends many small turns, adds
    // them up to a notch, or it ran through every zoom at once.
    WheelHandler {
        property int turned: 0

        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

        onWheel: event => {
            turned += event.angleDelta.y;

            if (Math.abs(turned) >= 120) {
                map.zoomBy(turned > 0 ? 1 : -1);
                turned = 0;
            }
        }
    }

    component Glass: Rectangle {
        radius: Kirigami.Units.cornerRadius
        color: Qt.rgba(0.04, 0.08, 0.16, 0.62)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.18)
    }

    component Ink: Label {
        typography: map.typography
        color: "#ffffff"
    }

    // Closer, farther.
    Glass {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Kirigami.Units.smallSpacing
        width: zoomButtons.implicitWidth
        height: zoomButtons.implicitHeight

        ColumnLayout {
            id: zoomButtons

            spacing: 0

            PlasmaComponents.ToolButton {
                icon.name: "zoom-in"
                icon.color: "#ffffff"
                enabled: map.zoom < Radar.MAX_ZOOM
                display: QQC2.AbstractButton.IconOnly
                text: I18n.t(map.language, "radar.zoomIn")

                onClicked: map.zoomBy(1)

                PlasmaComponents.ToolTip {
                    text: parent.text
                }
            }

            PlasmaComponents.ToolButton {
                icon.name: "zoom-out"
                icon.color: "#ffffff"
                enabled: map.zoom > Radar.MIN_ZOOM
                display: QQC2.AbstractButton.IconOnly
                text: I18n.t(map.language, "radar.zoomOut")

                onClicked: map.zoomBy(-1)

                PlasmaComponents.ToolTip {
                    text: parent.text
                }
            }
        }
    }

    // From light to heavy, in the colours of the radar.
    Glass {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: Kirigami.Units.smallSpacing
        width: legend.implicitWidth + Kirigami.Units.smallSpacing * 2
        height: legend.implicitHeight + Kirigami.Units.smallSpacing * 2

        RowLayout {
            id: legend

            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing

            Ink {
                relativeSize: 0.8
                text: I18n.t(map.language, "radar.light")
            }

            Rectangle {
                Layout.preferredWidth: map.gridUnit * 4
                Layout.preferredHeight: map.gridUnit * 0.4
                radius: height / 2

                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop {
                        position: 0
                        color: Radar.RADAR_COLOURS[0]
                    }

                    GradientStop {
                        position: 0.15
                        color: Radar.RADAR_COLOURS[1]
                    }

                    GradientStop {
                        position: 0.3
                        color: Radar.RADAR_COLOURS[2]
                    }

                    GradientStop {
                        position: 0.45
                        color: Radar.RADAR_COLOURS[4]
                    }

                    GradientStop {
                        position: 0.6
                        color: Radar.RADAR_COLOURS[5]
                    }

                    GradientStop {
                        position: 0.75
                        color: Radar.RADAR_COLOURS[6]
                    }

                    GradientStop {
                        position: 0.9
                        color: Radar.RADAR_COLOURS[7]
                    }

                    GradientStop {
                        position: 1
                        color: Radar.RADAR_COLOURS[8]
                    }
                }
            }

            Ink {
                relativeSize: 0.8
                text: I18n.t(map.language, "radar.heavy")
            }
        }
    }

    // While the index comes, or when it does not.
    Glass {
        anchors.centerIn: parent
        width: waiting.implicitWidth + Kirigami.Units.largeSpacing * 2
        height: waiting.implicitHeight + Kirigami.Units.largeSpacing
        visible: map.frames.length === 0

        Ink {
            id: waiting

            anchors.centerIn: parent
            text: I18n.t(map.language, map.failed ? "radar.failed" : "radar.loading")
        }
    }

    // Play or stop, the images of the two hours, and the time of the one shown.
    Glass {
        id: bar

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Kirigami.Units.smallSpacing
        height: controls.implicitHeight + Kirigami.Units.smallSpacing
        visible: map.frames.length > 0

        RowLayout {
            id: controls

            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.smallSpacing
            anchors.rightMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.ToolButton {
                icon.name: map.playing ? "media-playback-pause" : "media-playback-start"
                icon.color: "#ffffff"
                display: QQC2.AbstractButton.IconOnly
                text: I18n.t(map.language, map.playing ? "radar.pause" : "radar.play")

                onClicked: map.playing = !map.playing

                PlasmaComponents.ToolTip {
                    text: parent.text
                }
            }

            PlasmaComponents.Slider {
                Layout.fillWidth: true
                from: 0
                to: Math.max(1, map.frames.length - 1)
                stepSize: 1
                snapMode: PlasmaComponents.Slider.SnapAlways
                value: map.shown
                Accessible.name: I18n.t(map.language, "rain.radar")

                onMoved: {
                    map.playing = false;
                    map.shown = Math.round(value);
                }
            }

            Ink {
                // As wide as the widest time, so that the slider does not jump from one image to the next.
                Layout.minimumWidth: widestTime.advanceWidth
                font.features: { "tnum": 1 }
                text: map.frames.length > 0
                    ? Radar.frameClock(map.frames[map.shown].time, map.utcOffsetSeconds) + (map.shown === map.frames.length - 1 ? ` · ${I18n.t(map.language, "radar.latest")}` : "")
                    : ""
            }

            TextMetrics {
                id: widestTime

                font.family: map.typography.family
                font.pointSize: map.typography.size
                text: `${Dates.clockShown("12:55")} · ${I18n.t(map.language, "radar.latest")}`
            }
        }
    }

    // The sources, as their terms ask: RainViewer with its link, GIBS acknowledged, and
    // OpenStreetMap for the borders and the names.
    Ink {
        id: credits

        anchors.right: parent.right
        anchors.bottom: bar.visible ? bar.top : parent.bottom
        anchors.margins: Kirigami.Units.smallSpacing
        // With the map, which they are the sources of too, not only once the images have come.
        visible: map.opened
        style: Text.Outline
        styleColor: "#99000000"
        relativeSize: 0.75
        opacity: 0.8
        textFormat: Text.StyledText
        linkColor: "#ffffff"
        text: '<a href="https://www.rainviewer.com/">RainViewer</a> · <a href="https://earthdata.nasa.gov/gibs">NASA GIBS</a> · © <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'

        onLinkActivated: link => {
            if (Links.webAddress(link) !== "") {
                Qt.openUrlExternally(Links.webAddress(link));
            }
        }

        HoverHandler {
            cursorShape: credits.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
        }
    }
}
