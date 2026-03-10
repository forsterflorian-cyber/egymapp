import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.StringUtil;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

(:low_mem)
class EGYMViewLowMem extends WatchUi.View {
    const MAX_WEIGHT = 500;
    const MAX_NAME_LEN = 10;
    const PHASE_EXERCISE = 0;
    const PHASE_ADJUST = 1;
    const PHASE_BREAK = 2;
    const IND_PICK_ADD = 0;
    const IND_PICK_REPLACE = 1;
    const FINISH_RESULT_NO_SESSION = -1;
    const FINISH_RESULT_SAVE_FAILED = 0;
    const FINISH_RESULT_SAVED = 1;
    const UI_FONT_SMALL = Graphics.FONT_TINY;
    const UI_FONT_BODY = Graphics.FONT_MEDIUM;
    const UI_FONT_VALUE = Graphics.FONT_NUMBER_MEDIUM;

    var sm as EGYMSessionManager? = new EGYMSessionManager();
    var workoutEngine as EGYMWorkoutEngine? = new EGYMWorkoutEngine();

    var currentPhase as Number = PHASE_EXERCISE;
    var index as Number = 0;
    var currentRound as Number = 1;
    var currentWeight as Number = 0;
    var qualityValue as Number = 100;
    var activeProg as Number = 0;
    var sessionTotalKg as Number = 0;
    var sessionSetCount as Number = 0;
    var breakStartTime as Number = 0;

    var isIndividualMode as Boolean = false;
    var isWaitingForExercisePick as Boolean = false;
    var isWaitingForTestConfirm as Boolean = false;
    var isShowingSuccess as Boolean = false;
    var isShowingDiscarded as Boolean = false;
    var isShowingSaveFailed as Boolean = false;
    var isAskingForNewRound as Boolean = false;

    var zirkel as Array<String> = [] as Array<String>;
    var _individualPickMode as Number = IND_PICK_ADD;
    var _persistCompletedFreeflowOnSave as Boolean = false;
    var _pendingProgChange as Number = -1;
    var _yesBtnRect as Array<Number>? = null;
    var _noBtnRect as Array<Number>? = null;
    var _pendingIndividualPickerLaunch as Boolean = false;
    var _pendingIndividualPickerReplace as Boolean = false;
    var _pendingProgramMenuLaunch as Boolean = false;

    private var _learnedFactorGeneration as Number = 0;
    private var _cleanNameCache as Dictionary<String, String> = {} as Dictionary<String, String>;
    private var _sessionQualityTotal as Number = 0;
    private var _sessionQualityCount as Number = 0;
    private var _sessionWattTotal as Number = 0;
    private var _sessionWattCount as Number = 0;

    function initialize() {
        View.initialize();
        refreshLearnedCalibrationGeneration();
    }

    function refreshLearnedCalibrationGeneration() as Void {
        _learnedFactorGeneration = EGYMSafeStore.getStorageNumber(EGYMKeys.LEARNED_FACTOR_GEN, 0);
    }

    function setTestMode(status as Boolean) as Void {
        isWaitingForTestConfirm = false;
    }

    function onShow() as Void {
        if (isIndividualMode && zirkel.size() == 0 && !isWaitingForExercisePick) {
            prepareIndividualAddPicker();
        }
    }

    function onHide() as Void {
    }

    function safeLoadProgIndex() as Number {
        var progIndex = EGYMSafeStore.getPropertyNumber(EGYMKeys.ACTIVE_PROGRAM, 0);
        var programs = EGYMConfig.getActivePrograms();
        if (progIndex < 0 || progIndex >= programs.size()) {
            progIndex = 0;
        }
        return progIndex;
    }

    function limitExercisesForProfile(source as Array<String>?) as Array<String> {
        var copy = [] as Array<String>;
        if (source == null) {
            return copy;
        }

        var maxItems = EGYMBuildProfile.getMaxStoredExercises();
        if (maxItems <= 0 || maxItems > source.size()) {
            maxItems = source.size();
        }

        for (var i = 0; i < maxItems; i++) {
            copy.add(source[i]);
        }
        return copy;
    }

    private function copyExercises(source as Array<String>?) as Array<String> {
        var copy = [] as Array<String>;
        if (source == null) {
            return copy;
        }

        for (var i = 0; i < source.size(); i++) {
            copy.add(source[i]);
        }
        return copy;
    }

    function safeGetExercise(idx as Number) as String? {
        if (idx >= 0 && idx < zirkel.size()) {
            return zirkel[idx];
        }
        return null;
    }

    function getKnownExercises() as Array<String> {
        return EGYMConfig.getAllExercises();
    }

    function updateProgram(newIndex as Number) as Boolean {
        activeProg = newIndex;

        if (!EGYMSafeStore.setPropertyValue(EGYMKeys.ACTIVE_PROGRAM, newIndex)) {
            return false;
        }

        var sessionManager = getSessionManager();
        if (sessionManager != null && sessionManager.isRecording()) {
            initExercisePhase();
            WatchUi.requestUpdate();
            return true;
        }

        resetSessionState();
        if (sessionManager != null) {
            sessionManager.cleanup();
        }
        if (sessionManager == null || !sessionManager.createAndStart()) {
            return false;
        }

        initExercisePhase();
        WatchUi.requestUpdate();
        return true;
    }

    function getActiveProg() as Dictionary {
        var programs = EGYMConfig.getActivePrograms();
        if (programs.size() == 0) {
            return {
                :p => "??",
                :g => "GoalMuscleBuild",
                :m => "REGULAR",
                :w => "0",
                :i => 0.0
            };
        }
        if (activeProg < 0 || activeProg >= programs.size()) {
            activeProg = 0;
        }
        return programs[activeProg] as Dictionary;
    }

    private function getWorkoutEngine() as EGYMWorkoutEngine? {
        return workoutEngine;
    }

    function getSessionManager() as EGYMSessionManager? {
        return sm;
    }

    function hasActiveSessionRecording() as Boolean {
        var sessionManager = getSessionManager();
        return sessionManager != null && sessionManager.isRecording();
    }

