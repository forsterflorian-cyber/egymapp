import Toybox.Application;
import Toybox.Application;
import Toybox.WatchUi;
import Toybox.Lang;

(:low_mem)
class EGYMLowMemPickerLauncher {
    public static function openIndividualPicker(state as Dictionary, replaceCurrentView as Boolean) as Void {
        var menu = new WatchUi.Menu2({ :title => EGYMInstinctText.getNextLabel() });
        menu.addItem(new WatchUi.MenuItem(
            EGYMInstinctText.getDoneLabel(),
            null,
            "ind_finish",
            EGYMBuildProfile.getMenuItemOptions()
        ));

        var zirkel = (state[:zirkel] as Array<String>?) != null
            ? (state[:zirkel] as Array<String>)
            : ([] as Array<String>);
        if (zirkel.size() > 0) {
            menu.addItem(new WatchUi.MenuItem(
                EGYMInstinctText.getUndoLabel(),
                null,
                "ind_undo_last",
                EGYMBuildProfile.getMenuItemOptions()
            ));
        }

        var exercises = EGYMConfig.getAllExercises();
        for (var i = 0; i < exercises.size(); i++) {
            menu.addItem(new WatchUi.MenuItem(
                truncateName(EGYMInstinctText.getExerciseName(exercises[i])),
                null,
                "ind_ex_" + i.toString(),
                EGYMBuildProfile.getMenuItemOptions()
            ));
        }

        if (replaceCurrentView) {
            WatchUi.switchToView(menu, new EGYMIndividualPickerDelegate(state), WatchUi.SLIDE_IMMEDIATE);
        } else {
            WatchUi.switchToView(menu, new EGYMIndividualPickerDelegate(state), WatchUi.SLIDE_IMMEDIATE);
        }
    }

    public static function restoreWorkoutView(state as Dictionary) as EGYMViewLowMem {
        var view = new EGYMViewLowMem();
        view.restoreAtomicState(state);
        var app = Application.getApp() as EGYMApp;
        app.mView = view;
        return view;
    }

    private static function truncateName(name as String) as String {
        if (name.length() <= 10) {
            return name;
        }
        return name.substring(0, 10) + "..";
    }
}
