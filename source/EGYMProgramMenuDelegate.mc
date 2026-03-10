import Toybox.WatchUi;
import Toybox.Lang;

// ==========================================
// ProgramMenuDelegate.mc
// ==========================================

class ProgramMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _parentItem as WatchUi.MenuItem?;

    function initialize(parentItem as WatchUi.MenuItem) {
        Menu2InputDelegate.initialize();
        _parentItem = parentItem;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == null) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return;
        }

        var idStr = (id instanceof String) ? (id as String) : id.toString();

        var indexPos = idStr.find("prog_");
        
        if (indexPos != null && indexPos == 0) {
            var indexString = idStr.substring(5, idStr.length());
            var newIndex = indexString.toNumber();

            if (newIndex != null) {
                EGYMSafeStore.setPropertyValue(EGYMKeys.ACTIVE_PROGRAM, newIndex);

                var programs = EGYMConfig.getActivePrograms();
                var parent = _parentItem;

                if (newIndex >= 0 && newIndex < programs.size() && parent != null && !EGYMBuildProfile.isInstinctLowMemoryBuild()) {
                    var p = programs[newIndex] as Dictionary;
                    var newLabel = EGYMConfig.getProgramDisplayString(p);
                    parent.setSubLabel(newLabel);
                }
            }
        }

        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