    function getSavedValue(exName as String, getWatt as Boolean) as Number {
        var key = (getWatt ? EGYMKeys.WATT_PREFIX : EGYMKeys.RM_PREFIX) + cleanExName(exName);
        var propNum = EGYMSafeStore.getPropertyNumber(key, 0);
        var storageNum = EGYMSafeStore.getStorageNumber(key, 0);

        if (propNum > storageNum) {
            EGYMSafeStore.setStorageValue(key, propNum);
            EGYMSafeStore.setStorageValue(key + "_lastSync", propNum);
            return propNum;
        }

        if (storageNum > 0) {
            return storageNum;
        }
        return propNum;
    }

    function setSavedValue(exName as String, isWatt as Boolean, newValue as Number, force as Boolean) as Void {
        var key = (isWatt ? EGYMKeys.WATT_PREFIX : EGYMKeys.RM_PREFIX) + cleanExName(exName);
        var oldValue = EGYMSafeStore.getStorageNumber(key, 0);

        if (!force && newValue <= oldValue) {
            return;
        }

        EGYMSafeStore.setStorageValue(key, newValue);
        EGYMSafeStore.setStorageValue(key + "_lastSync", newValue);
        EGYMSafeStore.setPropertyValue(key, newValue);
    }

    function calcTargetWeight(exName as String) as Number {
        var engine = getWorkoutEngine();
        if (engine == null) {
            return 0;
        }

        var prog = getActiveProg();
        var rm = getSavedValue(exName, false);
        if (rm <= 0) {
            return 0;
        }

        var learnedKey = engine.buildLearnedFactorKey(
            cleanExName(exName),
            EGYMConfig.getProgramPrefix(prog),
            EGYMConfig.getProgramMethodKey(prog),
            engine.getBaseFactorBasis(prog),
            _learnedFactorGeneration
        );
        var learned = EGYMSafeStore.getStorageNumber(learnedKey, 0);
        var factorBasis = engine.resolveActiveFactorBasis(
            engine.getBaseFactorBasis(prog),
            learned
        );
        return engine.computeTargetWeight(rm, factorBasis);
    }

    function initExercisePhase() as Void {
        currentPhase = PHASE_EXERCISE;
        var exName = safeGetExercise(index);
        currentWeight = exName != null ? calcTargetWeight(exName as String) : 0;
        if (currentWeight < 0) {
            currentWeight = 0;
        }

        var engine = getWorkoutEngine();
        if (exName != null && engine != null && engine.isExplosiveMethod(EGYMConfig.getProgramMethodKey(getActiveProg()))) {
            var savedWatt = getSavedValue(exName as String, true);
            qualityValue = savedWatt > 0 ? savedWatt : 100;
        } else {
            qualityValue = 100;
        }
    }

    function refreshLabels() as Void {
    }

    function advancePhase() as Boolean {
        if (isShowingDiscarded || isAskingForNewRound) {
            WatchUi.requestUpdate();
            return true;
        }

        if (currentPhase == PHASE_BREAK) {
            if (isIndividualMode) {
                prepareIndividualAddPicker();
                return true;
            }

            if (index >= zirkel.size() - 1) {
                isAskingForNewRound = true;
                WatchUi.requestUpdate();
                return true;
            }

            var sessionManagerBreak = getSessionManager();
            if (sessionManagerBreak != null) {
                sessionManagerBreak.addLapAndReset();
            }
            index += 1;
            initExercisePhase();
            WatchUi.requestUpdate();
            return true;
        }

        processEndOfSet();
        currentPhase = PHASE_BREAK;
        breakStartTime = System.getTimer();
        WatchUi.requestUpdate();
        return true;
    }

    function onUpPressed() as Void {
        if (isShowingDiscarded || isAskingForNewRound) {
            return;
        }
        if (currentPhase == PHASE_EXERCISE && currentWeight < MAX_WEIGHT) {
            currentWeight += 1;
            WatchUi.requestUpdate();
        }
    }

    function onDownPressed() as Void {
        if (isShowingDiscarded || isAskingForNewRound) {
            return;
        }
        if (currentPhase == PHASE_EXERCISE && currentWeight > 0) {
            currentWeight -= 1;
            WatchUi.requestUpdate();
        }
    }

    function handleDecision(isYes as Boolean) as Void {
        if (!isAskingForNewRound) {
            return;
        }

        if (isYes) {
            var sessionManagerDecision = getSessionManager();
            if (sessionManagerDecision != null) {
                sessionManagerDecision.addLapAndReset();
            }
            index = 0;
            currentRound += 1;
            isAskingForNewRound = false;
            initExercisePhase();
        } else {
            forceEndZirkel();
            return;
        }

        WatchUi.requestUpdate();
    }

    function skipExercise() as Void {
        if (isShowingDiscarded || isAskingForNewRound) {
            return;
        }

        if (isIndividualMode) {
            prepareIndividualReplacePicker();
            return;
        }

        if (index >= zirkel.size() - 1) {
            isAskingForNewRound = true;
        } else {
            index += 1;
            initExercisePhase();
        }
        WatchUi.requestUpdate();
    }

    function goBackOnePhase() as Void {
        if (isShowingDiscarded || isAskingForNewRound) {
            return;
        }

        if (currentPhase == PHASE_BREAK) {
            currentPhase = PHASE_EXERCISE;
            WatchUi.requestUpdate();
            return;
        }

        if (currentPhase == PHASE_EXERCISE && isIndividualMode) {
            prepareIndividualReplacePicker();
        }
    }

