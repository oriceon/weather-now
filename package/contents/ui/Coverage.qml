import QtQuick
import org.kde.taskmanager as TaskManager

/**
 * Whether a window fills the screen of the item it is loaded in: maximized or full screen, on the
 * current desktop and activity, and not minimized. The wallpaper, and the widget on the desktop,
 * stand still meanwhile, as nobody sees them. Loaded on its own, through a Loader: where the task
 * manager of Plasma is missing, as on the lock screen, nothing ever counts as covered.
 */
Item {
    id: coverage

    readonly property bool covered: {
        for (let row = 0; row < windows.count; row++) {
            const window = windows.itemAt(row);

            if (window !== null && window.fills) {
                return true;
            }
        }

        return false;
    }

    TaskManager.VirtualDesktopInfo {
        id: desktops
    }

    TaskManager.ActivityInfo {
        id: activities
    }

    TaskManager.TasksModel {
        id: tasks

        groupMode: TaskManager.TasksModel.GroupDisabled
        screenGeometry: Qt.rect(coverage.Screen.virtualX, coverage.Screen.virtualY, coverage.Screen.width, coverage.Screen.height)
        virtualDesktop: desktops.currentDesktop
        activity: activities.currentActivity
        filterByScreen: true
        filterByVirtualDesktop: true
        filterByActivity: true
        filterMinimized: true
    }

    Repeater {
        id: windows

        model: tasks

        delegate: Item {
            readonly property bool fills: model.IsMaximized === true || model.IsFullScreen === true
        }
    }
}
