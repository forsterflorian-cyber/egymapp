import Toybox.WatchUi;
import Toybox.Lang;

class EGYMMenuDelegate extends WatchUi.Menu2InputDelegate {

    private const ID_FINISH  = "finish";
    private const ID_DISCARD = "discard";

    private var _viewRef as WeakReference;

    function initialize(view as EGYMView) {
        Menu2InputDelegate.initialize();
        _viewRef = view.weak();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var view = getView();
        if (view == null) { return; }

        var id = item.getId();
        if (id == null) { return; }

        var idStr = (id instanceof String) ? (id as String) : id.toString();

        // --- Finish workout ---
        if (idStr.equals(ID_FINISH)) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            view.forceEndZirkel();
            return;
        }

        // --- Discard workout ---
        if (idStr.equals(ID_DISCARD)) {
            WatchUi.switchToView(
                new WatchUi.Confirmation(
                    WatchUi.loadResource(Rez.Strings.UIConfirmDiscard) as String
                ),
                new EGYMDiscardConfirmDelegate(view),
                WatchUi.SLIDE_UP
            );
            return;
        }
    }

    // --------------------------------------------------------
    // Helper
    // --------------------------------------------------------

    private function getView() as EGYMView? {
        if (!_viewRef.stillAlive()) {
            return null;
        }
        return _viewRef.get() as EGYMView?;
    }
}