    function processEndOfSet() as Void {
        var prog = getActiveProg();
        var exName = safeGetExercise(index);
        if (exName == null) {
            return;
        }

        var engineProcess = getWorkoutEngine();
        if (engineProcess == null) {
            return;
        }

        var reps = engineProcess.parseReps(EGYMConfig.getProgramRepsSpec(prog));
        var methodKey = EGYMConfig.getProgramMethodKey(prog);
        var isExplosive = engineProcess.isExplosiveMethod(methodKey);
        var factor = isExplosive ? 1.0 : (qualityValue / 100.0);
        var workload = (currentWeight * factor * reps).toNumber();

        sessionSetCount += 1;
        sessionTotalKg += workload;

        if (isExplosive) {
            _sessionWattTotal += qualityValue;
            _sessionWattCount += 1;
            var oldWatt = getSavedValue(exName as String, true);
            if (qualityValue > oldWatt) {
                setSavedValue(exName as String, true, qualityValue, false);
            }
        } else {
            _sessionQualityTotal += qualityValue;
            _sessionQualityCount += 1;
        }

        var sessionManagerProcess = getSessionManager();
        if (sessionManagerProcess != null) {
            sessionManagerProcess.writeLapData(
                fitSafeString(EGYMInstinctText.getExerciseName(exName as String)),
                workload,
                reps,
                currentWeight,
                qualityValue
            );
        }
    }

    function persistSessionCheckpoint(reason as String) as Boolean {
        return true;
    }

    function emergencyStopAndSave() as Boolean {
        var sessionManagerEmergency = getSessionManager();
        if (sessionManagerEmergency == null || !sessionManagerEmergency.hasSession() || !hasWorkoutProgress()) {
            return false;
        }

        var prog = getActiveProg();
        var saved = sessionManagerEmergency.stopAndSave(
            sessionTotalKg,
            progDisplayName(prog),
            getSessionAverageFitValue(),
            methodDisplayName(prog),
            ""
        );

        if (saved) {
            EGYMSafeStore.clearCheckpoint();
        }
        return saved;
    }

    function restoreFromCheckpoint(checkpoint as Dictionary?) as Boolean {
        return false;
    }

    function forceEndZirkel() as Void {
        var saveFlow = _persistCompletedFreeflowOnSave;
        _persistCompletedFreeflowOnSave = false;

        var result = finalizeWorkoutFinish(saveFlow);
        if (result == FINISH_RESULT_SAVED) {
            release();
            System.exit();
        }

        isShowingDiscarded = true;
        isShowingSaveFailed = (result == FINISH_RESULT_SAVE_FAILED) || hasWorkoutProgress();
        isShowingSuccess = false;
        WatchUi.requestUpdate();
    }

    function forceEndZirkelAndSaveFlow() as Void {
        _persistCompletedFreeflowOnSave = true;
        forceEndZirkel();
    }

    function dismissSuccess() as Void {
        cleanupAndExit();
    }

    function cleanupAndExit() as Void {
        release();
        System.exit();
    }

    function scrollRecords(delta as Number) as Void {
    }

    function discardSession() as Void {
        var sessionManagerDiscard = getSessionManager();
        if (sessionManagerDiscard != null) {
            sessionManagerDiscard.discard();
        }
        EGYMSafeStore.clearCheckpoint();
        resetSessionState();
        isShowingSuccess = false;
        isShowingDiscarded = true;
        isShowingSaveFailed = false;
        WatchUi.requestUpdate();
    }

