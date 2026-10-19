pragma ComponentBehavior: Bound

import QtQuick

import "../../code/moon.mjs" as MoonPhase
import "../../code/scene.mjs" as Scene
import "../../code/sky.mjs" as Sky

/**
 * The animated picture of the current weather: a sky that follows the hour, the sun or the
 * moon on its way across it, clouds drifting with the wind, and whatever falls.
 */
Item {
    id: scene

    /** `current` and `today` of the parsed forecast. */
    required property var current
    required property var today
    required property string windUnit
    /** full | reduced | off; "off" is a still picture. */
    required property string quality
    /** Lets the owner stop the motion while the scene is not on screen. */
    property bool running: true
    property real radius: 0

    readonly property bool moving: running && quality !== "off"
    readonly property var look: Scene.sceneFor({
        weatherCode: current.conditionCode,
        isDay: current.isDay,
        windKmh: Scene.toKmh(current.windSpeed, windUnit),
        quality: quality,
    })
    readonly property var orbit: Scene.celestial(current.time, today.sunrise, today.sunset)
    readonly property var sky: Sky.skyGradient(look.family, current.isDay, Scene.twilight(current.time, today.sunrise, today.sunset))
    /** Wind from the western half of the compass carries the clouds and the rain to the right. */
    readonly property int windSign: current.windDirection > 180 ? 1 : -1
    readonly property real lean: Math.tan(look.slant * Math.PI / 180) * windSign

    /** Red, green and blue of the clouds, by day and by night. */
    readonly property var cloudTones: ({
        white: [[255, 255, 255], [150, 162, 190]],
        grey: [[206, 213, 223], [96, 106, 128]],
        dark: [[118, 126, 144], [62, 68, 86]],
    })
    readonly property var cloudTone: cloudTones[look.cloudTone][current.isDay ? 0 : 1]

    /**
     * Where everything that falls (fallClock) or drifts (driftClock) is, from 0 to 1, over and
     * over. While the scene does not move they keep their value, which gives the still picture.
     */
    property real fallClock: 0.37
    property real driftClock: 0.21

    clip: true

    NumberAnimation on fallClock {
        running: scene.moving && (scene.look.rain > 0 || scene.look.snow > 0)
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

    Rectangle {
        anchors.fill: parent
        radius: scene.radius

        gradient: Gradient {
            GradientStop {
                position: 0
                color: scene.sky.top
            }

            GradientStop {
                position: 1
                color: scene.sky.bottom
            }
        }
    }

    Repeater {
        model: scene.look.stars

        delegate: Rectangle {
            id: star

            required property int index

            readonly property real size: 1 + Scene.noise(index, 3) * 1.8

            x: Scene.noise(index, 1) * scene.width
            y: Scene.noise(index, 2) * scene.height * 0.7
            width: size
            height: size
            radius: size / 2
            color: "#ffffff"
            opacity: 0.35 + Scene.noise(index, 4) * 0.65

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

    // The sun or the moon, on an arc from one side of the sky to the other.
    Item {
        readonly property real size: Math.min(scene.width, scene.height) * 0.34

        x: (0.08 + 0.84 * scene.orbit.progress) * scene.width - size / 2
        y: (0.6 - 0.48 * Math.sin(Math.PI * scene.orbit.progress)) * scene.height - size / 2
        width: size
        height: size
        opacity: scene.look.celestialOpacity

        SunDisc {
            anchors.fill: parent
            visible: scene.current.isDay
            running: scene.moving && visible
        }

        MoonDisc {
            anchors.fill: parent
            visible: !scene.current.isDay
            phase: MoonPhase.moonPhase(scene.today.date).fraction
        }
    }

    Repeater {
        model: scene.look.clouds

        delegate: CloudShape {
            id: cloud

            required property int index

            readonly property real start: Scene.noise(index, 11)
            /** Crossings of the sky per round of the clock: some clouds are faster. */
            readonly property int laps: 1 + Math.floor(Scene.noise(index, 13) * 2)
            readonly property real travel: (scene.driftClock * laps + start) % 1

            width: scene.width * (0.42 + Scene.noise(index, 12) * 0.34)
            height: width * 0.42
            x: (scene.windSign > 0 ? travel : 1 - travel) * (scene.width + width) - width
            y: scene.height * (-0.08 + Scene.noise(index, 14) * 0.4)
            opacity: 0.6 + Scene.noise(index, 15) * 0.35
            seed: index
            tone: scene.cloudTone
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

    Repeater {
        model: scene.look.rain

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

    Repeater {
        model: scene.look.snow

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
}
