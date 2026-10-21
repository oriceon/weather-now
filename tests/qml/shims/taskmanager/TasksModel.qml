import QtQuick

// A stand-in for the windows of the task manager of Plasma: none, unless a run adds some.
ListModel {
    enum GroupMode {
        GroupDisabled,
        GroupApplications
    }

    property int groupMode
    property rect screenGeometry
    property var virtualDesktop
    property string activity
    property bool filterByScreen
    property bool filterByVirtualDesktop
    property bool filterByActivity
    property bool filterMinimized
}
