import Toybox.WatchUi;
import Toybox.Lang;

// ==========================================
// EGYMProgChangeConfirmDelegate.mc
// ==========================================

(:high_res)
class EGYMProgChangeConfirmDelegate extends WatchUi.ConfirmationDelegate {
    
    private var _viewRef as WeakReference;

    function initialize(view as EGYMView) {
        ConfirmationDelegate.initialize();
        _viewRef = view.weak();
    }

    function onResponse(response as WatchUi.Confirm) as Boolean {
        if (!_viewRef.stillAlive()) { 
            return true; 
        }
        
        var _view = _viewRef.get() as EGYMView?;
        if (_view == null) { 
            return true; 
        }

        if (response == WatchUi.CONFIRM_YES) {
            var progIndex = _view._pendingProgChange;
            _view._pendingProgChange = -1;
            if (!_view.updateProgram(progIndex)) {
                WatchUi.pushView(
                    new WatchUi.Confirmation("FIT-Session konnte nicht gestartet werden."),
                    new EGYMNoopConfirmDelegate(),
                    WatchUi.SLIDE_UP
                );
            }
        } else {
            _view._pendingProgChange = -1;
        }
        
        return true;
    }
}
