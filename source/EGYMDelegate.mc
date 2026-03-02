import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.WatchUi;

// ============================================================
// EGYMDelegate — Input handler for the active workout screen.
// Handles swipe gestures, tap events, and hardware key presses
// to navigate exercises, adjust weight, scroll records, and
// manage the end-of-round / success overlay screens.
// ============================================================

class EGYMDelegate extends WatchUi.InputDelegate {

    // Weak reference to the workout view (avoids preventing GC)
    private var _viewRef as WeakReference;

    // ========================================================
    // INITIALIZATION
    // ========================================================

    //! @param view The active EGYMView rendering the workout
    function initialize(view as EGYMView) {
        InputDelegate.initialize();
        _viewRef = view.weak();
    }

    // ========================================================
    // HELPER: Safe View Access
    // ========================================================

    //! Returns the EGYMView if it's still alive, or null.
    //! Consolidates the repeated weak-ref check pattern.
    private function getView() as EGYMView? {
        if (!_viewRef.stillAlive()) {
            return null;
        }
        return _viewRef.get() as EGYMView?;
    }

    // ========================================================
    // SWIPE GESTURES
    // ========================================================

    function onSwipe(evt as WatchUi.SwipeEvent) as Boolean {
        var _view = getView();
        if (_view == null) {
            return false;
        }

        var dir = evt.getDirection();

        // --- Swipe UP: weight up or scroll records ---
        if (dir == WatchUi.SWIPE_UP) {
            if (_view.isShowingSuccess) {
                _view.scrollRecords(1);
                return true;
            }
            if (_view.isShowingDiscarded) {
                return true;
            }
            _view.onUpPressed();
            return true;
        }

        // --- Swipe DOWN: weight down or scroll records ---
        if (dir == WatchUi.SWIPE_DOWN) {
            if (_view.isShowingSuccess) {
                _view.scrollRecords(-1);
                return true;
            }
            if (_view.isShowingDiscarded) {
                return true; 
            }
            _view.onDownPressed();
            return true;
        }

        // --- Swipe RIGHT: go back one phase ---
        if (dir == WatchUi.SWIPE_RIGHT) {
            if (_view.isShowingSuccess || _view.isShowingDiscarded || _view.isAskingForNewRound) {
                return true;
            }
            _view.goBackOnePhase();
            return true;
        }

        // --- Swipe LEFT: skip exercise (only during exercise phase) ---
        if (dir == WatchUi.SWIPE_LEFT) {
            if (
                !_view.isShowingSuccess &&
                !_view.isShowingDiscarded &&
                !_view.isAskingForNewRound &&
                _view.currentPhase == _view.PHASE_EXERCISE
            ) {
                _view.skipExercise();
                return true;
            }
        }

        return false;
    }

    // ========================================================
    // TAP EVENTS
    // ========================================================

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var _view = getView();
        if (_view == null) {
            return false;
        }

        var coords = evt.getCoordinates();
        if (coords.size() < 2) {
            return false;
        }
        
        var tx = coords[0] as Number;
        var ty = coords[1] as Number;

        if (_view.isAskingForNewRound) {
            if (isInRect(tx, ty, _view._yesBtnRect)) {
                _view.handleDecision(true);
                return true;
            }
            if (isInRect(tx, ty, _view._noBtnRect)) {
                _view.handleDecision(false);
                return true;
            }
            return false;
        }

        if (_view.isShowingSuccess || _view.isShowingDiscarded) {
            _view.dismissSuccess();
            return true;
        }

        return false;
    }

    // ========================================================
    // HARDWARE KEY EVENTS
    // ========================================================

    function onKey(evt as WatchUi.KeyEvent) as Boolean {
        var _view = getView();
        if (_view == null) {
            return false;
        }

        var key = evt.getKey();

        if (key == WatchUi.KEY_UP) {
            return handleKeyUp(_view);
        }

        if (key == WatchUi.KEY_DOWN) {
            return handleKeyDown(_view);
        }

        if (key == WatchUi.KEY_ENTER) {
            return handleKeyEnter(_view);
        }

        if (key == WatchUi.KEY_ESC) {
            return handleKeyEsc(_view);
        }

        return false;
    }

    // --------------------------------------------------------
    // KEY HANDLERS
    // --------------------------------------------------------

    private function handleKeyUp(view as EGYMView) as Boolean {
        if (view.isShowingSuccess) {
            view.scrollRecords(-1);
            return true;
        }
        if (view.isShowingDiscarded) {
            return true; 
        }
        view.onUpPressed();
        return true;
    }

    private function handleKeyDown(view as EGYMView) as Boolean {
        if (view.isShowingSuccess) {
            view.scrollRecords(1);
            return true;
        }
        if (view.isShowingDiscarded) {
            return true; 
        }
        view.onDownPressed();
        return true;
    }

    private function handleKeyEnter(view as EGYMView) as Boolean {
        if (view.isAskingForNewRound) {
            view.handleDecision(true);
            return true;
        }
        if (view.isShowingSuccess || view.isShowingDiscarded) {
            view.dismissSuccess();
            return true;
        }
        view.advancePhase();
        return true;
    }

    private function handleKeyEsc(view as EGYMView) as Boolean {
        if (view.isShowingSuccess || view.isShowingDiscarded) {
            view.cleanupAndExit();
            return true;
        }

        if (view.isAskingForNewRound) {
            view.handleDecision(false);
            return true;
        }

        if (view.currentPhase == view.PHASE_ADJUST) {
            view.goBackOnePhase();
            return true;
        }

        if (view.currentPhase == view.PHASE_EXERCISE && view.isIndividualMode) {
            view.goBackOnePhase();
            return true;
        }

        if (view.sm.isRecording()) {
            view.openProgramMenu();
            return true;
        }

        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    // ========================================================
    // HIT TESTING
    // ========================================================

    private function isInRect(
        x as Number,
        y as Number,
        rect as Array<Number>?
    ) as Boolean {
        if (rect == null || rect.size() < 4) {
            return false;
        }

        var rX = rect[0] as Number;
        var rY = rect[1] as Number;
        var rW = rect[2] as Number;
        var rH = rect[3] as Number;

        return (x >= rX && x <= rX + rW &&
                y >= rY && y <= rY + rH);
    }

}
