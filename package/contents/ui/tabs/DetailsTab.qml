pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../../code/activities.mjs" as Activities
import "../../code/airquality.mjs" as AirQuality
import "../../code/aurora.mjs" as Aurora
import "../../code/dates.mjs" as Dates
import "../../code/details.mjs" as Details
import "../../code/format.mjs" as Format
import "../../code/i18n.mjs" as I18n
import "../../code/instruments.mjs" as Instruments
import "../../code/meteocons.mjs" as Meteocons
import "../../code/moon.mjs" as MoonPhase
import "../../code/scene.mjs" as Scene
import "../../code/sun.mjs" as Sun
import "../../code/temperature.mjs" as Temperature
import "../components" as Components
import "../scene" as Scenery

/**
 * The measurements behind the forecast, a tile each, drawn as instruments where they can be: their
 * needles swing into place as the tab opens, and again under the mouse. The tiles are dragged into
 * the order one wants, or moved with Ctrl and the arrow keys; the order is kept in the settings.
 */
Item {
    id: tab

    /** The parsed forecast, see parseForecast() in code/openmeteo.mjs. */
    required property var forecast
    required property string language
    required property string windUnit
    /** mm | inch: with inches, the visibility is in miles. */
    required property string precipitationUnit
    /** celsius | fahrenheit: the bands of the dew point go by °C. */
    required property string temperatureUnit
    required property var typography
    required property var iconStyle
    /** full | reduced | off: off draws the instruments still. */
    required property string animations
    /** parseAirQuality() of code/airquality.mjs; null shows the gusts in its place. */
    required property var airQuality
    /** auroraOutlook() of code/aurora.mjs; null while the Kp is not known. */
    required property var aurora
    /** The ids of the tiles shown, in their order; see code/details.mjs. */
    required property var order
    /** The place, for the rising and setting of the moon. */
    required property real latitude
    required property real longitude
    /** The activities of their tile, see ACTIVITIES in code/activities.mjs. */
    required property var activities

    /** The tiles were dragged, or moved by keyboard, into another order. */
    signal reordered(var order)
    /** A tile was closed with its ×, or with Delete: it is turned off in the settings. */
    signal hidden(string tile)

    readonly property var current: forecast.current
    readonly property var today: forecast.today
    readonly property var moon: MoonPhase.moonPhase(today.date)
    readonly property string pressureTrend: Instruments.pressureTrend(forecast.hourly) || ""
    readonly property int daylightLeft: Sun.daylightLeft(current.time, today.sunrise, today.sunset)
    readonly property bool moving: animations !== "off"
    readonly property bool knowsDewPoint: typeof current.dewPoint === "number"
    readonly property real dewPointCelsius: knowsDewPoint ? Temperature.toCelsius(current.dewPoint, temperatureUnit) : 0
    readonly property bool knowsVisibility: typeof current.visibility === "number"
    readonly property var moonTimes: MoonPhase.moonTimes(today.date, latitude, longitude, forecast.utcOffsetSeconds)
    readonly property var moonWay: MoonPhase.moonWay(current.time, latitude, longitude, forecast.utcOffsetSeconds)
    readonly property var uvWindow: Instruments.uvWindow(forecast.hourly)
    readonly property var pressureChange: Instruments.pressureChange(forecast.hourly)
    readonly property var cloudsTurn: Instruments.cloudsTurn(forecast.hourly)
    readonly property int beaufort: Instruments.beaufort(Scene.toKmh(current.windSpeed, windUnit))
    readonly property var units: ({ windUnit: windUnit, temperatureUnit: temperatureUnit })

    /** How much bigger than the theme font the text is; the tiles need that much more room. */
    readonly property real fontFactor: typography.size / Kirigami.Theme.defaultFont.pointSize
    /** How tall a tile must be for its icon or its instrument, above the texts. */
    readonly property real roomyHeight: Kirigami.Units.gridUnit * 7.5
    /**
     * The columns and rows of the tiles, which grow to fill the tab as tiles are turned off; see
     * tileGrid() in code/details.mjs. A tile is never made shorter than its icon or instrument
     * needs: with more tiles than fit, the rest scrolls, and a tile added keeps the others whole.
     */
    readonly property var layout: Details.tileGrid(order.length, width, height, {
        minimumWidth: Kirigami.Units.gridUnit * 4.3 * fontFactor,
        minimumHeight: Math.max(Kirigami.Units.gridUnit * 4.2 * fontFactor, roomyHeight + Kirigami.Units.smallSpacing),
        roomyHeight: roomyHeight + Kirigami.Units.smallSpacing,
    })
    readonly property int columns: layout.columns
    readonly property real cellHeight: height / layout.rowsShown
    /** Where each tile is, in the order they are in now; see tileCells() in code/details.mjs. */
    property var cells: []
    /** The tile being dragged, for the scroll at the edges. */
    property Item dragged: null

    /** The ids in the order the tiles are in now. */
    function shownOrder(): var {
        const ids = [];

        for (let index = 0; index < tileModel.count; index++) {
            ids.push(tileModel.get(index).tileId);
        }

        return ids;
    }

    /**
     * Brings the tiles to `order` a step at a time: those turned off go, those turned on come, the
     * others move. The tiles that stay are not made again, so they glide to their new size instead
     * of drawing their instruments anew; after a drag of their own, nothing changes at all.
     */
    function follow(): void {
        for (let index = tileModel.count - 1; index >= 0; index--) {
            if (order.indexOf(tileModel.get(index).tileId) === -1) {
                tileModel.remove(index, 1);
            }
        }

        order.forEach((id, index) => {
            if (index < tileModel.count && tileModel.get(index).tileId === id) {
                return;
            }

            const from = shownOrder().indexOf(id);

            if (from === -1) {
                tileModel.insert(index, { tileId: id });
            } else {
                tileModel.move(from, index, 1);
            }
        });
    }

    /** Places the tiles again, after they moved, came or went, or the layout changed. */
    function relayout(): void {
        cells = Details.tileCells(shownOrder(), layout);
    }

    /** Moves the tile at `from` by `step` places, from the keyboard, and keeps the order. */
    function nudge(from: int, step: int): void {
        const to = Math.max(0, Math.min(tileModel.count - 1, from + step));

        if (to !== from) {
            tileModel.move(from, to, 1);
            reordered(shownOrder());
        }
    }

    onOrderChanged: follow()
    onLayoutChanged: relayout()
    Component.onCompleted: follow()

    ListModel {
        id: tileModel

        // Whichever way they change, the tiles are placed again.
        onRowsMoved: tab.relayout()
        onRowsInserted: tab.relayout()
        onRowsRemoved: tab.relayout()
    }

    component Tile: Rectangle {
        id: tile

        required property string label
        required property string value
        property string note: ""
        /** A Meteocons icon, see DETAIL_ICONS and moonIcon() in code/meteocons.mjs. */
        required property string symbol
        /** An instrument drawn in place of the icon, whatever the icons of the widget. */
        property Component instrument: null
        /** The instrument grows with its tile, when fewer tiles have more room. */
        property real instrumentWidth: Math.min(width * 0.7, height * 0.8, Kirigami.Units.gridUnit * 8)
        property real instrumentHeight: instrumentWidth * 0.55
        /** The icon or the instrument shows only where the tile is tall enough. */
        readonly property bool roomy: height >= tab.roomyHeight
        /** Under the mouse, or picked up. */
        property bool hovered: false
        property bool lifted: false

        radius: Kirigami.Units.cornerRadius
        // With large text, what does not fit stays within the tile instead of running over the next.
        clip: true
        color: Qt.alpha(Kirigami.Theme.textColor, lifted ? 0.16 : hovered ? 0.12 : 0.07)
        border.width: lifted ? 1 : 0
        border.color: Qt.alpha(Kirigami.Theme.highlightColor, 0.8)

        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }

        // Under the mouse the instrument plays again, and an icon hops.
        onHoveredChanged: {
            if (!hovered || lifted || !tab.moving) {
                return;
            }

            if (instrumentLoader.item !== null && instrumentLoader.item.replay !== undefined) {
                instrumentLoader.item.replay();
            } else if (icon.visible && !hop.running) {
                hop.restart();
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.smallSpacing * 2
            spacing: 0

            Loader {
                id: instrumentLoader

                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: tile.instrumentWidth
                Layout.preferredHeight: tile.instrumentHeight
                Layout.bottomMargin: Kirigami.Units.smallSpacing
                active: tile.instrument !== null && tile.roomy
                visible: active
                sourceComponent: tile.instrument
            }

            Components.SymbolIcon {
                id: icon

                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Kirigami.Units.iconSizes.large
                Layout.preferredHeight: Kirigami.Units.iconSizes.large
                // Shown with the Meteocons icons, where there is no instrument.
                visible: tile.instrument === null && tab.iconStyle.set === "meteocons" && tile.roomy
                name: tile.symbol

                transform: Translate {
                    id: iconLift
                }

                // A hop, and a little squash as it lands.
                SequentialAnimation {
                    id: hop

                    NumberAnimation {
                        target: iconLift
                        property: "y"
                        to: -Kirigami.Units.smallSpacing * 2
                        duration: 180
                        easing.type: Easing.OutQuad
                    }

                    NumberAnimation {
                        target: iconLift
                        property: "y"
                        to: 0
                        duration: 420
                        easing.type: Easing.OutBounce
                    }
                }
            }

            Components.Label {
                Layout.fillWidth: true
                typography: tab.typography
                relativeSize: 0.9
                horizontalAlignment: Text.AlignHCenter
                fontSizeMode: Text.HorizontalFit
                minimumPointSize: tab.typography.size * 0.7
                elide: Text.ElideRight
                opacity: 0.75
                text: tile.label
            }

            Components.Label {
                Layout.fillWidth: true
                typography: tab.typography
                relativeSize: 1.3
                horizontalAlignment: Text.AlignHCenter
                // A long value shrinks to fit rather than being cut.
                fontSizeMode: Text.HorizontalFit
                minimumPointSize: tab.typography.size * 0.75
                font.weight: Font.DemiBold
                visible: tile.value !== ""
                text: tile.value
            }

            Components.Label {
                Layout.fillWidth: true
                typography: tab.typography
                relativeSize: 0.9
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                // A tall tile has room for a third line, which the longer languages need.
                maximumLineCount: tile.roomy ? 3 : 2
                elide: Text.ElideRight
                visible: tile.note !== ""
                opacity: 0.85
                text: tile.note
            }
        }
    }

    // The tiles, laid out by tab.layout; they glide to their new places as others move, go or come.
    Flickable {
        id: grid

        anchors.fill: parent
        contentWidth: width
        contentHeight: tab.layout.rows * tab.cellHeight
        // The tiles are dragged, not the view: it scrolls with the wheel, or as a tile is dragged to its edge.
        interactive: false
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        QQC2.ScrollBar.vertical: PlasmaComponents.ScrollBar {
            visible: grid.contentHeight > grid.height + 1
        }

        Repeater {
            model: tileModel

            delegate: DropArea {
                id: slot

                required property string tileId
                required property int index

                /** Its row, and its place and width as shares of the width; see tileCells() in code/details.mjs. */
                readonly property var cell: tab.cells[index] || ({ row: 0, x: 0, width: 0 })

                x: cell.x * grid.width
                y: cell.row * tab.cellHeight
                width: cell.width * grid.width
                height: tab.cellHeight

                Behavior on x {
                    NumberAnimation {
                        duration: Kirigami.Units.longDuration
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on y {
                    NumberAnimation {
                        duration: Kirigami.Units.longDuration
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on width {
                    NumberAnimation {
                        duration: Kirigami.Units.longDuration
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on height {
                    NumberAnimation {
                        duration: Kirigami.Units.longDuration
                        easing.type: Easing.OutCubic
                    }
                }

                // A tile dragged over this place takes it; the tiles between close up.
                onEntered: drag => {
                    const from = drag.source.slotIndex;

                    if (from !== undefined && from !== slot.index) {
                        tileModel.move(from, slot.index, 1);
                    }
                }

                // The tile, at the top left of its place. Its size always follows the place, picked up too:
                // over a place of another size it takes that size, as it will have once dropped there.
                Item {
                    id: holder

                    readonly property int slotIndex: slot.index
                    /** The size it had, to keep it centred under the mouse as it takes another. */
                    property size lastSize: Qt.size(width, height)

                    width: slot.width
                    height: slot.height
                    z: grab.drag.active ? 10 : 0
                    scale: grab.drag.active ? 1.05 : 1
                    opacity: grab.drag.active ? 0.92 : 1
                    activeFocusOnTab: true
                    Drag.active: grab.drag.active
                    Drag.source: holder
                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2
                    Accessible.role: Accessible.StaticText
                    Accessible.name: tileLoader.item !== null ? [`${tileLoader.item.label}: ${tileLoader.item.value}`, tileLoader.item.note].filter(part => part !== "").join(", ") : ""
                    Accessible.description: I18n.t(tab.language, "a11y.moveTile")

                    onWidthChanged: {
                        if (grab.drag.active) {
                            x += (lastSize.width - width) / 2;
                        }

                        lastSize = Qt.size(width, height);
                    }
                    onHeightChanged: {
                        if (grab.drag.active) {
                            y += (lastSize.height - height) / 2;
                        }

                        lastSize = Qt.size(width, height);
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Kirigami.Units.shortDuration
                        }
                    }

                    // Ctrl and the arrow keys move the tile with the focus: sideways by one, up and down by a row. Delete hides it.
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Delete && tab.order.length > 1) {
                            tab.hidden(slot.tileId);
                            event.accepted = true;

                            return;
                        }

                        if ((event.modifiers & Qt.ControlModifier) === 0) {
                            return;
                        }

                        const steps = { [Qt.Key_Left]: -1, [Qt.Key_Right]: 1, [Qt.Key_Up]: -tab.columns, [Qt.Key_Down]: tab.columns };

                        if (steps[event.key] !== undefined) {
                            tab.nudge(slot.index, steps[event.key]);
                            event.accepted = true;
                        }
                    }

                    Loader {
                        id: tileLoader

                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.smallSpacing / 2
                        sourceComponent: ({
                            wind: windTile,
                            air: tab.airQuality !== null ? airTile : gustsTile,
                            humidity: humidityTile,
                            dewPoint: dewPointTile,
                            pressure: pressureTile,
                            uv: uvTile,
                            clouds: cloudsTile,
                            visibility: visibilityTile,
                            sun: sunTile,
                            moon: moonTile,
                            aurora: auroraTile,
                            pollen: pollenTile,
                            activities: activitiesTile,
                        })[slot.tileId]

                        onLoaded: {
                            item.hovered = Qt.binding(() => grab.containsMouse || closeTouch.containsMouse || holder.activeFocus);
                            item.lifted = Qt.binding(() => grab.drag.active);
                        }
                    }

                    // The focus shows as a ring.
                    Rectangle {
                        anchors.fill: tileLoader
                        radius: Kirigami.Units.cornerRadius
                        visible: holder.activeFocus
                        color: "transparent"
                        border.width: 2
                        border.color: Kirigami.Theme.focusColor
                    }

                    MouseArea {
                        id: grab

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        drag.target: holder

                        onPressed: holder.forceActiveFocus()
                    }

                    // Picked up, the tile leaves its place for the tab, so that it stays under the mouse while
                    // the places move; dropped, it goes back to its place, which may be another by then, and
                    // glides into it. The size is never set here: it stays bound to the place.
                    Connections {
                        target: grab.drag

                        function onActiveChanged(): void {
                            const home = grab.drag.active ? tab : slot;
                            const place = holder.mapToItem(home, 0, 0);

                            holder.parent = home;
                            holder.x = place.x;
                            holder.y = place.y;

                            if (grab.drag.active) {
                                tab.dragged = holder;

                                return;
                            }

                            tab.dragged = null;
                            settle.restart();
                            // Dropped: the order the tiles are in now is kept.
                            tab.reordered(tab.shownOrder());
                        }
                    }

                    ParallelAnimation {
                        id: settle

                        NumberAnimation {
                            target: holder
                            property: "x"
                            to: 0
                            duration: Kirigami.Units.longDuration
                            easing.type: Easing.OutCubic
                        }

                        NumberAnimation {
                            target: holder
                            property: "y"
                            to: 0
                            duration: Kirigami.Units.longDuration
                            easing.type: Easing.OutCubic
                        }
                    }

                    // Under the mouse, a × in the corner turns the tile off; the last one stays.
                    Rectangle {
                        readonly property real side: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing

                        anchors.top: tileLoader.top
                        anchors.right: tileLoader.right
                        anchors.margins: Kirigami.Units.smallSpacing / 2
                        width: side
                        height: side
                        radius: side / 2
                        visible: tab.order.length > 1 && !grab.drag.active
                        opacity: grab.containsMouse || closeTouch.containsMouse || holder.activeFocus ? 1 : 0
                        color: closeTouch.containsMouse ? Qt.alpha(Kirigami.Theme.negativeTextColor, 0.85) : Qt.alpha(Kirigami.Theme.textColor, 0.15)
                        Accessible.role: Accessible.Button
                        Accessible.name: I18n.t(tab.language, "details.hideTile")
                        Accessible.onPressAction: tab.hidden(slot.tileId)

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Kirigami.Units.shortDuration
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Kirigami.Units.shortDuration
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            font.pixelSize: parent.side * 0.75
                            color: Kirigami.Theme.textColor
                            text: "×"
                        }

                        MouseArea {
                            id: closeTouch

                            anchors.fill: parent
                            enabled: parent.opacity > 0
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: tab.hidden(slot.tileId)
                        }

                        PlasmaComponents.ToolTip {
                            visible: closeTouch.containsMouse
                            text: I18n.t(tab.language, "details.hideTile")
                        }
                    }
                }
            }
        }
    }

    // A tile dragged to the top or the bottom edge scrolls the tiles beyond it into view.
    Timer {
        interval: 30
        repeat: true
        running: tab.dragged !== null && grid.contentHeight > grid.height

        onTriggered: {
            const middle = tab.dragged.y + tab.dragged.height / 2;
            const edge = tab.cellHeight * 0.35;
            const most = Math.max(0, grid.contentHeight - grid.height);

            if (middle < edge) {
                grid.contentY = Math.max(0, grid.contentY - 6);
            } else if (middle > grid.height - edge) {
                grid.contentY = Math.min(most, grid.contentY + 6);
            }
        }
    }

    WheelHandler {
        onWheel: event => grid.contentY = Math.max(0, Math.min(Math.max(0, grid.contentHeight - grid.height), grid.contentY - event.angleDelta.y / 2))
    }

    Component {
        id: windTile

        Tile {
            symbol: "wind"
            label: I18n.t(tab.language, "details.wind")
            value: Format.wind(tab.current.windSpeed, tab.windUnit, tab.language)
            // With the air quality in their tile, the gusts go with the wind.
            note: [
                tab.airQuality !== null
                    ? `${I18n.compass(tab.current.windDirection, tab.language)} · ${I18n.t(tab.language, "details.gustsNote", { value: Format.wind(tab.current.windGusts, tab.windUnit, tab.language) })}`
                    : I18n.compass(tab.current.windDirection, tab.language),
                I18n.t(tab.language, "wind.beaufort", { force: tab.beaufort, name: I18n.t(tab.language, `beaufort.${tab.beaufort}`) }),
            ].join("\n")
            instrumentWidth: Math.min(width * 0.6, height * 0.42, Kirigami.Units.gridUnit * 6)
            instrumentHeight: instrumentWidth

            instrument: Components.Compass {
                direction: tab.current.windDirection
                language: tab.language
                typography: tab.typography
                animated: tab.moving
            }
        }
    }

    Component {
        id: gustsTile

        Tile {
            symbol: "windsock"
            label: I18n.t(tab.language, "details.gusts")
            value: Format.wind(tab.current.windGusts, tab.windUnit, tab.language)
        }
    }

    Component {
        id: airTile

        Tile {
            // Not shown, the dial stands in its place; an icon that exists, so that nothing fails to load.
            symbol: "wind"
            label: I18n.t(tab.language, "details.air")
            // Read while the tile gives way to the gusts too, when the air quality is gone.
            value: tab.airQuality !== null ? Format.number(tab.airQuality.aqi, 0, tab.language) : ""
            // The band of the index, and the pollen most felt, where there is any.
            note: tab.airQuality === null ? "" : [
                I18n.t(tab.language, `air.${AirQuality.aqiKey(tab.airQuality.aqi)}`),
                tab.airQuality.pollen !== null ? I18n.t(tab.language, `pollen.${tab.airQuality.pollen.level}`, { name: I18n.t(tab.language, `pollen.name.${tab.airQuality.pollen.name}`) }) : "",
            ].filter(part => part !== "").join(" · ")

            instrument: Components.Dial {
                scale: AirQuality.AQI_SCALE
                value: tab.airQuality !== null ? tab.airQuality.aqi : 0
                animated: tab.moving
            }
        }
    }

    Component {
        id: humidityTile

        Tile {
            symbol: "humidity"
            label: I18n.t(tab.language, "details.humidity")
            value: Format.percent(tab.current.humidity)
            note: typeof tab.current.humidity === "number" ? I18n.t(tab.language, Instruments.humidityKey(tab.current.humidity)) : ""
        }
    }

    Component {
        id: dewPointTile

        Tile {
            symbol: "humidity"
            label: I18n.t(tab.language, "details.dewPoint")
            value: tab.knowsDewPoint ? Format.temperature(tab.current.dewPoint) : Format.temperature(null)
            note: tab.knowsDewPoint ? I18n.t(tab.language, Instruments.dewPointKey(tab.dewPointCelsius)) : ""

            instrument: Components.Dial {
                scale: Instruments.DEW_POINT_SCALE
                value: tab.dewPointCelsius
                animated: tab.moving
            }
        }
    }

    Component {
        id: pressureTile

        Tile {
            symbol: "barometer"
            label: I18n.t(tab.language, "details.pressure")
            value: Format.pressure(tab.current.pressure)
            // The trend, or what a fast change foretells, and by how much it changes in three hours.
            note: {
                if (tab.pressureChange === null) {
                    return tab.pressureTrend !== "" ? I18n.t(tab.language, `details.trend.${tab.pressureTrend}`) : "";
                }

                const fast = Math.abs(tab.pressureChange) >= Instruments.FAST_CHANGE_HPA;
                const meaning = fast
                    ? I18n.t(tab.language, tab.pressureChange < 0 ? "pressure.worsening" : "pressure.improving")
                    : I18n.t(tab.language, `details.trend.${tab.pressureTrend}`);
                const change = `${tab.pressureChange > 0 ? "+" : tab.pressureChange < 0 ? "−" : ""}${Format.number(Math.abs(tab.pressureChange), 1, tab.language)}`;

                return `${meaning}\n${I18n.t(tab.language, "pressure.change", { change: change })}`;
            }

            instrument: Components.Dial {
                scale: Instruments.PRESSURE_SCALE
                value: tab.current.pressure
                animated: tab.moving
            }
        }
    }

    Component {
        id: uvTile

        Tile {
            symbol: "clear-day"
            label: I18n.t(tab.language, "details.uv")
            value: Format.number(tab.today.uvIndexMax, 1, tab.language)
            // The band of the day, and while the sun calls for it, when to protect the skin.
            note: {
                const band = I18n.t(tab.language, Format.uvKey(tab.today.uvIndexMax));

                if (tab.uvWindow === null) {
                    return band;
                }

                const now = Dates.timeLabel(tab.current.time);
                const advice = now < tab.uvWindow.from
                    ? I18n.t(tab.language, "uv.protectBetween", { start: tab.uvWindow.from, end: tab.uvWindow.until })
                    : I18n.t(tab.language, "uv.protectUntil", { time: tab.uvWindow.until });

                return `${band} · ${advice}`;
            }

            instrument: Components.Dial {
                scale: Instruments.UV_SCALE
                value: tab.today.uvIndexMax
                animated: tab.moving
            }
        }
    }

    Component {
        id: cloudsTile

        Tile {
            symbol: "cloudy"
            label: I18n.t(tab.language, "details.clouds")
            value: Format.percent(tab.current.cloudCover)
            note: tab.cloudsTurn !== null ? I18n.t(tab.language, `clouds.${tab.cloudsTurn.kind}`, { time: tab.cloudsTurn.time }) : ""
        }
    }

    Component {
        id: visibilityTile

        Tile {
            symbol: "fog"
            label: I18n.t(tab.language, "details.visibility")
            value: Format.distance(tab.knowsVisibility ? tab.current.visibility : null, tab.precipitationUnit, tab.language)
            note: tab.knowsVisibility ? I18n.t(tab.language, Instruments.visibilityKey(tab.current.visibility)) : ""

            instrument: Components.Visibility {
                metres: tab.knowsVisibility ? tab.current.visibility : null
                animated: tab.moving
            }
        }
    }

    Component {
        id: sunTile

        Tile {
            symbol: "clear-day"
            label: I18n.t(tab.language, "details.sun")
            value: `↑ ${Dates.timeLabel(tab.today.sunrise)}  ↓ ${Dates.timeLabel(tab.today.sunset)}`
            // By day, how long until sunset; by night, how long the day is.
            note: tab.daylightLeft > 0
                ? I18n.t(tab.language, "details.daylightLeft", { time: Format.duration(tab.daylightLeft) })
                : I18n.t(tab.language, "details.dayLength", { time: Format.duration(tab.today.daylightDuration / 60) })
            instrumentWidth: Math.min(width * 0.8, height * 0.9, Kirigami.Units.gridUnit * 8)
            instrumentHeight: instrumentWidth * 0.45

            instrument: Components.SunArc {
                now: tab.current.time
                sunrise: tab.today.sunrise
                sunset: tab.today.sunset
                animated: tab.moving
            }
        }
    }

    Component {
        id: moonTile

        Tile {
            symbol: Meteocons.moonIcon(tab.moon.key)
            label: I18n.t(tab.language, "details.moon")
            value: Format.percent(tab.moon.illumination * 100)
            // The phase, and when the moon rises and sets today.
            note: [I18n.t(tab.language, tab.moon.key), `↑ ${tab.moonTimes.rise || "–"}  ↓ ${tab.moonTimes.set || "–"}`].join("\n")
            instrumentWidth: Math.min(width * 0.8, height * 0.9, Kirigami.Units.gridUnit * 8)
            instrumentHeight: instrumentWidth * 0.5

            instrument: Components.MoonArc {
                phase: tab.moon.fraction
                way: tab.moonWay
                animated: tab.moving
            }
        }
    }

    Component {
        id: auroraTile

        Tile {
            symbol: "clear-night"
            label: I18n.t(tab.language, "details.aurora")
            // The Kp of the night, and its storm if it is one.
            value: tab.aurora === null ? Format.number(null, 1, tab.language) : [`Kp ${Format.number(tab.aurora.kp, 1, tab.language)}`, tab.aurora.storm].filter(part => part !== "").join(" · ")
            note: {
                if (tab.aurora === null) {
                    return "";
                }

                const direction = I18n.t(tab.language, `aurora.${tab.aurora.direction}`);

                return {
                    overhead: I18n.t(tab.language, "aurora.overhead"),
                    horizon: I18n.t(tab.language, "aurora.horizon", { direction: direction }),
                    camera: I18n.t(tab.language, "aurora.camera", { direction: direction }),
                    none: I18n.t(tab.language, "aurora.unlikely", { needed: tab.aurora.needed }),
                }[tab.aurora.sight];
            }

            instrument: Components.Dial {
                scale: Aurora.KP_SCALE
                value: tab.aurora !== null ? tab.aurora.kp : 0
                animated: tab.moving
            }
        }
    }

    Component {
        id: pollenTile

        Tile {
            readonly property var pollens: tab.airQuality !== null ? tab.airQuality.pollens || [] : []

            symbol: "wind"
            label: I18n.t(tab.language, "details.pollen")
            // The pollen most felt now, and its level; the others after it.
            value: pollens.length > 0 ? I18n.t(tab.language, `pollen.plant.${pollens[0].name}`) : Format.number(null, 0, tab.language)
            note: pollens.length === 0
                ? I18n.t(tab.language, "pollen.none")
                : [
                    I18n.t(tab.language, `pollen.level.${pollens[0].level}`),
                    pollens.length > 1 ? I18n.t(tab.language, "pollen.alsoPresent", { names: pollens.slice(1, 3).map(pollen => I18n.t(tab.language, `pollen.plant.${pollen.name}`)).join(", ") }) : "",
                ].filter(part => part !== "").join(" · ")
            instrumentWidth: Math.min(width * 0.85, Kirigami.Units.gridUnit * 9)
            instrumentHeight: Math.min(height * 0.4, Kirigami.Units.gridUnit * 3.5)

            instrument: Components.PollenDays {
                days: tab.airQuality !== null ? tab.airQuality.pollenDays || [] : []
                language: tab.language
                typography: tab.typography
                animated: tab.moving
            }
        }
    }

    Component {
        id: activitiesTile

        Tile {
            symbol: "clear-day"
            label: I18n.t(tab.language, "details.activities")
            value: ""
            instrumentWidth: width - Kirigami.Units.largeSpacing * 2
            instrumentHeight: Math.min(height * 0.62, tab.activities.length * Kirigami.Units.gridUnit * 1.4)

            instrument: Components.ActivityList {
                activities: tab.activities
                hourly: tab.forecast.hourly
                units: tab.units
                moonIllumination: tab.moon.illumination
                language: tab.language
                typography: tab.typography
            }
        }
    }
}
