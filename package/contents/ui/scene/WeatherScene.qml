pragma ComponentBehavior: Bound

import QtQuick

import "../../code/land.mjs" as Land
import "../../code/moon.mjs" as MoonPhase
import "../../code/scene.mjs" as Scene
import "../../code/sky.mjs" as Sky
import "../../code/temperature.mjs" as Temperature

/**
 * The animated picture of the current weather: a sky that follows the hour, the sun or the
 * moon on its way across it, clouds drifting with the wind, and whatever falls. Around them, what
 * the weather brings besides: a rainbow after showers, the Milky Way and shooting stars on a clear
 * night, the aurora when it can be seen, wind made visible, frost and heat haze, and snow that
 * settles. A change of weather fades from one picture to the next.
 */
Item {
    id: scene

    /** `current` and `today` of the parsed forecast. */
    required property var current
    required property var today
    required property string windUnit
    /** celsius | fahrenheit: frost and heat haze go by °C. */
    required property string temperatureUnit
    /** full | reduced | off; "off" is a still picture. */
    required property string quality
    /** How the aurora can be seen tonight, see auroraOutlook() in code/aurora.mjs: overhead, horizon, camera or none. */
    property string aurora: "none"
    /** The land under the sky: one of KINDS in code/land.mjs. */
    property string landscape: "none"
    /** How much of the height of the scene the land takes, in percent. */
    property int landscapeHeight: 55
    /** The latitude of the place, for the season of the leaves on the hills. */
    property real latitude: 45
    /** Lets the owner stop the motion while the scene is not on screen. */
    property bool running: true
    property real radius: 0

    readonly property bool moving: running && quality !== "off"
    readonly property var moon: MoonPhase.moonPhase(today.date)
    readonly property var orbit: Scene.celestial(current.time, today.sunrise, today.sunset)
    readonly property var look: Scene.sceneFor({
        weatherCode: current.conditionCode,
        isDay: current.isDay,
        windKmh: Scene.toKmh(current.windSpeed, windUnit),
        quality: quality,
        sunProgress: orbit.isDay ? orbit.progress : 0.5,
        moonIllumination: moon.illumination,
        celsius: Temperature.toCelsius(current.temperature, temperatureUnit),
        aurora: scene.aurora,
    })
    readonly property real twilight: Scene.twilight(current.time, today.sunrise, today.sunset)
    /** How high the sun is, 0 on the horizon and 1 at its highest; 0 by night. */
    readonly property real sunHeight: orbit.isDay ? Math.sin(Math.PI * orbit.progress) : 0
    readonly property var sky: Sky.skyGradient(look.family, current.isDay, twilight, { weatherCode: current.conditionCode, sunHeight: sunHeight })
    /** How warm the light is: at sunrise and sunset, and a little with the sun low; less through thick cloud. */
    readonly property real warmth: current.isDay ? Math.max(twilight, (1 - Math.min(1, sunHeight / 0.35)) * 0.55) * ({ clear: 1, cloudy: 0.6 }[look.family] || 0.3) : 0
    /** Wind from the western half of the compass carries the clouds and the rain to the right. */
    readonly property int windSign: current.windDirection > 180 ? 1 : -1
    readonly property real lean: Math.tan(look.slant * Math.PI / 180) * windSign

    /**
     * The lit top and the shaded base of the clouds, by day and by night, for each tone of cloud.
     * By night the tops are silvered by the moon, as much as it is lit.
     */
    readonly property var cloudTones: ({
        white: [["#ffffff", "#b4c5dc"], ["#c3cbe0", "#3a4258"]],
        grey: [["#e4e8ee", "#8c97a8"], ["#8e98b0", "#2a3146"]],
        dark: [["#8a93a6", "#4c5466"], ["#545d74", "#1c2130"]],
    })
    readonly property var cloudTone: cloudTones[look.cloudTone][current.isDay ? 0 : 1]
    /** The tops take the warm light of a low sun, the bases blush at sunset; by night, the moon lights the tops. */
    readonly property string cloudLit: current.isDay ? Sky.mixHex(cloudTone[0], "#ffcf9e", warmth * 0.7) : Sky.mixHex("#4a5370", cloudTone[0], 0.35 + 0.65 * moon.illumination)
    readonly property string cloudShade: current.isDay ? Sky.mixHex(cloudTone[1], "#c98aa0", warmth * 0.5) : cloudTone[1]

    /** The sun, or the moon: where its centre is, and how big it is drawn. */
    readonly property real celestialSize: Math.min(width, height) * 0.34
    readonly property point celestialCentre: Qt.point((0.08 + 0.84 * orbit.progress) * width, (0.6 - 0.48 * Math.sin(Math.PI * orbit.progress)) * height)

    /**
     * Where cloud `index` is: `{ x, y, width, height, layer, opacity }`. Three layers make the depth:
     * far clouds are small, faint and slow, high in the sky; near ones big and quicker, lower down.
     */
    function cloudPlace(index: int): var {
        const layer = index % 3;
        const start = Scene.noise(index, 11);
        // Whole crossings of the sky per round of the clock, so that the drift loops without a jump.
        const laps = [1, 1, 2][layer] + Math.floor(Scene.noise(index, 13) * 1.5);
        const travel = (driftClock * laps + start) % 1;
        const cloudWidth = width * [0.3, 0.45, 0.62][layer] * (0.85 + Scene.noise(index, 12) * 0.3);
        // Over a landscape, the clouds keep to the sky above it.
        const sky = landscape !== "none" ? Math.max(0.45, 1 - landscapeHeight / 100 + 0.1) : 1;
        const top = ([0.0, 0.08, 0.2][layer] + Scene.noise(index, 14) * [0.16, 0.22, 0.24][layer]) * sky;

        return {
            x: (windSign > 0 ? travel : 1 - travel) * (width + cloudWidth) - cloudWidth,
            y: height * top,
            width: cloudWidth,
            height: cloudWidth * 0.5,
            layer: layer,
            opacity: [0.6, 0.85, 0.97][layer],
        };
    }

    /** How much the clouds hide the sun now, 0 to 1: the light of the whole scene dims as one passes in front of it. */
    readonly property real sunCover: {
        // Before the scene has a size there is nothing to hide.
        if (!current.isDay || look.clouds === 0 || width <= 0 || height <= 0) {
            return 0;
        }

        const reach = celestialSize * 0.15;
        let cover = 0;

        // Read so that the cover follows the drift.
        void driftClock;

        for (let index = 0; index < look.clouds; index++) {
            const place = cloudPlace(index);
            const across = Math.abs(celestialCentre.x - (place.x + place.width / 2)) / (place.width * 0.36 + reach);
            const down = Math.abs(celestialCentre.y - (place.y + place.height * 0.6)) / (place.height * 0.36 + reach);

            cover = Math.max(cover, Math.max(0, 1 - across) * Math.max(0, 1 - down) * place.opacity * (place.layer === 0 ? 0.5 : 1));
        }

        return Math.min(1, cover * 2);
    }

    /** The mouse over the scene, from -1 to 1 each way: the layers shift by their depth, the far ones least. */
    property real tiltX: 0
    property real tiltY: 0

    Behavior on tiltX {
        NumberAnimation {
            duration: 700
            easing.type: Easing.OutCubic
        }
    }

    Behavior on tiltY {
        NumberAnimation {
            duration: 700
            easing.type: Easing.OutCubic
        }
    }

    /**
     * Where everything that falls (fallClock) or drifts (driftClock) is, from 0 to 1, over and
     * over. While the scene does not move they keep their value, which gives the still picture.
     */
    property real fallClock: 0.37
    property real driftClock: 0.21
    /** Like the others, for what the wind blows across: fast, as gusts are. */
    property real gustClock: 0.63
    /**
     * What falls goes on falling while it fades out, after the weather has changed: these keep the
     * number of drops and flakes until their layer has faded.
     */
    property int rainLeft: 0
    property int snowLeft: 0
    readonly property int rainCount: look.rain > 0 ? look.rain : rainLeft
    readonly property int snowCount: look.snow > 0 ? look.snow : snowLeft
    /** How far the snow has piled up, 0 to 1: it settles over half a minute of snowfall. */
    property real settled: quality === "off" && look.snowCover > 0 ? 1 : 0
    property string auroraSight: look.aurora !== "none" ? look.aurora : "overhead"

    clip: true

    onLookChanged: {
        // The aurora keeps its height while it fades out.
        if (look.aurora !== "none") {
            auroraSight = look.aurora;
        }

        if (look.rain > 0) {
            rainLeft = look.rain;
        }

        if (look.snow > 0) {
            snowLeft = look.snow;
        }
    }

    NumberAnimation on fallClock {
        running: scene.moving && (scene.rainCount > 0 || scene.snowCount > 0)
        from: 0
        to: 1
        duration: 6000
        loops: Animation.Infinite
    }

    NumberAnimation on driftClock {
        running: scene.moving && (scene.look.clouds > 0 || scene.look.fog)
        from: 0
        to: 1
        duration: scene.look.driftSeconds * 1000
        loops: Animation.Infinite
    }

    NumberAnimation on gustClock {
        running: scene.moving && (scene.look.streaks > 0 || scene.look.leaves > 0)
        from: 0
        to: 1
        duration: 9000
        loops: Animation.Infinite
    }

    NumberAnimation on settled {
        running: scene.moving && scene.look.snowCover > 0
        to: 1
        duration: 30000
    }

    // The snow melts away once it has stopped falling.
    NumberAnimation on settled {
        running: scene.look.snowCover === 0 && scene.settled > 0
        to: 0
        duration: 6000
    }

    Rectangle {
        anchors.fill: parent
        radius: scene.radius

        // A change of weather or of the hour turns the sky slowly, not at once.
        gradient: Gradient {
            GradientStop {
                position: 0
                color: scene.sky.top

                Behavior on color {
                    ColorAnimation {
                        duration: 2500
                    }
                }
            }

            GradientStop {
                position: 0.55
                color: scene.sky.middle

                Behavior on color {
                    ColorAnimation {
                        duration: 2500
                    }
                }
            }

            GradientStop {
                position: 1
                color: scene.sky.bottom

                Behavior on color {
                    ColorAnimation {
                        duration: 2500
                    }
                }
            }
        }
    }

    /**
     * A layer that is made only while it shows, and kept until it has faded out, `strength` its
     * opacity. Hidden, a Canvas as large as the scene was still painted and kept: by day, the stars,
     * the Milky Way, the rainbow and the frost of a wallpaper, some 8 MB each at the size of a screen.
     */
    component Fading: Loader {
        id: fading

        property real strength: 0
        property int fade: 2500

        anchors.fill: parent
        opacity: strength
        active: opacity > 0
        visible: active

        Behavior on opacity {
            NumberAnimation {
                duration: fading.fade
            }
        }
    }

    Fading {
        strength: scene.look.milkyWay ? 1 : 0
        transform: Translate {
            x: scene.tiltX * 2
            y: scene.tiltY
        }

        sourceComponent: MilkyWay {}
    }

    // Hundreds of faint stars, painted once, and among them the bright ones, which twinkle.
    Fading {
        strength: scene.look.stars > 0 ? 1 : 0
        transform: Translate {
            x: scene.tiltX * 2
            y: scene.tiltY
        }

        sourceComponent: StarField {
            count: scene.look.stars
        }
    }

    Repeater {
        model: scene.look.twinkles

        delegate: Rectangle {
            id: star

            required property int index

            readonly property real size: 1.6 + Scene.noise(index, 3) * 1.4

            x: Scene.noise(index, 1) * scene.width + scene.tiltX * 2
            y: Math.pow(Scene.noise(index, 2), 1.3) * scene.height * 0.7 + scene.tiltY
            width: size
            height: size
            radius: size / 2
            color: "#ffffff"
            opacity: 0.45 + Scene.noise(index, 4) * 0.55

            SequentialAnimation on opacity {
                running: scene.moving
                loops: Animation.Infinite

                NumberAnimation {
                    to: 0.15
                    duration: 900 + Scene.noise(star.index, 5) * 2600
                    easing.type: Easing.InOutSine
                }

                NumberAnimation {
                    to: 1
                    duration: 900 + Scene.noise(star.index, 6) * 2600
                    easing.type: Easing.InOutSine
                }
            }
        }
    }

    Aurora {
        anchors.fill: parent
        sight: scene.auroraSight
        running: scene.moving && opacity > 0
        opacity: scene.look.aurora !== "none" ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 4000
            }
        }
    }

    ShootingStar {
        anchors.fill: parent
        visible: scene.look.shootingStars
        running: scene.moving && visible
    }

    // The sun or the moon, on an arc from one side of the sky to the other. A cloud in front of the sun dims it.
    Item {
        x: scene.celestialCentre.x - width / 2
        y: scene.celestialCentre.y - height / 2
        width: scene.celestialSize
        height: scene.celestialSize
        opacity: scene.look.celestialOpacity
        transform: Translate {
            x: scene.tiltX * 4
            y: scene.tiltY * 2
        }

        SunDisc {
            anchors.fill: parent
            visible: scene.current.isDay
            running: scene.moving && visible
            cover: scene.sunCover
        }

        MoonDisc {
            anchors.fill: parent
            visible: !scene.current.isDay
            phase: scene.moon.fraction
            south: scene.latitude < 0
        }
    }

    // Beams of light through the gaps, strongest while a cloud only half hides the sun; not made
    // without the sun and a cloud to pass it.
    Loader {
        x: scene.celestialCentre.x - width / 2
        y: scene.celestialCentre.y
        width: scene.width * 1.4
        height: scene.height * 1.1
        active: scene.current.isDay && scene.look.clouds > 0 && scene.look.celestialOpacity > 0.5
        opacity: 4 * scene.sunCover * (1 - scene.sunCover) * 0.45
        transform: Translate {
            x: scene.tiltX * 4
            y: scene.tiltY * 2
        }

        sourceComponent: GodRays {
            running: scene.moving && parent.opacity > 0.02
        }
    }

    // A covered sky: the deck behind the single clouds, which still drift in front of it.
    Fading {
        strength: scene.look.deck
        fade: 3000

        sourceComponent: CloudDeck {
            drift: scene.driftClock
            windSign: scene.windSign
            lit: scene.cloudLit
            shade: scene.cloudShade
        }
    }

    // The single clouds, near ones in front of far ones, all behind the land.
    Item {
        anchors.fill: parent

        Repeater {
            model: scene.look.clouds

            delegate: CloudShape {
                id: cloud

                required property int index

                readonly property var place: scene.cloudPlace(index)
                /** How far it stands: the near clouds shift most with the mouse. */
                readonly property real depth: [5, 9, 14][place.layer]

                x: place.x
                y: place.y
                z: place.layer
                width: place.width
                height: place.height
                opacity: 0
                seed: index
                lightFromLeft: !scene.current.isDay || scene.orbit.progress < 0.5
                // The far clouds take a little of the colour of the sky, as distance does.
                lit: place.layer === 0 ? Sky.mixHex(scene.cloudLit, scene.sky.middle, 0.25) : scene.cloudLit
                shade: place.layer === 0 ? Sky.mixHex(scene.cloudShade, scene.sky.middle, 0.3) : scene.cloudShade
                transform: Translate {
                    x: scene.tiltX * cloud.depth
                    y: scene.tiltY * cloud.depth * 0.5
                }

                // A cloud that comes with a change of weather drifts in faintly, then fills out.
                NumberAnimation on opacity {
                    to: cloud.place.opacity
                    duration: scene.moving ? 2500 : 0
                }
            }
        }
    }

    // The light of the sun on the whole scene: it fades as a cloud passes in front, and comes back.
    Rectangle {
        anchors.fill: parent
        radius: scene.radius
        visible: scene.current.isDay && scene.look.clouds > 0
        color: "#10182a"
        opacity: scene.sunCover * 0.16 * scene.look.celestialOpacity
    }

    Fading {
        strength: scene.look.rainbow ? 1 : 0
        fade: 4000

        sourceComponent: Rainbow {
            sunOnLeft: scene.orbit.progress < 0.5
        }
    }

    // Fog: wide layers that thicken and thin out in turn, and sway a little.
    Repeater {
        model: scene.look.fog ? 3 : 0

        delegate: Rectangle {
            id: band

            required property int index

            readonly property real start: Scene.noise(index, 21)
            readonly property real swell: Math.sin((scene.driftClock * (1 + index) + start) * 2 * Math.PI)

            width: scene.width
            height: scene.height * 0.42
            y: scene.height * (0.08 + 0.24 * index) + swell * scene.height * 0.03
            opacity: 0.55 + 0.3 * swell

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "#00ffffff"
                }

                GradientStop {
                    position: 0.5
                    color: "#77ffffff"
                }

                GradientStop {
                    position: 1
                    color: "#00ffffff"
                }
            }
        }
    }

    // Wind strong enough to be seen: thin streaks rushing across, and leaves tumbling with them.
    Repeater {
        model: scene.look.streaks

        delegate: Rectangle {
            id: streak

            required property int index

            readonly property real start: Scene.noise(index, 111)
            readonly property int laps: 3 + Math.floor(Scene.noise(index, 112) * 3)
            readonly property real travel: (scene.gustClock * laps + start) % 1

            width: scene.width * (0.12 + Scene.noise(index, 113) * 0.16)
            height: 1.8
            radius: 0.9
            x: (scene.windSign > 0 ? travel : 1 - travel) * (scene.width + width * 2) - width
            y: scene.height * (0.1 + Scene.noise(index, 114) * 0.7) + Math.sin(travel * 2 * Math.PI) * 4
            opacity: 0.15 + Math.sin(Math.PI * travel) * 0.6

            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop {
                    position: 0
                    color: "#00ffffff"
                }

                GradientStop {
                    position: 0.5
                    color: "#ccffffff"
                }

                GradientStop {
                    position: 1
                    color: "#00ffffff"
                }
            }
        }
    }

    Repeater {
        model: scene.look.leaves

        delegate: Leaf {
            id: leaf

            required property int index

            readonly property real start: Scene.noise(index, 121)
            readonly property int laps: 1 + Math.floor(Scene.noise(index, 122) * 2)
            readonly property real travel: (scene.gustClock * laps + start) % 1

            width: 9 + Scene.noise(index, 123) * 6
            height: width * 0.55
            x: (scene.windSign > 0 ? travel : 1 - travel) * (scene.width + width * 2) - width
            y: scene.height * (0.25 + Scene.noise(index, 124) * 0.55) + Math.sin((travel * 3 + start) * 2 * Math.PI) * scene.height * 0.08
            rotation: travel * 720 * (Scene.noise(index, 125) > 0.5 ? 1 : -1)
            opacity: Math.min(1, Math.sin(Math.PI * travel) * 2)
            colour: ["#d9822b", "#c0452b", "#e0b03a", "#9a8a2e"][Math.floor(Scene.noise(index, 126) * 4)]
        }
    }

    // The land, in front of the far sky and behind what falls; not made at all while there is none,
    // which a new widget starts with: hidden, it was still drawn at every opening.
    Loader {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.height * scene.landscapeHeight / 100
        active: scene.landscape !== "none"

        sourceComponent: Landscape {
            kind: scene.landscape
            isDay: scene.current.isDay
            horizon: scene.sky.bottom
            warmth: scene.warmth
            // In tenths: the snow settles over seconds, and the land is drawn again at each step.
            snow: scene.look.snowCover > 0 ? Math.round(scene.settled * 10) / 10 : 0
            lightAt: 0.08 + 0.84 * scene.orbit.progress
            season: Land.seasonOf(scene.today.date, scene.latitude)
            wind: Scene.toKmh(scene.current.windSpeed, scene.windUnit)
            tilt: scene.tiltX
            running: scene.moving
        }
    }

    Item {
        id: rainLayer

        anchors.fill: parent
        opacity: scene.look.rain > 0 ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 2000
            }
        }

        onOpacityChanged: {
            if (opacity === 0) {
                scene.rainLeft = 0;
            }
        }

        Repeater {
            model: scene.rainCount

            delegate: Rectangle {
                id: drop

                required property int index

                /** 0 far away, 1 close: closer drops are longer, brighter and faster. */
                readonly property real depth: Scene.noise(index, 31)
                readonly property real start: Scene.noise(index, 32)
                readonly property real column: Scene.noise(index, 33)
                readonly property int laps: 4 + Math.floor(depth * 5)
                readonly property real fall: (scene.fallClock * laps + start) % 1

                width: 1 + depth * 1.2
                height: 9 + depth * 12
                radius: width / 2
                color: "#ffffff"
                opacity: 0.22 + depth * 0.38
                rotation: -scene.look.slant * scene.windSign
                // Leaning rain enters from beyond the edge it is blown from.
                x: column * (scene.width + Math.abs(scene.lean) * scene.height) - Math.max(0, scene.lean) * scene.height + fall * scene.lean * scene.height
                y: fall * (scene.height + height * 2) - height
            }
        }
    }

    Item {
        id: snowLayer

        anchors.fill: parent
        opacity: scene.look.snow > 0 ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 2000
            }
        }

        onOpacityChanged: {
            if (opacity === 0) {
                scene.snowLeft = 0;
            }
        }

        Repeater {
            model: scene.snowCount

            delegate: Rectangle {
                id: flake

                required property int index

                readonly property real depth: Scene.noise(index, 41)
                readonly property real start: Scene.noise(index, 42)
                readonly property real column: Scene.noise(index, 43)
                readonly property real sway: Scene.noise(index, 44)
                readonly property int laps: 1 + Math.floor(depth * 2.99)
                readonly property real fall: (scene.fallClock * laps + start) % 1
                readonly property real size: 2 + depth * 4

                width: size
                height: size
                radius: size / 2
                color: "#ffffff"
                opacity: 0.45 + depth * 0.5
                x: column * scene.width + Math.sin((fall * 2 + sway) * 2 * Math.PI) * (6 + depth * 10) + fall * scene.look.slant * scene.windSign
                y: fall * (scene.height + size * 2) - size
            }
        }
    }

    Rectangle {
        id: flash

        anchors.fill: parent
        radius: scene.radius
        color: "#ffffff"
        opacity: 0
    }

    Canvas {
        id: bolt

        /** Counts the strikes; every strike draws another bolt. */
        property int strike: 0

        anchors.fill: parent
        // A still picture of a storm shows its lightning.
        opacity: scene.look.lightning && scene.quality === "off" ? 0.9 : 0

        onPaint: {
            const context = getContext("2d");
            const segments = 7;
            let x = width * (0.2 + 0.6 * Scene.noise(strike, 51));

            context.clearRect(0, 0, width, height);
            context.strokeStyle = "rgba(255, 255, 240, 0.95)";
            context.lineWidth = 2;
            context.lineJoin = "miter";
            context.beginPath();
            context.moveTo(x, 0);

            for (let segment = 1; segment <= segments; segment++) {
                x += (Scene.noise(strike * 9 + segment, 52) - 0.5) * width * 0.12;
                context.lineTo(x, height * 0.65 * segment / segments);
            }

            context.stroke();
        }
        onStrikeChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    Timer {
        running: scene.moving && scene.look.lightning
        interval: 2500 + Scene.noise(bolt.strike, 53) * 6000
        repeat: true

        onTriggered: {
            bolt.strike++;
            strikeAnimation.restart();
        }
    }

    SequentialAnimation {
        id: strikeAnimation

        ParallelAnimation {
            NumberAnimation {
                target: flash
                property: "opacity"
                to: 0.55
                duration: 60
            }

            NumberAnimation {
                target: bolt
                property: "opacity"
                to: 1
                duration: 40
            }
        }

        NumberAnimation {
            target: flash
            property: "opacity"
            to: 0.1
            duration: 90
        }

        NumberAnimation {
            target: flash
            property: "opacity"
            to: 0.4
            duration: 50
        }

        ParallelAnimation {
            NumberAnimation {
                target: flash
                property: "opacity"
                to: 0
                duration: 350
            }

            NumberAnimation {
                target: bolt
                property: "opacity"
                to: 0
                duration: 300
            }
        }
    }

    HeatHaze {
        anchors.fill: parent
        running: scene.moving && scene.look.heat
        opacity: scene.look.heat ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 3000
            }
        }
    }

    // Over a landscape the snow settles on the land itself.
    Loader {
        anchors.fill: parent
        active: scene.landscape === "none" && scene.settled > 0

        sourceComponent: SnowBank {
            // In tenths, as on the land: the snow settles over seconds, and it was drawn again at every frame.
            depth: (0.05 + 0.07 * Math.max(scene.look.snowCover, 0.5)) * Math.round(scene.settled * 10) / 10
        }
    }

    // Rain on the glass in front of it all.
    Glass {
        anchors.fill: parent
        drops: scene.look.glassDrops
        running: scene.moving
    }

    // Darkens the lower part a little, so that the text on the scene stays readable on a bright sky.
    Rectangle {
        anchors.fill: parent
        radius: scene.radius

        gradient: Gradient {
            GradientStop {
                position: 0.35
                color: "#00000000"
            }

            GradientStop {
                position: 1
                color: "#40000000"
            }
        }
    }

    Fading {
        strength: scene.look.frost ? 1 : 0
        fade: 4000

        sourceComponent: Frost {}
    }
}
