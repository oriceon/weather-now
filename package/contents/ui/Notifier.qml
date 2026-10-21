import QtQuick
import org.kde.notification

import "../code/links.mjs" as Links

/**
 * Sends desktop notifications. It is loaded on its own, through a Loader, so that a system
 * without this module loses the notifications and nothing else.
 */
QtObject {
    id: notifier

    readonly property Component message: Component {
        Notification {
            // The events every Plasma session knows, whatever application sends them.
            componentName: "plasma_workspace"
            eventId: "notification"
            // The logo: Plasma takes a path to a picture where it expects the name of an icon.
            iconName: Qt.resolvedUrl("../icons/weather-now.png").toString()
        }
    }

    function send(title: string, text: string): void {
        // A notification deletes itself once it is closed. Its text is read as markup, and a warning
        // may hold any: "< -10 °C" is to read as it is written, a link of the feed not to open.
        message.createObject(notifier, { title: title, text: Links.escapeMarkup(text) }).sendEvent();
    }
}
