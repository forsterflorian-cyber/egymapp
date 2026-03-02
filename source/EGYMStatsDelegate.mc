import Toybox.WatchUi;
import Toybox.Lang;

class EGYMStatsDelegate extends WatchUi.BehaviorDelegate {
    private var _statsViewRef as WeakReference;

    function initialize(view as EGYMStatsView) {
        BehaviorDelegate.initialize();
        _statsViewRef = view.weak();
    }

    function onPreviousPage() as Boolean {
        if (!_statsViewRef.stillAlive()) { 
            return false; 
        }
        var _statsView = _statsViewRef.get() as EGYMStatsView?;
        if (_statsView != null) {
            _statsView.scrollUp();
            return true;
        }
        return false;
    }

    function onNextPage() as Boolean {
        if (!_statsViewRef.stillAlive()) { 
            return false; 
        }
        var _statsView = _statsViewRef.get() as EGYMStatsView?;
        if (_statsView != null) {
            _statsView.scrollDown();
            return true;
        }
        return false;
    }

    function onSelect() as Boolean {
        if (!_statsViewRef.stillAlive()) {
            return false;
        }
        var _statsView = _statsViewRef.get() as EGYMStatsView?;
        if (_statsView != null) {
            return _statsView.cycleFilter();
        }
        return false;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
