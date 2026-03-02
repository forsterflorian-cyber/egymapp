import Toybox.WatchUi;
import Toybox.Lang;

class EGYMDiagnosticsDelegate extends WatchUi.BehaviorDelegate {
    private var _viewRef as WeakReference;

    function initialize(view as EGYMDiagnosticsView) {
        BehaviorDelegate.initialize();
        _viewRef = view.weak();
    }

    function onSelect() as Boolean {
        if (!_viewRef.stillAlive()) {
            return false;
        }

        var view = _viewRef.get() as EGYMDiagnosticsView?;
        if (view == null) {
            return false;
        }

        view.resetCounters();
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
