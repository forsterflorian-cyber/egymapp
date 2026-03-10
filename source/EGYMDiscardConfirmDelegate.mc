import Toybox.WatchUi;
import Toybox.Lang;

// ============================================================
// EGYMDiscardConfirmDelegate — Handles the user's response to
// the "Discard workout?" confirmation dialog.
// YES → discards the active recording session
// NO  → dismissed, workout continues
// ============================================================

class EGYMDiscardConfirmDelegate extends WatchUi.ConfirmationDelegate {

    // Weak reference to the workout view that owns the session
    private var _viewRef as WeakReference;

    // ========================================================
    // INITIALIZATION
    // ========================================================

    //! @param view The workout view whose session may be discarded
    function initialize(view) {
        ConfirmationDelegate.initialize();
        _viewRef = view.weak();
    }

    // ========================================================
    // RESPONSE HANDLER
    // ========================================================

    //! Called when the user taps Yes or No on the confirmation dialog.
    function onResponse(response as WatchUi.Confirm) as Boolean {
        if (!_viewRef.stillAlive()) {
            return true;
        }
        
        var _view = _viewRef.get();
        if (_view == null) {
            return true;
        }

        if (response == WatchUi.CONFIRM_YES) {
            try {
                if (_view has :discardSession) {
                    _view.discardSession();
                }
            } catch (e) {
                // Session may already be null or stopped — non-fatal
            }
        }
        
        // CONFIRM_NO: dialog dismissed, workout continues silently
        return true;
    }
}
