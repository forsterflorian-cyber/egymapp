import Toybox.WatchUi;
import Toybox.Lang;

// ==========================================
// EGYMProgChangeConfirmDelegate.mc
// ==========================================

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
            _view.updateProgram(progIndex);
        } else {
            _view._pendingProgChange = -1;
        }
        
        return true;
    }
}