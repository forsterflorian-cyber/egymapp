import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.System;
import Toybox.Timer;
// ============================================================
// EGYMStartMenuDelegate - Handles all interactions on the
// main start menu: program selection, circle selection,
// test-mode toggle, workout start, and statistics.
// ============================================================

class EGYMStartMenuDelegate extends WatchUi.Menu2InputDelegate {

    // Cached test-mode state (synced with Properties on toggle)
    private var _isTestMode as Boolean = false;

    // Double-tap guard for START button
    private var _trainingStarted as Boolean = false;

    // Timer to reset the double-tap guard after 1 second
    private var _resetTimer as Timer.Timer? = null;

    // ========================================================
    // INITIALIZATION
    // ========================================================

    function initialize() {
        Menu2InputDelegate.initialize();
        _isTestMode = EGYMSafeStore.getPropertyBool(EGYMKeys.IS_TEST_MODE, false);
    }

    private function getWorkoutView() as EGYMView {
        var app = Application.getApp() as EGYMApp;
        return app.ensureMainView();
    }

    // ========================================================
    // MENU ITEM HANDLER
    // ========================================================

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == null) {
            return;
        }
        
        var idStr = (id instanceof String) ? (id as String) : id.toString();
        var app = Application.getApp() as EGYMApp;

        if (!idStr.equals("reset_calibration")) {
            app.clearCalibrationResetState();
        }

        if (idStr.equals("select_program")) {
            openProgramMenu(item);
            return;
        }

        if (idStr.equals("select_circle")) {
            openCircleMenu(item);
            return;
        }

        if (idStr.equals("toggle_test")) {
            handleTestToggle(item);
            return;
        }

        if (idStr.equals("repeat_last_setup")) {
            applyLastSetup(getWorkoutView());
            return;
        }
        if (idStr.equals("repeat_last_freeflow")) {
            startSavedFreeflow(getWorkoutView());
            return;
        }
        if (idStr.equals("start_workout")) {
            startTraining(getWorkoutView());
            return;
        }

        if (idStr.equals("open_stats")) {
            var statsView = new EGYMStatsView();
            WatchUi.pushView(
                statsView,
                new EGYMStatsDelegate(statsView),
                WatchUi.SLIDE_UP
            );
            return;
        }

        if (idStr.equals("reset_calibration")) {

            if (app.isCalibrationResetPending()) {
                app.resetLearnedCalibration();
                app.markCalibrationResetDone();
            } else {
                app.beginCalibrationReset();
            }

            var freshMenu = app.createStartMenu();
            WatchUi.switchToView(
                freshMenu,
                new EGYMStartMenuDelegate(),
                WatchUi.SLIDE_IMMEDIATE
            );
            return;
        }

    }

    // ========================================================
    // SUBMENU: Program Selection
    // ========================================================

    private function openProgramMenu(parentItem as WatchUi.MenuItem) as Void {
        var app = Application.getApp() as EGYMApp;
        var menuTitle = WatchUi.loadResource(Rez.Strings.UIMenuProgram) as String;
        var progMenu = new WatchUi.Menu2({ :title => menuTitle });
        var programs = EGYMConfig.getActivePrograms();
        var repsLabel = WatchUi.loadResource(Rez.Strings.UIReps).toString();

        var label = "";
        var subLabel = "";

        for (var i = 0; i < programs.size(); i++) {
            var p = programs[i] as Dictionary;

            label = EGYMConfig.getProgramPrefix(p) + " " + app.getGoalName(EGYMConfig.getProgramGoalKey(p));
            subLabel = app.getMethodName(EGYMConfig.getProgramMethodKey(p)) + " " + EGYMConfig.getProgramRepsSpec(p) + " " + repsLabel;

            progMenu.addItem(
                new WatchUi.MenuItem(label, subLabel, "prog_" + i.toString(), {})
            );
        }

        WatchUi.pushView(
            progMenu,
            new ProgramMenuDelegate(parentItem),
            WatchUi.SLIDE_LEFT
        );
    }

    // ========================================================
    // SUBMENU: Circle Selection
    // ========================================================

    private function openCircleMenu(parentItem as WatchUi.MenuItem) as Void {
        var circleMenu = new WatchUi.Menu2({
            :title => WatchUi.loadResource(Rez.Strings.UIChooseCircle) as String
        });

        circleMenu.addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.UIStrength) as String,
            WatchUi.loadResource(Rez.Strings.UIStrengthSub) as String,
            "circle_0", {}
        ));

        circleMenu.addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.UILegs) as String,
            WatchUi.loadResource(Rez.Strings.UILegsSub) as String,
            "circle_1", {}
        ));

        circleMenu.addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.UICustomCircuit) as String,
            WatchUi.loadResource(Rez.Strings.UICustomCircuitSub) as String,
            "circle_2", {}
        ));

        circleMenu.addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.UIIndividual) as String,
            WatchUi.loadResource(Rez.Strings.UIIndividualSub) as String,
            "circle_3", {}
        ));

        WatchUi.pushView(
            circleMenu,
            new EGYMCircleMenuDelegate(parentItem),
            WatchUi.SLIDE_LEFT
        );
    }

    // ========================================================
    // TOGGLE: Strength Test Mode
    // ========================================================

    private function handleTestToggle(item as WatchUi.MenuItem) as Void {
        if (!(item instanceof WatchUi.ToggleMenuItem)) {
            return;
        }
        var toggleItem = item as WatchUi.ToggleMenuItem;
        _isTestMode = toggleItem.isEnabled();
        EGYMSafeStore.setPropertyValue(EGYMKeys.IS_TEST_MODE, _isTestMode);
    }

    // ========================================================
    // START WORKOUT
    // ========================================================

    private function startTraining(view as EGYMView) as Void {
        var app = Application.getApp() as EGYMApp;
        var circleId = EGYMSafeStore.getPropertyNumber(EGYMKeys.ACTIVE_CIRCLE, 0);
        if (circleId < 0 || circleId > 3) {
            circleId = 0;
            EGYMSafeStore.setPropertyValue(EGYMKeys.ACTIVE_CIRCLE, 0);
        }

        var selectedZirkel = null as Array<String>?;
        var isIndividual = false;

        if (circleId == 0) {
            selectedZirkel = app.copyArray(EGYMConfig.getZirkelKraft());
        } else if (circleId == 1) {
            selectedZirkel = app.copyArray(EGYMConfig.getZirkelBeine());
        } else if (circleId == 2) {
            selectedZirkel = getParsedCustomZirkel(app);
        } else if (circleId == 3) {
            isIndividual = true;
            selectedZirkel = [] as Array<String>;
        }

        var progIndex = view.safeLoadProgIndex();
        startPreparedTraining(view, selectedZirkel, isIndividual, progIndex, circleId, true);
    }

    private function startPreparedTraining(
        view as EGYMView,
        selectedZirkel as Array<String>?,
        isIndividual as Boolean,
        progIndex as Number,
        circleId as Number,
        persistSetup as Boolean
    ) as Void {
        if (_trainingStarted) {
            return;
        }
        _trainingStarted = true;

        var app = Application.getApp() as EGYMApp;
        var activeZirkel = selectedZirkel;
        if (activeZirkel == null || activeZirkel.size() == 0) {
            if (!isIndividual) {
                activeZirkel = app.copyArray(app.getDefaultZirkel());
            }
        }
        if (activeZirkel == null) {
            activeZirkel = [] as Array<String>;
        }

        EGYMSafeStore.setStorageValue(EGYMKeys.LAST_ZIRKEL, activeZirkel);
        if (persistSetup) {
            saveLastSetupSnapshot(progIndex, circleId);
        }
        view.setTestMode(_isTestMode);
        view.updateProgram(progIndex);
        view.isIndividualMode = isIndividual;
        view.zirkel = activeZirkel as Array<String>;
        if (activeZirkel.size() > 0) {
            view.initExercisePhase();
        } else {
            view.refreshLabels();
        }

        WatchUi.pushView(view, new EGYMDelegate(view), WatchUi.SLIDE_LEFT);

        if (_resetTimer != null) {
            _resetTimer.stop();
            _resetTimer = null;
        }
        _resetTimer = new Timer.Timer();
        _resetTimer.start(method(:resetStartFlag), 1000, false);
    }

    function resetStartFlag() as Void {
        _trainingStarted = false;
        _resetTimer = null;
    }

    private function startSavedFreeflow(view as EGYMView) as Void {
        var savedFlow = EGYMSafeStore.getStorageStringArray(EGYMKeys.LAST_SAVED_FREEFLOW);
        if (savedFlow == null || savedFlow.size() == 0) {
            return;
        }

        var progIndex = view.safeLoadProgIndex();
        startPreparedTraining(view, savedFlow, false, progIndex, 0, false);
    }

    private function applyLastSetup(view as EGYMView) as Void {
        if (!EGYMSafeStore.getStorageBool(EGYMKeys.LAST_SETUP_EXISTS, false)) {
            return;
        }

        var circleId = EGYMSafeStore.getStorageNumber(EGYMKeys.LAST_SETUP_CIRCLE, 0);
        if (circleId < 0 || circleId > 3) {
            circleId = 0;
        }

        var progIndex = EGYMSafeStore.getStorageNumber(EGYMKeys.LAST_SETUP_PROGRAM, 0);
        var programs = EGYMConfig.getActivePrograms();
        if (progIndex < 0 || progIndex >= programs.size()) {
            progIndex = 0;
        }

        _isTestMode = EGYMSafeStore.getStorageBool(EGYMKeys.LAST_SETUP_TEST, false);

        EGYMSafeStore.setPropertyValue(EGYMKeys.ACTIVE_CIRCLE, circleId);
        EGYMSafeStore.setPropertyValue(EGYMKeys.ACTIVE_PROGRAM, progIndex);
        EGYMSafeStore.setPropertyValue(EGYMKeys.IS_TEST_MODE, _isTestMode);

        startTraining(view);
    }

    private function saveLastSetupSnapshot(progIndex as Number, circleId as Number) as Void {
        EGYMSafeStore.setStorageValue(EGYMKeys.LAST_SETUP_PROGRAM, progIndex);
        EGYMSafeStore.setStorageValue(EGYMKeys.LAST_SETUP_CIRCLE, circleId);
        EGYMSafeStore.setStorageValue(EGYMKeys.LAST_SETUP_TEST, _isTestMode);
        EGYMSafeStore.setStorageValue(EGYMKeys.LAST_SETUP_EXISTS, true);
    }

    // ========================================================
    // CUSTOM ZIRKEL PARSING
    // ========================================================
    private function getParsedCustomZirkel(app as EGYMApp) as Array<String>? {
        var cached = EGYMSafeStore.getStorageStringArray(EGYMKeys.CUSTOM_ZIRKEL);
        if (cached != null && cached.size() > 0) {
            return cached;
        }

        var str = EGYMSafeStore.getPropertyString(EGYMKeys.ZIRKEL_ORDER, "");
        if (str.length() > 0) {
            var parsed = app.parseZirkelString(str);
            if (parsed.size() > 0) {
                EGYMSafeStore.setStorageValue(EGYMKeys.CUSTOM_ZIRKEL, parsed);
                return parsed;
            }
        }

        // Legacy fallback: convert old mixed arrays into sanitized string arrays.
        try {
            var legacyCached = Storage.getValue(EGYMKeys.CUSTOM_ZIRKEL);
            if (legacyCached != null && legacyCached instanceof Array) {
                var arr = legacyCached as Array;
                var result = [] as Array<String>;
                for (var i = 0; i < arr.size(); i++) {
                    if (arr[i] instanceof String) {
                        result.add(arr[i] as String);
                    }
                }
                if (result.size() > 0) {
                    EGYMSafeStore.setStorageValue(EGYMKeys.CUSTOM_ZIRKEL, result);
                    return result;
                }
            }
        } catch (e) {
            System.println("[EGYM menu] Legacy custom circuit cache read failed.");
        }
        
        return null;
    }
}







