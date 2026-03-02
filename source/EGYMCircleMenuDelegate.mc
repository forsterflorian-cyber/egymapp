import Toybox.WatchUi;
import Toybox.Lang;

// ============================================================
// EGYMCircleMenuDelegate — Handles selection in the circle/
// Zirkel submenu. Persists the choice and updates the parent
// menu item's sublabel to reflect the new selection.
// ============================================================

class EGYMCircleMenuDelegate extends WatchUi.Menu2InputDelegate {

    private const CIRCLE_PREFIX = "circle_";
    private const CIRCLE_PREFIX_LEN = 7;

    private const CIRCLE_MIN = 0;
    private const CIRCLE_MAX = 3;

    private var _parentItem as WatchUi.MenuItem;

    // ========================================================
    // INITIALIZATION
    // ========================================================

    function initialize(parentItem as WatchUi.MenuItem) {
        Menu2InputDelegate.initialize();
        _parentItem = parentItem;
    }

    // ========================================================
    // SELECTION HANDLER
    // ========================================================

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == null) {
            return;
        }
        
        var idStr = (id instanceof String) ? (id as String) : id.toString();

        var prefixIdx = idStr.find(CIRCLE_PREFIX);
        if (prefixIdx == null || prefixIdx != 0) {
            return;
        }

        var indexStr = idStr.substring(CIRCLE_PREFIX_LEN, idStr.length());
        var circleIndex = indexStr.toNumber();

        if (circleIndex == null || circleIndex < CIRCLE_MIN || circleIndex > CIRCLE_MAX) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return;
        }

        EGYMSafeStore.setPropertyValue(EGYMKeys.ACTIVE_CIRCLE, circleIndex);

        _parentItem.setSubLabel(EGYMConfig.getCircleName());

        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
