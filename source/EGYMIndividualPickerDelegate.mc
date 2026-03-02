import Toybox.WatchUi;
import Toybox.Lang;

class EGYMIndividualPickerDelegate extends WatchUi.Menu2InputDelegate {

    private const PREFIX_EX = "ind_ex_";
    private const PREFIX_LEN = 7; // "ind_ex_".length()
    private const ID_FINISH = "ind_finish";
    private const ID_MODE_INFO = "ind_mode_info";
    private const ID_UNDO_LAST = "ind_undo_last";

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

        if (idStr.equals(ID_FINISH)) {
            view.isWaitingForExercisePick = false;
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            view._individualPickMode = view.IND_PICK_ADD;
            view.forceEndZirkel();
            return;
        }

        if (idStr.equals(ID_MODE_INFO)) {
            view.isWaitingForExercisePick = true;
            return;
        }

        if (idStr.equals(ID_UNDO_LAST)) {
            view.handleIndividualUndoFromPicker();
            return;
        }

        if (idStr.length() > PREFIX_LEN &&
            idStr.substring(0, PREFIX_LEN).equals(PREFIX_EX)) {

            var idx = idStr.substring(PREFIX_LEN, idStr.length()).toNumber();
            if (idx != null && idx >= 0) {
                var exercises = EGYMConfig.getAllExercises();
                if (idx < exercises.size()) {
                    view.isWaitingForExercisePick = false;
                    WatchUi.popView(WatchUi.SLIDE_DOWN);
                    view.onIndividualExercisePicked(exercises[idx]);
                    return;
                }
            }
        }
    }

    function onBack() as Void {
        var view = getView();
        if (view == null) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            return;
        }

        view.handleIndividualPickerCancel();
    }

    private function getView() as EGYMView? {
        if (!_viewRef.stillAlive()) {
            return null;
        }
        return _viewRef.get() as EGYMView?;
    }
}
