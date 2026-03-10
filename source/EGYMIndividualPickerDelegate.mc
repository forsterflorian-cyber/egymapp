import Toybox.WatchUi;
import Toybox.WatchUi;
import Toybox.Lang;

class EGYMIndividualPickerDelegate extends WatchUi.Menu2InputDelegate {

    private const PREFIX_EX = "ind_ex_";
    private const PREFIX_LEN = 7; // "ind_ex_".length()
    private const ID_FINISH = "ind_finish";
    private const ID_MODE_INFO = "ind_mode_info";
    private const ID_UNDO_LAST = "ind_undo_last";

    private var _state as Dictionary;

    function initialize(state as Dictionary) {
        Menu2InputDelegate.initialize();
        _state = state;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == null) { return; }

        var idStr = (id instanceof String) ? (id as String) : id.toString();
        var view = restoreView();

        if (idStr.equals(ID_FINISH)) {
            view.isWaitingForExercisePick = false;
            view._individualPickMode = view.IND_PICK_ADD;
            view.scheduleProgramMenuLaunch();
            switchBack(view);
            return;
        }

        if (idStr.equals(ID_MODE_INFO)) {
            view.isWaitingForExercisePick = true;
            switchBack(view);
            return;
        }

        if (idStr.equals(ID_UNDO_LAST)) {
            view.applyIndividualUndoFromPickerAtomic();
            switchBack(view);
            return;
        }

        if (idStr.length() > PREFIX_LEN &&
            idStr.substring(0, PREFIX_LEN).equals(PREFIX_EX)) {

            var idx = idStr.substring(PREFIX_LEN, idStr.length()).toNumber();
            if (idx != null && idx >= 0) {
                var exercises = EGYMConfig.getAllExercises();
                if (idx < exercises.size()) {
                    view.isWaitingForExercisePick = false;
                    view.onIndividualExercisePicked(exercises[idx]);
                    switchBack(view);
                    return;
                }
            }
        }

        switchBack(view);
    }

    function onBack() as Void {
        var view = restoreView();
        view.applyIndividualPickerCancelAtomic();
        switchBack(view);
    }

    private function restoreView() as EGYMViewLowMem {
        return EGYMLowMemPickerLauncher.restoreWorkoutView(_state);
    }

    private function switchBack(view as EGYMViewLowMem) as Void {
        WatchUi.switchToView(view, new EGYMDelegate(view), WatchUi.SLIDE_IMMEDIATE);
    }
}
