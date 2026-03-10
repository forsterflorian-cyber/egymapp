import Toybox.WatchUi;
import Toybox.Lang;

(:high_res)
class EGYMResumeCheckpointConfirmDelegate extends WatchUi.ConfirmationDelegate {

    private var _menuRef as WeakReference;
    private var _viewRef as WeakReference;

    function initialize(menuDelegate as EGYMStartMenuDelegate, view as EGYMView) {
        ConfirmationDelegate.initialize();
        _menuRef = menuDelegate.weak();
        _viewRef = view.weak();
    }

    function onResponse(response as WatchUi.Confirm) as Boolean {
        if (!_menuRef.stillAlive() || !_viewRef.stillAlive()) {
            return true;
        }

        var menu = _menuRef.get() as EGYMStartMenuDelegate?;
        var view = _viewRef.get() as EGYMView?;
        if (menu == null || view == null) {
            return true;
        }

        menu.handleResumeCheckpointResponse(response == WatchUi.CONFIRM_YES, view);
        return true;
    }
}
