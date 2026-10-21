import QtQuick

// Stands in for the notification of org.kde.notification: says what it would have shown.
QtObject {
    id: notification

    property string componentName
    property string eventId
    property string iconName
    property string title
    property string text

    function sendEvent(): void {
        console.log(`notification: ${notification.title} | ${notification.text}`);
    }
}
