import Toybox.Application;
import Toybox.WatchUi;
import Toybox.Lang;

(:high_res)
class EGYMStatsDelegate extends WatchUi.BehaviorDelegate {
    private var _statsViewRef as WeakReference?;

    function initialize(view as EGYMStatsView) {
        BehaviorDelegate.initialize();
        _statsViewRef = view.weak();
    }

    function onPreviousPage() as Boolean {
        var statsView = _getStatsViewOrNull();
        if (statsView == null) {
            return false;
        }
        statsView.scrollUp();
        return true;
    }

    function onNextPage() as Boolean {
        var statsView = _getStatsViewOrNull();
        if (statsView == null) {
            return false;
        }
        statsView.scrollDown();
        return true;
    }

    function onSelect() as Boolean {
        var statsView = _getStatsViewOrNull();
        if (statsView == null) {
            return false;
        }
        return statsView.cycleFilter();
    }

    (:is_instinct)
    function onBack() as Boolean {
        _releaseView();
        var app = Application.getApp() as EGYMApp;
        WatchUi.switchToView(
            app.createStartMenu(),
            new EGYMStartMenuDelegate(),
            WatchUi.SLIDE_DOWN
        );
        return true;
    }

    (:high_res)
    function onBack() as Boolean {
        _releaseView();
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    private function _releaseView() as Void {
        var statsView = _getStatsViewOrNull();
        if (statsView != null) {
            statsView.release();
        }
        _statsViewRef = null;
    }

    private function _getStatsViewOrNull() as EGYMStatsView? {
        if (_statsViewRef == null || !_statsViewRef.stillAlive()) {
            return null;
        }
        return _statsViewRef.get() as EGYMStatsView?;
    }
}