    function requestProgramChange(newIndex as Number) as Void {
        if (updateProgram(newIndex)) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        }
    }

    function onWeightPicked(newWeight as Number) as Void {
        currentWeight = newWeight;
        isWaitingForTestConfirm = false;
        WatchUi.requestUpdate();
    }

    function cancelWeightPicker() as Void {
        isWaitingForTestConfirm = false;
        WatchUi.requestUpdate();
    }

    function openProgramMenu() as Void {
        var menu = new WatchUi.Menu2({ :title => EGYMInstinctText.getWorkoutMenuTitle() });
        menu.addItem(new WatchUi.MenuItem(
            EGYMInstinctText.getWorkoutMenuSave(),
            null,
            "finish",
            EGYMBuildProfile.getMenuItemOptions()
        ));

        if (canSaveCompletedFreeflow()) {
            menu.addItem(new WatchUi.MenuItem(
                EGYMInstinctText.getWorkoutMenuSaveFlow(),
                null,
                "save_flow",
                EGYMBuildProfile.getMenuItemOptions()
            ));
        }

        menu.addItem(new WatchUi.MenuItem(
            EGYMInstinctText.getWorkoutMenuDiscard(),
            null,
            "discard",
            EGYMBuildProfile.getMenuItemOptions()
        ));
        WatchUi.pushView(menu, new EGYMMenuDelegate(self), WatchUi.SLIDE_UP);
    }

    function prepareIndividualAddPicker() as Void {
        _individualPickMode = IND_PICK_ADD;
        scheduleIndividualPicker(false);
    }

    function prepareIndividualReplacePicker() as Void {
        _individualPickMode = IND_PICK_REPLACE;
        scheduleIndividualPicker(false);
    }

    private function scheduleIndividualPicker(replaceCurrentView as Boolean) as Void {
        if (_pendingIndividualPickerLaunch && _pendingIndividualPickerReplace == replaceCurrentView) {
            return;
        }

        isWaitingForExercisePick = true;
        _pendingIndividualPickerLaunch = true;
        _pendingIndividualPickerReplace = replaceCurrentView;
        WatchUi.requestUpdate();
    }

    private function launchPendingIndividualPicker() as Void {
        if (!_pendingIndividualPickerLaunch) {
            return;
        }

        var state = captureAtomicState();
        var replaceCurrentView = _pendingIndividualPickerReplace;
        _pendingIndividualPickerLaunch = false;
        _pendingIndividualPickerReplace = false;
        prepareHeapForIndividualPicker();
        sm = null;
        workoutEngine = null;
        var app = Application.getApp() as EGYMApp;
        app.mView = null;
        EGYMLowMemPickerLauncher.openIndividualPicker(state, replaceCurrentView);
    }

    private function prepareHeapForIndividualPicker() as Void {
        _yesBtnRect = null;
        _noBtnRect = null;
        _cleanNameCache = {} as Dictionary<String, String>;
    }

    private function launchPendingProgramMenu() as Void {
        if (!_pendingProgramMenuLaunch) {
            return;
        }

        _pendingProgramMenuLaunch = false;
        openProgramMenu();
    }

    function captureAtomicState() as Dictionary {
        return {
            :sm => sm,
            :engine => workoutEngine,
            :currentPhase => currentPhase,
            :index => index,
            :currentRound => currentRound,
            :currentWeight => currentWeight,
            :qualityValue => qualityValue,
            :activeProg => activeProg,
            :sessionTotalKg => sessionTotalKg,
            :sessionSetCount => sessionSetCount,
            :breakStartTime => breakStartTime,
            :isIndividualMode => isIndividualMode,
            :isWaitingForExercisePick => isWaitingForExercisePick,
            :isWaitingForTestConfirm => isWaitingForTestConfirm,
            :isShowingSuccess => isShowingSuccess,
            :isShowingDiscarded => isShowingDiscarded,
            :isShowingSaveFailed => isShowingSaveFailed,
            :isAskingForNewRound => isAskingForNewRound,
            :zirkel => copyExercises(zirkel),
            :pickMode => _individualPickMode,
            :persistFlow => _persistCompletedFreeflowOnSave,
            :pendingProgChange => _pendingProgChange,
            :learnedFactorGeneration => _learnedFactorGeneration,
            :sessionQualityTotal => _sessionQualityTotal,
            :sessionQualityCount => _sessionQualityCount,
            :sessionWattTotal => _sessionWattTotal,
            :sessionWattCount => _sessionWattCount
        };
    }

    function restoreAtomicState(state as Dictionary?) as Void {
        if (state == null) {
            return;
        }

        sm = state[:sm] != null ? (state[:sm] as EGYMSessionManager) : null;
        workoutEngine = state[:engine] != null ? (state[:engine] as EGYMWorkoutEngine) : null;
        currentPhase = state[:currentPhase] as Number;
        index = state[:index] as Number;
        currentRound = state[:currentRound] as Number;
        currentWeight = state[:currentWeight] as Number;
        qualityValue = state[:qualityValue] as Number;
        activeProg = state[:activeProg] as Number;
        sessionTotalKg = state[:sessionTotalKg] as Number;
        sessionSetCount = state[:sessionSetCount] as Number;
        breakStartTime = state[:breakStartTime] as Number;
        isIndividualMode = state[:isIndividualMode] == true;
        isWaitingForExercisePick = state[:isWaitingForExercisePick] == true;
        isWaitingForTestConfirm = state[:isWaitingForTestConfirm] == true;
        isShowingSuccess = state[:isShowingSuccess] == true;
        isShowingDiscarded = state[:isShowingDiscarded] == true;
        isShowingSaveFailed = state[:isShowingSaveFailed] == true;
        isAskingForNewRound = state[:isAskingForNewRound] == true;
        zirkel = copyExercises(state[:zirkel] as Array<String>?);
        _individualPickMode = state[:pickMode] as Number;
        _persistCompletedFreeflowOnSave = state[:persistFlow] == true;
        _pendingProgChange = state[:pendingProgChange] as Number;
        _learnedFactorGeneration = state[:learnedFactorGeneration] as Number;
        _sessionQualityTotal = state[:sessionQualityTotal] as Number;
        _sessionQualityCount = state[:sessionQualityCount] as Number;
        _sessionWattTotal = state[:sessionWattTotal] as Number;
        _sessionWattCount = state[:sessionWattCount] as Number;
        _cleanNameCache = {} as Dictionary<String, String>;
        _yesBtnRect = null;
        _noBtnRect = null;
        _pendingIndividualPickerLaunch = false;
        _pendingIndividualPickerReplace = false;
        _pendingProgramMenuLaunch = false;
    }

    function scheduleProgramMenuLaunch() as Void {
        _pendingProgramMenuLaunch = true;
        WatchUi.requestUpdate();
    }

    function applyIndividualPickerCancelAtomic() as Void {
        isWaitingForExercisePick = false;
        _individualPickMode = IND_PICK_ADD;
        if (zirkel.size() == 0) {
            discardSession();
            return;
        }
        WatchUi.requestUpdate();
    }

    function applyIndividualUndoFromPickerAtomic() as Void {
        if (zirkel.size() == 0) {
            return;
        }

        var shortened = [] as Array<String>;
        for (var i = 0; i < zirkel.size() - 1; i++) {
            shortened.add(zirkel[i]);
        }
        zirkel = shortened;

        if (zirkel.size() == 0) {
            index = 0;
            isWaitingForExercisePick = false;
            _individualPickMode = IND_PICK_ADD;
            prepareIndividualAddPicker();
            return;
        }

        index = zirkel.size() - 1;
        initExercisePhase();
        isWaitingForExercisePick = false;
        WatchUi.requestUpdate();
    }

    function handleIndividualPickerCancel() as Void {
        isWaitingForExercisePick = false;
        _individualPickMode = IND_PICK_ADD;
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        if (zirkel.size() == 0) {
            discardSession();
        } else {
            WatchUi.requestUpdate();
        }
    }

    function handleIndividualUndoFromPicker() as Void {
        if (zirkel.size() == 0) {
            return;
        }

        var shortened = [] as Array<String>;
        for (var i = 0; i < zirkel.size() - 1; i++) {
            shortened.add(zirkel[i]);
        }
        zirkel = shortened;

        if (zirkel.size() == 0) {
            index = 0;
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            prepareIndividualAddPicker();
            return;
        }

        index = zirkel.size() - 1;
        initExercisePhase();
        isWaitingForExercisePick = false;
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }

    function onIndividualExercisePicked(exName as String) as Void {
        if (_individualPickMode == IND_PICK_REPLACE && index >= 0 && index < zirkel.size()) {
            zirkel[index] = exName;
        } else {
            zirkel.add(exName);
            index = zirkel.size() - 1;
        }

        _individualPickMode = IND_PICK_ADD;
        isWaitingForExercisePick = false;
        initExercisePhase();
        WatchUi.requestUpdate();
    }

    function release() as Void {
        var sessionManagerRelease = getSessionManager();
        if (sessionManagerRelease != null) {
            sessionManagerRelease.cleanup();
        }
        resetSessionState();
        zirkel = [] as Array<String>;
        _cleanNameCache = {} as Dictionary<String, String>;
        isWaitingForExercisePick = false;
        isWaitingForTestConfirm = false;
        _pendingIndividualPickerLaunch = false;
        _pendingIndividualPickerReplace = false;
        _pendingProgramMenuLaunch = false;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var currentY = 15;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (getWorkoutEngine() == null) {
            return;
        }

        if (isShowingDiscarded) {
            drawStatusScreen(
                dc,
                w,
                h,
                currentY,
                isShowingSaveFailed ? EGYMInstinctText.getSaveFailedLabel() : EGYMInstinctText.getDiscardedLabel()
            );
            if (_pendingProgramMenuLaunch) {
                launchPendingProgramMenu();
            }
            if (_pendingIndividualPickerLaunch) {
                launchPendingIndividualPicker();
            }
            return;
        }

        if (isAskingForNewRound) {
            drawRoundDecision(dc, w, h, currentY);
            if (_pendingProgramMenuLaunch) {
                launchPendingProgramMenu();
            }
            if (_pendingIndividualPickerLaunch) {
                launchPendingIndividualPicker();
            }
            return;
        }

        if (zirkel.size() == 0) {
            drawStatusScreen(dc, w, h, currentY, EGYMInstinctText.getNoCircuitLabel());
            if (_pendingProgramMenuLaunch) {
                launchPendingProgramMenu();
            }
            if (_pendingIndividualPickerLaunch) {
                launchPendingIndividualPicker();
            }
            return;
        }

        if (currentPhase == PHASE_BREAK) {
            drawBreakPhase(dc, w, h, currentY);
            if (_pendingProgramMenuLaunch) {
                launchPendingProgramMenu();
            }
            if (_pendingIndividualPickerLaunch) {
                launchPendingIndividualPicker();
            }
            return;
        }

        drawExercisePhase(dc, w, h, currentY);
        if (_pendingProgramMenuLaunch) {
            launchPendingProgramMenu();
        }
        if (_pendingIndividualPickerLaunch) {
            launchPendingIndividualPicker();
        }
    }

    private function drawExercisePhase(dc as Graphics.Dc, w as Number, h as Number, currentY as Number) as Void {
        var prog = getActiveProg();
        var repsSpec = safeStringValue(EGYMConfig.getProgramRepsSpec(prog), "");
        var engine = getWorkoutEngine();
        var repsValue = engine != null ? engine.parseReps(repsSpec) : 0;
        var reps = safeNumberString(repsValue, "0");
        var weightStr = safeWeightString(currentWeight);
        if (hasSubscreen()) {
            drawInstinctExercisePhase(dc, w, h, getCurrentExerciseName(), weightStr, reps);
        } else {
            drawFr55ExercisePhase(dc, w, h, getCurrentExerciseName(), weightStr, reps);
        }
    }

    private function drawBreakPhase(dc as Graphics.Dc, w as Number, h as Number, currentY as Number) as Void {
        if (hasSubscreen()) {
            drawInstinctBreakPhase(dc, w, h, getNextExerciseName());
        } else {
            drawFr55BreakPhase(dc, w, h, getPreviousExerciseName());
        }
    }

    private function drawRoundDecision(dc as Graphics.Dc, w as Number, h as Number, currentY as Number) as Void {
        if (hasSubscreen()) {
            drawInstinctDecisionPhase(dc, w, h);
        } else {
            drawFr55DecisionPhase(dc, w, h);
        }
    }

    private function drawStatusScreen(dc as Graphics.Dc, w as Number, h as Number, currentY as Number, title as String) as Void {
        if (hasSubscreen()) {
            drawInstinctStatusScreen(dc, w, h, title, EGYMInstinctText.getExitFooterLabel());
        } else {
            drawFr55StatusScreen(dc, w, h, title, EGYMInstinctText.getExitFooterLabel());
        }
    }

    private function drawFr55ExercisePhase(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        exerciseName as String,
        weightStr as String,
        reps as String
    ) as Void {
        var centerX = (w / 2).toNumber();
        var nameY = 18;
        var weightY = ((h / 2) - 18).toNumber();
        var minWeightY = nameY + dc.getFontHeight(UI_FONT_SMALL) + 10;
        if (weightY < minWeightY) {
            weightY = minWeightY;
        }
        var repsY = weightY + dc.getFontHeight(UI_FONT_VALUE) + 12;
        var maxRepsY = h - dc.getFontHeight(UI_FONT_BODY) - 10;
        if (repsY > maxRepsY) {
            repsY = maxRepsY;
        }

        drawCenteredLine(dc, centerX, nameY, UI_FONT_SMALL, fitExerciseName(dc, exerciseName, w - 28, UI_FONT_SMALL), w - 28);
        drawCenteredLine(dc, centerX, weightY, UI_FONT_VALUE, safeWeightString(weightStr), w - 32);
        drawCenteredLine(
            dc,
            centerX,
            repsY,
            UI_FONT_BODY,
            buildMetricText(EGYMInstinctText.getRepsLabel(), reps),
            w - 28
        );
    }

    private function drawInstinctExercisePhase(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        exerciseName as String,
        weightStr as String,
        reps as String
    ) as Void {
        var box = getSubscreenBounds();
        var centerX = (w / 2).toNumber();
        var weightX = centerX;
        var weightY = 35;
        if (box != null) {
            weightX -= ((w - box.x.toNumber()) / 3).toNumber();
            weightY = box.y.toNumber() - 14;
        }
        if (weightY < 24) {
            weightY = 24;
        }
        var unitY = weightY + dc.getFontHeight(UI_FONT_VALUE) - 4;
        var nameY = ((h / 2) - (dc.getFontHeight(UI_FONT_BODY) / 2)).toNumber() + 16;
        var statusY = h - 25;

        drawCenteredLine(dc, weightX, weightY, UI_FONT_VALUE, safeWeightString(weightStr), w - 40);
        drawCenteredLine(dc, weightX, unitY, UI_FONT_SMALL, EGYMInstinctText.getKgLabel(), w - 40);
        drawCenteredLine(dc, centerX, nameY, UI_FONT_BODY, fitExerciseName(dc, exerciseName, w - 28, UI_FONT_BODY), w - 28);
        drawCenteredLine(dc, centerX, statusY, UI_FONT_SMALL, EGYMInstinctText.getGoLabel(), w - 28);
        drawSubscreenReps(dc, reps);
    }

    private function drawFr55BreakPhase(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        previousName as String
    ) as Void {
        drawThreeLineStack(
            dc,
            w,
            h,
            fitBreakPreviousLine(dc, previousName, w - 28),
            EGYMInstinctText.getDoneUpperLabel(),
            EGYMInstinctText.getTakeBreakLabel(),
            false,
            8
        );
    }

    private function drawInstinctBreakPhase(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        nextName as String
    ) as Void {
        drawSubscreenPauseIndicator(dc);
        drawThreeLineStackFromTop(
            dc,
            w,
            getInstinctPauseStartY(h),
            fitNextExerciseLine(dc, nextName, w - 28),
            EGYMInstinctText.getDoneStatusLabel(),
            EGYMInstinctText.getTakeBreakLabel(),
            8
        );
    }

    private function drawFr55DecisionPhase(dc as Graphics.Dc, w as Number, h as Number) as Void {
        drawThreeLineStack(
            dc,
            w,
            h,
            EGYMInstinctText.getAnotherRoundLabel(),
            EGYMInstinctText.getDoneUpperLabel(),
            EGYMInstinctText.getRoundFooterLabel(),
            true,
            10
        );
    }

    private function drawInstinctDecisionPhase(dc as Graphics.Dc, w as Number, h as Number) as Void {
        drawSubscreenPauseIndicator(dc);
        drawThreeLineStackFromTop(
            dc,
            w,
            getInstinctPauseStartY(h),
            EGYMInstinctText.getAnotherRoundLabel(),
            EGYMInstinctText.getDoneStatusLabel(),
            EGYMInstinctText.getRoundFooterLabel(),
            8
        );
    }

    private function drawFr55StatusScreen(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        title as String,
        footer as String
    ) as Void {
        var centerX = (w / 2).toNumber();
        var titleY = ((h / 2) - dc.getFontHeight(UI_FONT_BODY)).toNumber();
        var footerY = h - 20;

        drawCenteredLine(dc, centerX, titleY, UI_FONT_BODY, safeStringValue(title, ""), w - 28);
        drawCenteredLine(dc, centerX, footerY, UI_FONT_SMALL, safeStringValue(footer, ""), w - 28);
    }

    private function drawInstinctStatusScreen(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        title as String,
        footer as String
    ) as Void {
        var centerX = (w / 2).toNumber();
        var titleY = ((h / 2) - dc.getFontHeight(UI_FONT_BODY)).toNumber();
        var footerY = h - 20;

        drawCenteredLine(dc, centerX, titleY, UI_FONT_BODY, safeStringValue(title, ""), w - 28);
        drawCenteredLine(dc, centerX, footerY, UI_FONT_SMALL, safeStringValue(footer, ""), w - 28);
    }

    private function drawThreeLineStack(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        line1 as String,
        line2 as String,
        line3 as String,
        footerSmall as Boolean,
        spacing as Number
    ) as Void {
        var font1 = UI_FONT_SMALL;
        var font2 = UI_FONT_BODY;
        var font3 = footerSmall ? UI_FONT_SMALL : UI_FONT_BODY;
        var centerX = (w / 2).toNumber();
        var line2Y = ((h / 2) - dc.getFontHeight(font2)).toNumber();
        var line1Y = line2Y - dc.getFontHeight(font1) - spacing;
        var line3Y = line2Y + dc.getFontHeight(font2) + spacing;

        drawCenteredLine(dc, centerX, line1Y, font1, safeStringValue(line1, ""), w - 28);
        drawCenteredLine(dc, centerX, line2Y, font2, safeStringValue(line2, ""), w - 28);
        drawCenteredLine(dc, centerX, line3Y, font3, safeStringValue(line3, ""), w - 28);
    }

    private function drawCenteredLine(
        dc as Graphics.Dc,
        centerX as Number,
        y as Number,
        font,
        text as String,
        maxWidth as Number
    ) as Void {
        var safeText = fitTextToWidth(dc, safeStringValue(text, ""), font, maxWidth);
        if (safeText.length() == 0) {
            return;
        }

        dc.setColor(Graphics.COLOR_WHITE, -1);
        dc.drawText(centerX, y, font, safeText, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawSubscreenReps(dc as Graphics.Dc, reps as String) as Void {
        var box = getSubscreenBounds();
        if (box == null) {
            return;
        }

        var sx = box.x.toNumber();
        var sy = box.y.toNumber();
        var sw = box.width.toNumber();
        var sh = box.height.toNumber();
        if (sw < 20 || sh < 20) {
            return;
        }

        var labelFont = UI_FONT_SMALL;
        var valueFont = UI_FONT_VALUE;
        var centerX = sx + (sw / 2).toNumber();
        var labelY = sy + 5;
        var valueY = sy + ((sh * 0.48).toNumber()) - 6;
        var minValueY = labelY + dc.getFontHeight(labelFont) - 1;
        if (valueY < minValueY) {
            valueY = minValueY;
        }
        var maxWidth = sw - 6;
        var safeValue = fitTextToWidth(dc, safeNumberString(reps, "0"), valueFont, maxWidth);

        dc.setClip(sx, sy, sw, sh);
        dc.setColor(Graphics.COLOR_WHITE, -1);
        dc.drawText(centerX, labelY, labelFont, EGYMInstinctText.getRepsLabel(), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(centerX, valueY, valueFont, safeValue, Graphics.TEXT_JUSTIFY_CENTER);
        dc.clearClip();
    }

    private function drawSubscreenPauseIndicator(dc as Graphics.Dc) as Void {
        var box = getSubscreenBounds();
        if (box == null) {
            return;
        }

        var sx = box.x.toNumber();
        var sy = box.y.toNumber();
        var sw = box.width.toNumber();
        var sh = box.height.toNumber();
        if (sw < 20 || sh < 20) {
            return;
        }

        var centerX = sx + (sw / 2).toNumber();
        var labelY = sy + ((sh / 2) - (dc.getFontHeight(UI_FONT_SMALL) / 2)).toNumber();

        dc.setClip(sx, sy, sw, sh);
        dc.setColor(Graphics.COLOR_WHITE, -1);
        dc.drawText(
            centerX,
            labelY,
            UI_FONT_SMALL,
            fitTextToWidth(dc, EGYMInstinctText.getBreakLabel(), UI_FONT_SMALL, sw - 6),
            Graphics.TEXT_JUSTIFY_CENTER
        );
        dc.clearClip();
    }

    private function hasSubscreen() as Boolean {
        if (!(WatchUi has :getSubscreen)) {
            return false;
        }

        try {
            var box = getSubscreenBounds();
            return box != null && box.width > 0 && box.height > 0;
        } catch (ignored) {
        }
        return false;
    }

    private function getSubscreenBounds() as Graphics.BoundingBox? {
        if (!(WatchUi has :getSubscreen)) {
            return null;
        }

        try {
            var subscreen = WatchUi.getSubscreen();
            if (subscreen != null) {
                return subscreen as Graphics.BoundingBox;
            }
        } catch (ignored) {
        }

        return null;
    }

    private function getInstinctPauseStartY(h as Number) as Number {
        var box = getSubscreenBounds();
        if (box != null) {
            return box.y.toNumber() + box.height.toNumber() + 6;
        }
        return 86;
    }

    private function getPreviousExerciseName() as String {
        var exName = safeGetExercise(index);
        if (exName == null) {
            return "";
        }
        return EGYMInstinctText.getExerciseName(exName as String);
    }

    private function getCurrentExerciseName() as String {
        var exName = safeGetExercise(index);
        if (exName == null) {
            return "";
        }
        return EGYMInstinctText.getExerciseName(exName as String);
    }

    private function getNextExerciseName() as String {
        if (index + 1 < zirkel.size()) {
            return EGYMInstinctText.getExerciseName(zirkel[index + 1]);
        }
        return "";
    }

    private function finalizeWorkoutFinish(saveFlow as Boolean) as Number {
        var sessionManagerFinish = getSessionManager();
        if (sessionManagerFinish == null || !sessionManagerFinish.hasSession()) {
            if (sessionManagerFinish != null) {
                sessionManagerFinish.discard();
            }
            return FINISH_RESULT_NO_SESSION;
        }

        var prog = getActiveProg();
        var saved = sessionManagerFinish.stopAndSave(
            sessionTotalKg,
            progDisplayName(prog),
            getSessionAverageFitValue(),
            methodDisplayName(prog),
            ""
        );
        if (!saved) {
            return FINISH_RESULT_SAVE_FAILED;
        }

        if (saveFlow) {
            saveCompletedFreeflow();
        }
        EGYMSafeStore.clearCheckpoint();
        updateSessionStats();
        return FINISH_RESULT_SAVED;
    }

    private function hasWorkoutProgress() as Boolean {
        return sessionSetCount > 0 || sessionTotalKg > 0;
    }

    private function resetSessionState() as Void {
        index = 0;
        currentRound = 1;
        currentPhase = PHASE_EXERCISE;
        currentWeight = 0;
        qualityValue = 100;
        sessionTotalKg = 0;
        sessionSetCount = 0;
        breakStartTime = 0;
        isAskingForNewRound = false;
        isShowingSuccess = false;
        isShowingDiscarded = false;
        isShowingSaveFailed = false;
        _sessionQualityTotal = 0;
        _sessionQualityCount = 0;
        _sessionWattTotal = 0;
        _sessionWattCount = 0;
        _persistCompletedFreeflowOnSave = false;
        _pendingProgChange = -1;
        _yesBtnRect = null;
        _noBtnRect = null;
        _pendingProgramMenuLaunch = false;
    }

    private function getCompletedFreeflow() as Array<String> {
        var completed = [] as Array<String>;
        if (!isIndividualMode || zirkel.size() == 0) {
            return completed;
        }

        var lastIndex = index;
        if (currentPhase != PHASE_BREAK && !isAskingForNewRound) {
            lastIndex = index - 1;
        }

        if (lastIndex < 0) {
            return completed;
        }
        if (lastIndex >= zirkel.size()) {
            lastIndex = zirkel.size() - 1;
        }

        for (var i = 0; i <= lastIndex; i++) {
            completed.add(zirkel[i]);
        }
        return completed;
    }

    private function canSaveCompletedFreeflow() as Boolean {
        return isIndividualMode && getCompletedFreeflow().size() >= 3;
    }

    private function saveCompletedFreeflow() as Void {
        var completed = getCompletedFreeflow();
        if (completed.size() < 3) {
            return;
        }
        EGYMSafeStore.setStorageValue(
            EGYMKeys.LAST_SAVED_FREEFLOW,
            limitExercisesForProfile(completed)
        );
    }

    private function cleanExName(exName as String) as String {
        if (_cleanNameCache.hasKey(exName)) {
            return _cleanNameCache[exName] as String;
        }

        var substituted = EGYMSafeStore.applyUmlautSubstitution(exName);
        var chars = substituted.toCharArray();
        var clean = [] as Array<Char>;
        for (var i = 0; i < chars.size(); i++) {
            var c = chars[i];
            if (c != 0x20 && c != 0x09) {
                clean.add(c);
            }
        }

        var cleanName = clean.size() > 0 ? StringUtil.charArrayToString(clean) : "";
        _cleanNameCache[exName] = cleanName;
        return cleanName;
    }

    private function truncateExerciseName(name as String) as String {
        if (name.length() <= MAX_NAME_LEN) {
            return name;
        }
        return name.substring(0, MAX_NAME_LEN) + "..";
    }

    private function fitExerciseName(dc as Graphics.Dc, name as String, maxWidth as Number, font) as String {
        var safeName = safeStringValue(name, "--");
        if (dc.getTextWidthInPixels(safeName, font) <= maxWidth) {
            return safeName;
        }
        return fitTextToWidth(dc, truncateExerciseName(safeName), font, maxWidth);
    }

    private function buildMetricText(label as String, value as String) as String {
        return safeStringValue(label, "--") + " " + safeStringValue(value, "0");
    }

    private function fitBreakPreviousLine(dc as Graphics.Dc, previousName as String, maxWidth as Number) as String {
        var fittedName = fitExerciseName(dc, previousName, maxWidth - 24, UI_FONT_SMALL);
        return fitTextToWidth(
            dc,
            EGYMInstinctText.formatPreviousExerciseLabel(fittedName),
            UI_FONT_SMALL,
            maxWidth
        );
    }

    private function fitNextExerciseLine(dc as Graphics.Dc, nextName as String, maxWidth as Number) as String {
        var fittedName = fitExerciseName(dc, nextName, maxWidth - 24, UI_FONT_SMALL);
        return fitTextToWidth(
            dc,
            EGYMInstinctText.formatNextExerciseLabel(fittedName),
            UI_FONT_SMALL,
            maxWidth
        );
    }

    private function drawThreeLineStackFromTop(
        dc as Graphics.Dc,
        w as Number,
        startY as Number,
        line1 as String,
        line2 as String,
        line3 as String,
        spacing as Number
    ) as Void {
        var centerX = (w / 2).toNumber();
        var line1Y = startY;
        var line2Y = line1Y + dc.getFontHeight(UI_FONT_SMALL) + spacing;
        var line3Y = line2Y + dc.getFontHeight(UI_FONT_BODY) + spacing;

        drawCenteredLine(dc, centerX, line1Y, UI_FONT_SMALL, safeStringValue(line1, ""), w - 28);
        drawCenteredLine(dc, centerX, line2Y, UI_FONT_BODY, safeStringValue(line2, ""), w - 28);
        drawCenteredLine(dc, centerX, line3Y, UI_FONT_BODY, safeStringValue(line3, ""), w - 28);
    }

    private function fitTextToWidth(
        dc as Graphics.Dc,
        text as String,
        font,
        maxWidth as Number
    ) as String {
        var fitted = safeStringValue(text, "");
        if (maxWidth <= 0 || fitted.length() == 0) {
            return fitted;
        }

        if (dc.getTextWidthInPixels(fitted, font) <= maxWidth) {
            return fitted;
        }

        while (fitted.length() > 2 && dc.getTextWidthInPixels(fitted, font) > maxWidth) {
            if (fitted.length() <= 4) {
                fitted = "..";
                break;
            }
            fitted = fitted.substring(0, fitted.length() - 3) + "..";
        }

        return fitted;
    }

    private function safeStringValue(raw, fallback as String) as String {
        if (raw == null) {
            return fallback;
        }

        if (raw instanceof String) {
            var str = raw as String;
            return str.length() > 0 ? str : fallback;
        }

        if (raw has :toString) {
            try {
                var coerced = raw.toString();
                if (coerced != null && coerced.length() > 0) {
                    return coerced;
                }
            } catch (ignored) {
            }
        }

        return fallback;
    }

    private function safeNumberString(raw, fallback as String) as String {
        if (raw == null) {
            return fallback;
        }

        if (raw instanceof Lang.Number) {
            return (raw as Number).toString();
        }

        return safeStringValue(raw, fallback);
    }

    private function safeWeightString(raw) as String {
        if (raw == null) {
            return "0";
        }

        if (raw instanceof String) {
            return safeStringValue(raw, "0");
        }

        if (raw has :format) {
            try {
                return raw.format("%.1f");
            } catch (ignored) {
            }
        }

        return safeNumberString(raw, "0");
    }

    private function fitSafeString(str as String?) as String {
        if (str == null) {
            return EGYMInstinctText.getUnknown();
        }
        return str.length() > 23 ? str.substring(0, 23) : str;
    }

    private function progDisplayName(prog as Dictionary) as String {
        return EGYMConfig.getProgramPrefix(prog) + ": " +
            EGYMInstinctText.getGoalName(EGYMConfig.getProgramGoalKey(prog));
    }

    private function methodDisplayName(prog as Dictionary) as String {
        return EGYMInstinctText.getMethodName(EGYMConfig.getProgramMethodKey(prog));
    }

    function getSessionAverageFitValue() as String {
        if (_sessionWattCount > 0 && _sessionWattCount >= _sessionQualityCount) {
            var avgWatt = ((_sessionWattTotal + (_sessionWattCount / 2)) / _sessionWattCount).toNumber();
            return avgWatt.toString() + " W";
        }

        if (_sessionQualityCount > 0) {
            var avgQuality = ((_sessionQualityTotal + (_sessionQualityCount / 2)) / _sessionQualityCount).toNumber();
            return avgQuality.toString() + "%";
        }

        return "";
    }

    private function updateSessionStats() as Void {
        var sessions = EGYMSafeStore.getStorageNumber(EGYMKeys.STAT_SESSIONS, 0);
        var totalVolume = EGYMSafeStore.getStorageNumber(EGYMKeys.STAT_TOTAL_VOLUME, 0);
        var streak = EGYMSafeStore.getStorageNumber(EGYMKeys.STAT_STREAK, 0);
        var lastDay = EGYMSafeStore.getStorageNumber(EGYMKeys.STAT_LAST_DAY, 0);
        var today = (Time.today().value() / 86400).toNumber();

        if (sessions < 0) { sessions = 0; }
        if (totalVolume < 0) { totalVolume = 0; }
        if (streak < 0) { streak = 0; }
        if (lastDay < 0) { lastDay = 0; }

        if (today == lastDay + 1) {
            streak += 1;
        } else if (today != lastDay) {
            streak = 1;
        }

        EGYMSafeStore.setStorageValue(EGYMKeys.STAT_SESSIONS, sessions + 1);
        EGYMSafeStore.setStorageValue(EGYMKeys.STAT_TOTAL_VOLUME, totalVolume + sessionTotalKg);
        EGYMSafeStore.setStorageValue(EGYMKeys.STAT_STREAK, streak);
        EGYMSafeStore.setStorageValue(EGYMKeys.STAT_LAST_DAY, today);
        EGYMSafeStore.setStorageValue(EGYMKeys.LAST_SESSION_VOLUME, sessionTotalKg);
    }
}
