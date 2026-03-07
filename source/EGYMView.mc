import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.Activity;
import Toybox.Application;
import Toybox.Math;
import Toybox.StringUtil;
import Toybox.Attention;
import Toybox.Time;

// ============================================================
// EGYMView - Main workout view. Manages exercise state,
// phase transitions, input handling, and data persistence.
//
// Drawing -> EGYMViewDrawer
// FIT recording -> EGYMSessionManager
// ============================================================

class EGYMView extends WatchUi.View {

    // App info
    var appVersion as String = "";
    var _learnedFactorGeneration as Number = 0;

    // Value limits
    const MAX_WEIGHT = 500;
    const MAX_WATT = 9999;
    const MIN_QUALITY = 0;
    const MAX_QUALITY = 100;
    // Fallback program (prevents crashes when data is missing)
    const FALLBACK_PROG as Dictionary = {
        :p => "??", :g => "GoalUnknown",
        :m => "REGULAR", :w => "0", :i => 0.0,
    };



    // Phase constants
    const PHASE_EXERCISE = 0;
    const PHASE_ADJUST = 1;
    const PHASE_BREAK = 2;
    const IND_PICK_ADD = 0;
    const IND_PICK_REPLACE = 1;
    const RECORD_TYPE_WATT = "W";
    const RECORD_TYPE_RM = "RM";
    const CHECKPOINT_REASON_PERIODIC = "periodic";
    const CHECKPOINT_REASON_SET_COMPLETE = "set_complete";
    const CHECKPOINT_REASON_APP_STOP = "app_stop";
    const CHECKPOINT_REASON_REHYDRATED = "rehydrated";

    // Managers
    var sm as EGYMSessionManager = new EGYMSessionManager();
    var drawer as EGYMViewDrawer? = null;
    var workoutEngine as EGYMWorkoutEngine = new EGYMWorkoutEngine();

    // Workout state
    var currentPhase as Number = PHASE_EXERCISE;
    var index as Number = 0;
    var currentRound as Number = 1;
    var currentWeight as Number = 0;
    var qualityValue as Number = 100;
    var activeProg as Number = 0;
    var sessionTotalKg as Number = 0;
    var finalCalories as Number = 0;
    var breakStartTime as Number = 0;
    var _previousSessionVolume as Number = 0;

    // Mode flags
    var isIndividualMode as Boolean = false;
    var isWaitingForExercisePick as Boolean = false;
    var isTestModeActive as Boolean = false;
    var isWaitingForTestConfirm as Boolean = false;
    var isFirstStart as Boolean = true;
    var _pendingPowerTest as Boolean = false;
    var _individualPickMode as Number = IND_PICK_ADD;
    var _persistCompletedFreeflowOnSave as Boolean = false;

    // Overlay flags
    var isShowingSuccess as Boolean = false;
    var isShowingDiscarded as Boolean = false;
    var isShowingSaveFailed as Boolean = false;
    var isAskingForNewRound as Boolean = false;

    // Exercise list
    var zirkel as Array<String> = [] as Array<String>;

    // Session records (PR tracking)
    var sessionRecords as Array<Dictionary> = [] as Array<Dictionary>;
    var sessionSetCount as Number = 0;
    var _sessionQualityTotal as Number = 0;
    var _sessionQualityCount as Number = 0;
    var _sessionWattTotal as Number = 0;
    var _sessionWattCount as Number = 0;
    // Scroll state for success overlay
    var _recordScrollIndex as Number = 0;
    var _lastMaxVisible as Number = 1;

    // Timer
    var refreshTimer as Timer.Timer? = null;
    private var _tickCount as Number = 0;
    private var _checkpointTickSeconds as Number = 0;
    private var _setCalcState as Dictionary = {
        :setCount => 0,
        :qualityTotal => 0,
        :qualityCount => 0,
        :wattTotal => 0,
        :wattCount => 0,
        :sessionTotalKg => 0,
        :lastReps => 0,
        :lastWorkload => 0
    };

    // Cached UI strings (loaded once in onShow)
    var _stringsLoaded as Boolean = false;
    var _sNoCircuit as String = "";
    var _sHR as String = "";
    var _sRound as String = "";
    var _sAdjustKg as String = "";
    var _sAdjustKgCompact as String = "";
    var _sNext as String = "";
    var _sRateWatt as String = "";
    var _sRateQuality as String = "";
    var _sAdjustConfirm as String = "";
    var _sAdjustConfirmCompact as String = "";
    var _sBreak as String = "";
    var _sSkipHintShort as String = "";
    var _sBackHintShort as String = "";
    var _sBreakContinueHint as String = "";
    var _sBreakContinueCompact as String = "";
    var _sBreakPickHint as String = "";
    var _sBreakPickCompact as String = "";
    var _sCircuitComplete as String = "";
    var _sNewRecords as String = "";
    var _sNoRecords as String = "";
    var _sBackSave as String = "";
    var _sRoundComplete as String = "";
    var _sAnotherRound as String = "";
    var _sYes as String = "";
    var _sNo as String = "";
    var _sLastExercise as String = "";
    var _sDiscarded as String = "";
    var _sSaveFailed as String = "";
    var _sConfirmProgChange as String = "";
    var _sReps as String = "";
    var _sIndividualAddNext as String = "";
    var _sIndividualReplaceCurrent as String = "";
    var _sIndividualUndoLast as String = "";
    var _sModeActive as String = "";
    var _sSummarySets as String = "";
    var _sSummaryPrs as String = "";
    var _sSummaryAvgQuality as String = "";
    var _sSummaryAvgWatt as String = "";
    var _sSummaryTopPr as String = "";
    var _sSummaryTrend as String = "";
    var _sSummaryTrendVsLast as String = "";
    var _sSummaryTrendSame as String = "";
    var _sUnknown as String = "";
    var _sUnitKg as String = "";
    var _sUnitKgSpaced as String = "";
    var _sUnitW as String = "";
    var _sUnitWSpaced as String = "";
    var _sUnitPercent as String = "";
    var _sUnitSeconds as String = "";
    var _sUnitKcal as String = "";
    var _sInstinctSet as String = "";
    var _sInstinctRest as String = "";
    var _sInstinctDefaultProgress as String = "";
    var _sHeaderNoHr as String = "";
    var _sLogPrefix as String = "";
    var _sLogPropWriteFailed as String = "";
    var _sLogCreateAndStartFailed as String = "";
    var _sLogUpdateSessionStatsFailed as String = "";
    var _sLogCheckpointSaveFailed as String = "";
    var _sLogRestoreCheckpointPropFailed as String = "";
    var _sLogRestoreCheckpointCreateStartFailed as String = "";
    var _sLogProgramChangeAborted as String = "";
    var _sLogStorageWriteFailedPrefix as String = "";
    var _sLogStorageWriteFailedMid as String = "";
    private var _enableViewLogs as Boolean = false;
    private var _shortVibePattern as Array<Attention.VibeProfile> = [
        new Attention.VibeProfile(50, 200)
    ] as Array<Attention.VibeProfile>;
    private var _longVibePattern as Array<Attention.VibeProfile> = [
        new Attention.VibeProfile(100, 500)
    ] as Array<Attention.VibeProfile>;

    // Cached per-phase labels
    var _cachedProgLabel as String = "";
    var _cachedExLabel as String = "";
    var _cachedNextExLabel as String = "";
    var _cachedNextExTruncated as String = "";
    var _cachedExInfo as String = "";
    var _cachedIsExp as Boolean = false;

    // Button rectangles (shared with delegate hit testing)
    var _noBtnRect as Array<Number>? = null;
    var _yesBtnRect as Array<Number>? = null;
    var _cachedBtnW as Number = 0;

    // Name cache and property keys
    var _cleanNameCache as Dictionary<String, String> = {};
    var _knownPropertyKeys as Array<String>? = null;
    var _knownExercisesCache as Array<String>? = null;
    var _pendingProgChange as Number = -1;
    // -- Screen Size 
    var _screenW as Number = 0;
    var _screenH as Number = 0;
    // ========================================================
    // INITIALIZATION
    // ========================================================

    function initialize() {
        View.initialize();
        drawer = new EGYMViewDrawer();

        var app = Application.getApp();
        if (app != null && app instanceof EGYMApp) {
            appVersion = (app as EGYMApp).getAppVersionTag();
        }
        _enableViewLogs = shouldEnableSimulatorLogging();
        refreshLearnedCalibrationGeneration();
    }

    private function shouldEnableSimulatorLogging() as Boolean {
        try {
            var settings = System.getDeviceSettings();
            if (settings != null && settings has :partNumber && settings.partNumber != null) {
                var part = settings.partNumber.toString();
                return part.find("sim") != null || part.find("SIM") != null;
            }
        } catch (ignored) {
        }
        return false;
    }

    function refreshLearnedCalibrationGeneration() as Void {
        _learnedFactorGeneration = EGYMSafeStore.getStorageNumber(EGYMKeys.LEARNED_FACTOR_GEN, 0);
    }

    function setTestMode(status as Boolean) as Void {
        isTestModeActive = status;
    }

    // ========================================================
    // DATA PERSISTENCE
    // ========================================================

    //! Loads saved RM or Watt value for an exercise.
    function getSavedValue(exName as String, getWatt as Boolean) as Number {
        var cleanName = cleanExName(exName);
        var key = (getWatt ? EGYMKeys.WATT_PREFIX : EGYMKeys.RM_PREFIX) + cleanName;
        var val = 0;

        if (isKnownPropertyKey(key)) {
            var prop = EGYMSafeStore.getPropertyValue(key);
            if (prop != null) {
                var propNum = EGYMSafeStore.toNumber(prop, -1);
                if (propNum > 0) {
                    var storageNum = EGYMSafeStore.getStorageNumber(key, 0);
                    var lastSync = EGYMSafeStore.getStorageNumber(key + "_lastSync", 0);

                    if (propNum != lastSync) {
                        safeStoreSet(key, propNum, "sync getSavedValue");
                        safeStoreSet(key + "_lastSync", propNum, "sync getSavedValue lastSync");
                        return propNum;
                    }
                    return storageNum > 0 ? storageNum : propNum;
                }
            }
        }

        var storedNum = EGYMSafeStore.getStorageNumber(key, 0);
        if (storedNum > 0) {
            val = storedNum;
        }

        return val;
    }

    //! Saves an RM or Watt value. Only overwrites if higher (unless force=true).
    function setSavedValue(exName as String, isWatt as Boolean, newValue as Number, force as Boolean) as Void {
        var cleanName = cleanExName(exName);
        var key = (isWatt ? EGYMKeys.WATT_PREFIX : EGYMKeys.RM_PREFIX) + cleanName;

        var oldNum = EGYMSafeStore.getStorageNumber(key, 0);

        if (force || newValue > oldNum) {
            safeStoreSet(key, newValue, "setSavedValue");

            if (!isWatt && newValue != oldNum) {
                saveRMHistory(cleanName, newValue);
            }

            if (isKnownPropertyKey(key)) {
                if (!EGYMSafeStore.setPropertyValue(key, newValue)) {
                    logViewIssueWithSuffix(_sLogPropWriteFailed, key);
                }
                safeStoreSet(key + "_lastSync", newValue, "setSavedValue lastSync");
            }
        }
    }

    // ========================================================
    // EXERCISE HELPERS
    // ========================================================

    function safeGetExercise(idx as Number) as String? {
        if (idx >= 0 && idx < zirkel.size()) {
            return zirkel[idx];
        }
        return null;
    }

    function calcTargetWeight(exName as String) as Number {
        var prog = getActiveProg();
        var rm = getSavedValue(exName, false);
        var factorBasis = getActiveFactorBasis(exName, prog);
        return workoutEngine.computeTargetWeight(rm, factorBasis);
    }

    private function getBaseFactorBasis(prog as Dictionary) as Number {
        return workoutEngine.getBaseFactorBasis(prog);
    }

    private function getLearnedFactorKey(exName as String, prog as Dictionary) as String {
        var baseFactorBasis = getBaseFactorBasis(prog);
        return workoutEngine.buildLearnedFactorKey(
            cleanExName(exName),
            EGYMConfig.getProgramPrefix(prog),
            EGYMConfig.getProgramMethodKey(prog),
            baseFactorBasis,
            _learnedFactorGeneration
        );
    }

    private function getActiveFactorBasis(exName as String, prog as Dictionary) as Number {
        var baseFactorBasis = getBaseFactorBasis(prog);
        var learned = EGYMSafeStore.getStorageNumber(getLearnedFactorKey(exName, prog), 0);
        return workoutEngine.resolveActiveFactorBasis(baseFactorBasis, learned);
    }

    private function maybeLearnWeightFactor(exName as String, prog as Dictionary) as Void {
        if (isTestModeActive) {
            return;
        }

        var rm = getSavedValue(exName, false);
        if (rm <= 0 || currentWeight <= 0) {
            return;
        }

        var suggestedWeight = calcTargetWeight(exName);
        var key = getLearnedFactorKey(exName, prog);
        var storedBasis = EGYMSafeStore.getStorageNumber(key, 0);
        var newBasis = workoutEngine.computeLearnedFactorUpdate(
            rm,
            currentWeight,
            suggestedWeight,
            storedBasis
        );
        if (newBasis == null) {
            return;
        }

        safeStoreSet(key, newBasis as Number, "learnedFactor");
    }

    // ========================================================
    // PHASE INITIALIZATION
    // ========================================================

    function initExercisePhase() as Void {
        currentPhase = PHASE_EXERCISE;
        qualityValue = 100;

        var ex = safeGetExercise(index);
        currentWeight = (ex != null) ? calcTargetWeight(ex) : 0;
        refreshLabels();
    }

    function updateZirkel(newZirkel as Array?) as Void {
        if (newZirkel != null && newZirkel.size() > 0) {
            zirkel = newZirkel as Array<String>;
            index = 0;
            currentRound = 1;
            currentPhase = PHASE_EXERCISE;
            qualityValue = 100;
            initExercisePhase();
            WatchUi.requestUpdate();
        }
    }

    // ========================================================
    // VIEW LIFECYCLE
    // ========================================================

    function onShow() as Void {
        if (!_stringsLoaded) {
            loadCachedStrings();
        }
        refreshLabels();
        _checkpointTickSeconds = 0;

        if (refreshTimer == null) {
            refreshTimer = new Timer.Timer();
        }
        refreshTimer.start(method(:tick), 1000, true);

        if (isShowingSuccess || isShowingDiscarded) {
            return;
        }

        if (_pendingPowerTest) {
            _pendingPowerTest = false;
            startPowerTest();
            return;
        }

        if (isIndividualMode && zirkel.size() == 0 && !isWaitingForExercisePick) {
            prepareIndividualAddPicker();
            return;
        }

        if (isTestModeActive && isFirstStart && !isIndividualMode) {
            isFirstStart = false;
            startPowerTest();
        }
    }

    function onHide() as Void {
        if (refreshTimer != null) {
            refreshTimer.stop();
            refreshTimer = null;
        }
    }

    function tick() as Void {
        _checkpointTickSeconds += 1;
        if (_checkpointTickSeconds >= 30) {
            _checkpointTickSeconds = 0;
            persistSessionCheckpoint(CHECKPOINT_REASON_PERIODIC);
        }

        _tickCount = (_tickCount + 1) % 2;
        if (currentPhase == PHASE_BREAK || isAskingForNewRound ||
            isShowingSuccess || isShowingDiscarded || _tickCount == 0) {
            WatchUi.requestUpdate();
        }
    }

    // ========================================================
    // PROGRAM MANAGEMENT
    // ========================================================

    function updateProgram(newIndex as Number) as Boolean {
        activeProg = newIndex;

        if (sm.isRecording()) {
            if (!EGYMSafeStore.setPropertyValue(EGYMKeys.ACTIVE_PROGRAM, newIndex)) {
                logViewIssueWithSuffix(_sLogPropWriteFailed, EGYMKeys.ACTIVE_PROGRAM);
            }
            initExercisePhase();
            refreshLabels();
            WatchUi.requestUpdate();
            return true;
        }

        resetSessionState();

        if (!EGYMSafeStore.setPropertyValue(EGYMKeys.ACTIVE_PROGRAM, newIndex)) {
            logViewIssueWithSuffix(_sLogPropWriteFailed, EGYMKeys.ACTIVE_PROGRAM);
        }

        sm.cleanup();
        if (!sm.createAndStart()) {
            logViewIssue(_sLogCreateAndStartFailed);
            return false;
        }

        initExercisePhase();
        refreshLabels();
        WatchUi.requestUpdate();
        return true;
    }

    function getActiveProg() as Dictionary {
        var progs = EGYMConfig.getActivePrograms();
        if (progs.size() == 0) {
            return FALLBACK_PROG;
        }
        if (activeProg < 0 || activeProg >= progs.size()) {
            activeProg = 0;
        }
        return progs[activeProg] as Dictionary;
    }

    // ========================================================
    // PHASE TRANSITIONS
    // ========================================================

    function advancePhase() as Boolean {
        onTimerLap();
        return true;
    }

    function onTimerLap() as Void {
        if (isAskingForNewRound || isShowingSuccess) {
            return;
        }

        if (currentPhase == PHASE_EXERCISE) {
            currentPhase = PHASE_ADJUST;
            var prog = getActiveProg();
            var exName = safeGetExercise(index);
            qualityValue = isExplonic(prog) && exName != null ? getSavedValue(exName, true) : 100;
        } else if (currentPhase == PHASE_ADJUST) {
            processEndOfSet();
            currentPhase = PHASE_BREAK;
            breakStartTime = System.getTimer();
            vibrateShort();
        } else if (currentPhase == PHASE_BREAK) {
            if (isIndividualMode) {
                prepareIndividualAddPicker();
            } else if (index >= zirkel.size() - 1) {
                isAskingForNewRound = true;
                isTestModeActive = false;
                vibrateLong();
            } else {
                sm.addLapAndReset();
                index++;
                initExercisePhase();
                vibrateShort();
                if (isTestModeActive) {
                    startPowerTest();
                }
            }
        }
        WatchUi.requestUpdate();
    }

    // ========================================================
    // INPUT HANDLING
    // ========================================================

    function onUpPressed() as Void {
        if (isAskingForNewRound || isShowingSuccess) { return; }
        if (currentPhase == PHASE_EXERCISE) {
            if (currentWeight < MAX_WEIGHT) { currentWeight += 1; }
            WatchUi.requestUpdate();
        } else if (currentPhase == PHASE_ADJUST) {
            changeQuality(5);
        }
    }

    function onDownPressed() as Void {
        if (isAskingForNewRound || isShowingSuccess) { return; }
        if (currentPhase == PHASE_EXERCISE) {
            if (currentWeight > 0) { currentWeight -= 1; }
            WatchUi.requestUpdate();
        } else if (currentPhase == PHASE_ADJUST) {
            changeQuality(-5);
        }
    }

    function changeQuality(delta as Number) as Void {
        qualityValue = workoutEngine.clampQualityAfterDelta(
            qualityValue,
            delta,
            isExplonic(getActiveProg()),
            MIN_QUALITY,
            MAX_QUALITY,
            MAX_WATT
        );
        WatchUi.requestUpdate();
    }

    // ========================================================
    // DECISIONS
    // ========================================================

    function handleDecision(isYes as Boolean) as Void {
        if (isYes) {
            if (zirkel.size() == 0) {
                forceEndZirkel();
                WatchUi.requestUpdate();
                return;
            }
            sm.addLapAndReset();
            index = 0;
            currentRound++;
            isAskingForNewRound = false;
            qualityValue = 100;
            initExercisePhase();
            refreshLabels();
            if (isTestModeActive) {
                startPowerTest();
            }
        } else {
            forceEndZirkel();
        }
        WatchUi.requestUpdate();
    }

    function skipExercise() as Void {
        if (isIndividualMode) {
            prepareIndividualReplacePicker();
            return;
        }
        if (index >= zirkel.size() - 1) {
            isAskingForNewRound = true;
            isTestModeActive = false;
            vibrateLong();
        } else {
            index++;
            initExercisePhase();
            vibrateShort();
            if (isTestModeActive) {
                startPowerTest();
            }
        }
        WatchUi.requestUpdate();
    }

    function goBackOnePhase() as Void {
        if (isAskingForNewRound || isShowingSuccess || isShowingDiscarded) {
            return;
        }

        if (currentPhase == PHASE_ADJUST) {
            currentPhase = PHASE_EXERCISE;
            var ex = safeGetExercise(index);
            if (ex != null) {
                currentWeight = calcTargetWeight(ex);
            }
            refreshLabels();
            vibrateShort();
            WatchUi.requestUpdate();
            return;
        }

        if (currentPhase == PHASE_EXERCISE && isIndividualMode) {
            prepareIndividualReplacePicker();
            return;
        }
    }

    // ========================================================
    // SESSION END
    // ========================================================

    function forceEndZirkel() as Void {
        var saveFlow = _persistCompletedFreeflowOnSave;
        _persistCompletedFreeflowOnSave = false;

        if (sm.hasSession()) {
            var recStr = buildRecordsString();
            var prog = getActiveProg();
            var saved = sm.stopAndSave(
                sessionTotalKg,
                progDisplayName(prog),
                getSessionAverageFitValue(),
                methodDisplayName(prog),
                recStr
            );
            if (saved) {
                EGYMSafeStore.clearCheckpoint();
                if (saveFlow) {
                    saveCompletedFreeflow();
                }
                _previousSessionVolume = EGYMSafeStore.getStorageNumber(EGYMKeys.LAST_SESSION_VOLUME, 0);
                try {
                    updateSessionStats();
                } catch (e) {
                    logViewIssue(_sLogUpdateSessionStatsFailed);
                }
                isShowingSuccess = true;
                isShowingDiscarded = false;
                isShowingSaveFailed = false;
            } else {
                isShowingSuccess = false;
                isShowingDiscarded = true;
                isShowingSaveFailed = true;
            }
        } else {
            sm.discard();
            isShowingSuccess = false;
            isShowingDiscarded = true;
            isShowingSaveFailed = hasWorkoutProgress();
        }
        WatchUi.requestUpdate();
    }

    function forceEndZirkelAndSaveFlow() as Void {
        _persistCompletedFreeflowOnSave = true;
        forceEndZirkel();
    }

    function discardSession() as Void {
        sm.discard();
        EGYMSafeStore.clearCheckpoint();
        sessionTotalKg = 0;
        sessionRecords = [] as Array<Dictionary>;
        sessionSetCount = 0;
        _sessionQualityTotal = 0;
        _sessionQualityCount = 0;
        _sessionWattTotal = 0;
        _sessionWattCount = 0;
        finalCalories = 0;
        currentPhase = PHASE_EXERCISE;
        isAskingForNewRound = false;
        isShowingSuccess = false;
        isShowingDiscarded = true;
        isShowingSaveFailed = false;
        _previousSessionVolume = 0;
        WatchUi.requestUpdate();
    }

    function dismissSuccess() as Void {
        isShowingSuccess = false;
        isShowingDiscarded = false;
        isShowingSaveFailed = false;
        resetSessionState();

        var app = Application.getApp() as EGYMApp;
        var freshMenu = app.createStartMenu();
        WatchUi.switchToView(
            freshMenu,
            new EGYMStartMenuDelegate(),
            WatchUi.SLIDE_DOWN
        );
    }

    function cleanupAndExit() as Void {
        isShowingSuccess = false;
        isShowingDiscarded = false;
        isShowingSaveFailed = false;
        resetSessionState();
        System.exit();
    }

    function cancelWeightPicker() as Void {
        isWaitingForTestConfirm = false;
        WatchUi.requestUpdate();
    }

    // ========================================================
    // FIT DATA PROCESSING
    // ========================================================

    private function syncSetCalcStateFromView() as Void {
        _setCalcState[:setCount] = sessionSetCount;
        _setCalcState[:qualityTotal] = _sessionQualityTotal;
        _setCalcState[:qualityCount] = _sessionQualityCount;
        _setCalcState[:wattTotal] = _sessionWattTotal;
        _setCalcState[:wattCount] = _sessionWattCount;
        _setCalcState[:sessionTotalKg] = sessionTotalKg;
    }

    private function syncViewStateFromSetCalcState() as Void {
        sessionSetCount = _setCalcState[:setCount] as Number;
        _sessionQualityTotal = _setCalcState[:qualityTotal] as Number;
        _sessionQualityCount = _setCalcState[:qualityCount] as Number;
        _sessionWattTotal = _setCalcState[:wattTotal] as Number;
        _sessionWattCount = _setCalcState[:wattCount] as Number;
        sessionTotalKg = _setCalcState[:sessionTotalKg] as Number;
    }

    function processEndOfSet() as Void {
        var prog = getActiveProg();
        var methodKey = EGYMConfig.getProgramMethodKey(prog);
        var isExp = workoutEngine.isExplosiveMethod(methodKey);
        var exName = safeGetExercise(index);
        if (exName == null) { return; }

        syncSetCalcStateFromView();
        workoutEngine.applySetOutcome(
            _setCalcState,
            methodKey,
            qualityValue,
            currentWeight,
            EGYMConfig.getProgramRepsSpec(prog)
        );
        syncViewStateFromSetCalcState();

        maybeLearnWeightFactor(exName, prog);

        if (isExp) {
            var oldWatt = getSavedValue(exName, true);
            if (qualityValue > oldWatt) {
                sessionRecords.add({
                    :n => exName, :d => qualityValue - oldWatt, :t => RECORD_TYPE_WATT,
                });
                setSavedValue(exName, true, qualityValue, false);
                updateRecordsField();
            }
        }

        var totalReps = _setCalcState[:lastReps] as Number;
        var currentWorkload = _setCalcState[:lastWorkload] as Number;

        sm.writeLapData(fitSafeString(exDisplayName(exName)), currentWorkload, totalReps, currentWeight, qualityValue);
        persistSessionCheckpoint(CHECKPOINT_REASON_SET_COMPLETE);
    }

    function updateRecordsField() as Void {
        sm.writeRecordsField(buildRecordsString());
    }

    private function buildRecordsString() as String {
        var maxLen = sm.getRecordsSafeLength();
        if (sessionRecords.size() == 0) { return truncate(_sNoRecords, maxLen); }
        var recStr = "";
        for (var i = 0; i < sessionRecords.size(); i++) {
            var rec = sessionRecords[i] as Dictionary;
            if (!(rec[:n] instanceof String) || !(rec[:t] instanceof String)) {
                continue;
            }

            var unit = (rec[:t] as String).equals(RECORD_TYPE_WATT) ? _sUnitW : _sUnitKg;
            var localizedName = exDisplayName(rec[:n] as String);
            var name = truncate(localizedName, 14);
            var deltaStr = EGYMSafeStore.toNumber(rec[:d], 0).toString();
            var entry = name + "+" + deltaStr + unit;
            var separator = recStr.length() > 0 ? ";" : "";
            var next = recStr + separator + entry;

            if (next.length() > maxLen) {
                if (recStr.length() == 0) {
                    recStr = truncate(entry, maxLen);
                }
                break;
            }
            recStr = next;
        }
        return recStr;
    }

    private function hasWorkoutProgress() as Boolean {
        return sessionSetCount > 0 ||
            sessionTotalKg > 0 ||
            finalCalories > 0 ||
            sessionRecords.size() > 0;
    }

    function persistSessionCheckpoint(reason as String) as Boolean {
        if (!sm.hasSession() && !hasWorkoutProgress()) {
            return true;
        }

        var payload = buildCheckpointPayload(reason);
        var saved = EGYMSafeStore.saveCheckpoint(payload);
        if (!saved) {
            logViewIssueWithSuffix(_sLogCheckpointSaveFailed, reason);
        }
        return saved;
    }

    function emergencyStopAndSave() as Boolean {
        persistSessionCheckpoint(CHECKPOINT_REASON_APP_STOP);

        if (!sm.hasSession() || !hasWorkoutProgress()) {
            return false;
        }

        var prog = getActiveProg();
        var saved = sm.stopAndSave(
            sessionTotalKg,
            progDisplayName(prog),
            getSessionAverageFitValue(),
            methodDisplayName(prog),
            buildRecordsString()
        );

        if (saved) {
            EGYMSafeStore.clearCheckpoint();
        }

        return saved;
    }

    function restoreFromCheckpoint(checkpoint as Dictionary?) as Boolean {
        if (checkpoint == null) {
            return false;
        }

        var rawZirkel = checkpoint["zirkel"];
        if (!(rawZirkel instanceof Array)) {
            return false;
        }

        var restoredZirkel = [] as Array<String>;
        var zArr = rawZirkel as Array;
        for (var z = 0; z < zArr.size(); z++) {
            if (zArr[z] instanceof String) {
                restoredZirkel.add(zArr[z] as String);
            }
        }

        var restoredIndividual = EGYMSafeStore.toBool(checkpoint["isIndividualMode"], false);
        if (!restoredIndividual && restoredZirkel.size() == 0) {
            return false;
        }

        var programs = EGYMConfig.getActivePrograms();
        var restoredProg = EGYMSafeStore.toNumber(checkpoint["activeProg"], 0);
        if (restoredProg < 0 || restoredProg >= programs.size()) {
            restoredProg = 0;
        }

        sm.cleanup();
        resetSessionState();

        activeProg = restoredProg;
        if (!EGYMSafeStore.setPropertyValue(EGYMKeys.ACTIVE_PROGRAM, activeProg)) {
            logViewIssue(_sLogRestoreCheckpointPropFailed);
        }

        if (!sm.createAndStart()) {
            logViewIssue(_sLogRestoreCheckpointCreateStartFailed);
            return false;
        }

        zirkel = restoredZirkel;
        isIndividualMode = restoredIndividual;
        isTestModeActive = EGYMSafeStore.toBool(checkpoint["isTestModeActive"], false);

        currentPhase = EGYMSafeStore.toNumber(checkpoint["phase"], PHASE_EXERCISE);
        if (currentPhase != PHASE_EXERCISE &&
            currentPhase != PHASE_ADJUST &&
            currentPhase != PHASE_BREAK) {
            currentPhase = PHASE_EXERCISE;
        }

        index = EGYMSafeStore.toNumber(checkpoint["index"], 0);
        if (index < 0) {
            index = 0;
        }
        if (zirkel.size() > 0 && index >= zirkel.size()) {
            index = zirkel.size() - 1;
        }

        currentRound = EGYMSafeStore.toNumber(checkpoint["round"], 1);
        if (currentRound < 1) {
            currentRound = 1;
        }

        currentWeight = EGYMSafeStore.toNumber(checkpoint["currentWeight"], 0);
        if (currentWeight < 0) {
            currentWeight = 0;
        }

        qualityValue = EGYMSafeStore.toNumber(checkpoint["qualityValue"], 100);
        if (qualityValue < MIN_QUALITY) {
            qualityValue = MIN_QUALITY;
        }

        sessionSetCount = EGYMSafeStore.toNumber(checkpoint["setCount"], 0);
        if (sessionSetCount < 0) {
            sessionSetCount = 0;
        }

        sessionTotalKg = EGYMSafeStore.toNumber(checkpoint["sessionTotalKg"], 0);
        if (sessionTotalKg < 0) {
            sessionTotalKg = 0;
        }

        finalCalories = EGYMSafeStore.toNumber(checkpoint["finalCalories"], 0);
        if (finalCalories < 0) {
            finalCalories = 0;
        }

        _sessionQualityTotal = EGYMSafeStore.toNumber(checkpoint["qualityTotal"], 0);
        if (_sessionQualityTotal < 0) {
            _sessionQualityTotal = 0;
        }
        _sessionQualityCount = EGYMSafeStore.toNumber(checkpoint["qualityCount"], 0);
        if (_sessionQualityCount < 0) {
            _sessionQualityCount = 0;
        }

        _sessionWattTotal = EGYMSafeStore.toNumber(checkpoint["wattTotal"], 0);
        if (_sessionWattTotal < 0) {
            _sessionWattTotal = 0;
        }
        _sessionWattCount = EGYMSafeStore.toNumber(checkpoint["wattCount"], 0);
        if (_sessionWattCount < 0) {
            _sessionWattCount = 0;
        }

        sessionRecords = restoreSessionRecordsFromCheckpoint(checkpoint["records"]);
        _recordScrollIndex = EGYMSafeStore.toNumber(checkpoint["recordScrollIndex"], 0);
        if (_recordScrollIndex < 0) {
            _recordScrollIndex = 0;
        }
        if (_recordScrollIndex >= sessionRecords.size()) {
            _recordScrollIndex = sessionRecords.size() > 0 ? sessionRecords.size() - 1 : 0;
        }

        var breakElapsedSec = EGYMSafeStore.toNumber(checkpoint["breakElapsedSec"], 0);
        if (breakElapsedSec < 0) {
            breakElapsedSec = 0;
        }
        if (currentPhase == PHASE_BREAK) {
            breakStartTime = System.getTimer() - (breakElapsedSec * 1000);
            if (breakStartTime < 0) {
                breakStartTime = 0;
            }
        } else {
            breakStartTime = 0;
        }

        refreshLabels();
        if (drawer != null) {
            drawer.resetCaches();
        }

        persistSessionCheckpoint(CHECKPOINT_REASON_REHYDRATED);
        WatchUi.requestUpdate();
        return true;
    }

    private function buildCheckpointPayload(reason as String) as Dictionary {
        var payload = {} as Dictionary;
        payload["version"] = 1;
        payload["reason"] = reason;
        payload["timestampMs"] = System.getTimer();
        payload["phase"] = currentPhase;
        payload["index"] = index;
        payload["round"] = currentRound;
        payload["activeProg"] = activeProg;
        payload["isIndividualMode"] = isIndividualMode;
        payload["isTestModeActive"] = isTestModeActive;
        payload["currentWeight"] = currentWeight;
        payload["qualityValue"] = qualityValue;
        payload["setCount"] = sessionSetCount;
        payload["sessionTotalKg"] = sessionTotalKg;
        payload["finalCalories"] = finalCalories;
        payload["qualityTotal"] = _sessionQualityTotal;
        payload["qualityCount"] = _sessionQualityCount;
        payload["wattTotal"] = _sessionWattTotal;
        payload["wattCount"] = _sessionWattCount;
        payload["recordScrollIndex"] = _recordScrollIndex;
        payload["zirkel"] = copyZirkelForCheckpoint();
        payload["records"] = copySessionRecordsForCheckpoint();

        var breakElapsedSec = 0;
        if (currentPhase == PHASE_BREAK && breakStartTime > 0) {
            breakElapsedSec = ((System.getTimer() - breakStartTime) / 1000).toNumber();
            if (breakElapsedSec < 0) {
                breakElapsedSec = 0;
            }
        }
        payload["breakElapsedSec"] = breakElapsedSec;

        return payload;
    }

    private function copyZirkelForCheckpoint() as Array<String> {
        var copy = [] as Array<String>;
        for (var i = 0; i < zirkel.size(); i++) {
            copy.add(zirkel[i]);
        }
        return copy;
    }

    private function copySessionRecordsForCheckpoint() as Array<Dictionary> {
        var copy = [] as Array<Dictionary>;
        for (var i = 0; i < sessionRecords.size(); i++) {
            var rec = sessionRecords[i] as Dictionary;
            if (!(rec[:n] instanceof String) || !(rec[:t] instanceof String)) {
                continue;
            }

            var recordEntry = {} as Dictionary;
            recordEntry["n"] = rec[:n] as String;
            recordEntry["d"] = EGYMSafeStore.toNumber(rec[:d], 0);
            recordEntry["t"] = rec[:t] as String;
            copy.add(recordEntry);
        }
        return copy;
    }

    private function restoreSessionRecordsFromCheckpoint(raw) as Array<Dictionary> {
        var restored = [] as Array<Dictionary>;
        if (!(raw instanceof Array)) {
            return restored;
        }

        var list = raw as Array;
        for (var i = 0; i < list.size(); i++) {
            if (!(list[i] instanceof Dictionary)) {
                continue;
            }

            var rec = list[i] as Dictionary;
            var name = null as String?;
            var typ = null as String?;
            var delta = 0;

            if (rec.hasKey("n") && rec["n"] instanceof String) {
                name = rec["n"] as String;
            } else if (rec.hasKey(:n) && rec[:n] instanceof String) {
                name = rec[:n] as String;
            }

            if (rec.hasKey("t") && rec["t"] instanceof String) {
                typ = rec["t"] as String;
            } else if (rec.hasKey(:t) && rec[:t] instanceof String) {
                typ = rec[:t] as String;
            }

            if (rec.hasKey("d")) {
                delta = EGYMSafeStore.toNumber(rec["d"], 0);
            } else if (rec.hasKey(:d)) {
                delta = EGYMSafeStore.toNumber(rec[:d], 0);
            }

            if (name == null || typ == null) {
                continue;
            }

            restored.add({
                :n => name as String,
                :d => delta,
                :t => typ as String
            });
        }
        return restored;
    }

    // ========================================================
    private function getCompletedFreeflow() as Array<String> {
        var completed = [] as Array<String>;
        if (!isIndividualMode || zirkel.size() == 0) {
            return completed;
        }

        var lastIndex = index - 1;
        if (currentPhase == PHASE_BREAK || isAskingForNewRound || isShowingSuccess) {
            lastIndex = index;
        }
        if (lastIndex >= zirkel.size()) {
            lastIndex = zirkel.size() - 1;
        }
        if (lastIndex < 0) {
            return completed;
        }

        for (var j = 0; j <= lastIndex; j++) {
            completed.add(zirkel[j]);
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
        safeStoreSet(EGYMKeys.LAST_SAVED_FREEFLOW, completed, "saveCompletedFreeflow");
    }

    // REP PARSING
    // ========================================================

    //! Parse specs like "2x8+10" without per-character allocations.
    function parseReps(repsString as String?) as Number {
        return workoutEngine.parseReps(repsString);
    }

    function parseTerm(term as String?) as Number {
        return workoutEngine.parseTerm(term);
    }

    // ========================================================
    // POWER TEST & MENUS
    // ========================================================

    function startPowerTest() as Void {
        isWaitingForTestConfirm = true;
        var currentEx = safeGetExercise(index);
        if (currentEx == null) {
            isWaitingForTestConfirm = false;
            return;
        }
        var currentRM = getSavedValue(currentEx, false);
        var displayName = exDisplayName(currentEx);
        var picker = new EGYMWeightPickerView(displayName, currentRM);
        WatchUi.pushView(picker, new EGYMWeightPickerDelegate(picker, self), WatchUi.SLIDE_UP);
    }

    function onWeightPicked(newWeight as Number) as Void {
        var exName = safeGetExercise(index);
        if (exName == null) { return; }
        var oldRM = getSavedValue(exName, false);
        setSavedValue(exName, false, newWeight, true);

        if (newWeight > oldRM) {
            sessionRecords.add({ :n => exName, :d => newWeight - oldRM, :t => RECORD_TYPE_RM });
            updateRecordsField();
        }
        isWaitingForTestConfirm = false;
        initExercisePhase();
        WatchUi.requestUpdate();
    }

    function openProgramMenu() as Void {
        var menu = new WatchUi.Menu2({ :title => WatchUi.loadResource(Rez.Strings.UIMenuTitle) });
        menu.addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.UIMenuSave), null, "finish", {}));
        if (canSaveCompletedFreeflow()) {
            menu.addItem(new WatchUi.MenuItem(
                WatchUi.loadResource(Rez.Strings.UIMenuSaveFlow),
                WatchUi.loadResource(Rez.Strings.UIMenuSaveFlowSub),
                "save_flow",
                {}
            ));
        }
        menu.addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.UIMenuDiscard), WatchUi.loadResource(Rez.Strings.UIMenuDiscardSub), "discard", {}));
        WatchUi.pushView(menu, new EGYMMenuDelegate(self), WatchUi.SLIDE_UP);
    }

    function prepareIndividualAddPicker() as Void {
        _individualPickMode = IND_PICK_ADD;
        showIndividualPicker();
    }

    function prepareIndividualReplacePicker() as Void {
        _individualPickMode = IND_PICK_REPLACE;
        showIndividualPicker();
    }

    function isIndividualReplacePicker() as Boolean {
        return _individualPickMode == IND_PICK_REPLACE;
    }

    function showIndividualPicker() as Void {
        openIndividualPicker(false);
    }

    function reopenIndividualPicker() as Void {
        openIndividualPicker(true);
    }

    private function openIndividualPicker(replaceCurrentView as Boolean) as Void {
        isWaitingForExercisePick = true;
        var menu = new WatchUi.Menu2({ :title => WatchUi.loadResource(Rez.Strings.UIPickExercise) });
        menu.addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.UIMenuSave), WatchUi.loadResource(Rez.Strings.UIMenuSaveSub), "ind_finish", {}));

        if (_individualPickMode == IND_PICK_REPLACE) {
            menu.addItem(new WatchUi.MenuItem(_sIndividualReplaceCurrent, _sModeActive, "ind_mode_info", {}));

            var undoSub = null as String?;
            var currentEx = safeGetExercise(index);
            if (currentEx != null) {
                undoSub = exDisplayName(currentEx);
            }
            menu.addItem(new WatchUi.MenuItem(_sIndividualUndoLast, undoSub, "ind_undo_last", {}));
        } else {
            menu.addItem(new WatchUi.MenuItem(_sIndividualAddNext, _sModeActive, "ind_mode_info", {}));
        }

        var exercises = EGYMConfig.getAllExercises();
        var count = exercises.size();
        var indices = new [count] as Array<Number>;
        var names = new [count] as Array<String>;
        for (var i = 0; i < count; i++) {
            indices[i] = i;
            names[i] = exDisplayName(exercises[i]);
        }

        for (var i = 1; i < count; i++) {
            var keyName = names[i];
            var keyIdx = indices[i];
            var j = i - 1;
            while (j >= 0 && compareStrings(names[j] as String, keyName) > 0) {
                names[j + 1] = names[j];
                indices[j + 1] = indices[j];
                j--;
            }
            names[j + 1] = keyName;
            indices[j + 1] = keyIdx;
        }

        for (var i = 0; i < count; i++) {
            var origIdx = indices[i] as Number;
            var exKey = exercises[origIdx];
            var displayName = names[i] as String;
            var target = calcTargetWeight(exKey);
            var sub = target > 0 ? target.toString() + _sUnitKgSpaced : null;
            menu.addItem(new WatchUi.MenuItem(displayName, sub, "ind_ex_" + origIdx.toString(), {}));
        }

        if (replaceCurrentView) {
            WatchUi.switchToView(menu, new EGYMIndividualPickerDelegate(self), WatchUi.SLIDE_IMMEDIATE);
        } else {
            WatchUi.pushView(menu, new EGYMIndividualPickerDelegate(self), WatchUi.SLIDE_UP);
        }
    }

    function handleIndividualPickerCancel() as Void {
        if (_individualPickMode == IND_PICK_REPLACE) {
            isWaitingForExercisePick = false;
            _individualPickMode = IND_PICK_ADD;
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            WatchUi.requestUpdate();
            return;
        }

        isWaitingForExercisePick = false;
        if (zirkel.size() > 0) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            forceEndZirkel();
            return;
        }

        discardSession();
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }

    function removeLastIndividualExercise() as Void {
        if (zirkel.size() == 0) {
            index = 0;
            return;
        }

        var shortened = [] as Array<String>;
        for (var i = 0; i < zirkel.size() - 1; i++) {
            shortened.add(zirkel[i]);
        }
        zirkel = shortened;

        if (zirkel.size() == 0) {
            index = 0;
            currentWeight = 0;
            qualityValue = 100;
            refreshLabels();
            WatchUi.requestUpdate();
            return;
        }

        index = zirkel.size() - 1;
        initExercisePhase();
        WatchUi.requestUpdate();
    }

    function handleIndividualUndoFromPicker() as Void {
        if (_individualPickMode != IND_PICK_REPLACE) {
            return;
        }

        removeLastIndividualExercise();
        _individualPickMode = IND_PICK_ADD;

        if (zirkel.size() == 0) {
            reopenIndividualPicker();
            return;
        }

        isWaitingForExercisePick = false;
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }

    function applyIndividualExerciseSelection(exName as String) as Void {
        if (_individualPickMode == IND_PICK_REPLACE &&
            index >= 0 && index < zirkel.size()) {
            zirkel[index] = exName;
        } else {
            zirkel.add(exName);
            index = zirkel.size() - 1;
        }
        _individualPickMode = IND_PICK_ADD;
    }

    function onIndividualExercisePicked(exName as String) as Void {
        isWaitingForExercisePick = false;
        if (currentPhase == PHASE_BREAK) {
            sm.addLapAndReset();
        }
        applyIndividualExerciseSelection(exName);
        initExercisePhase();
        if (isTestModeActive) { _pendingPowerTest = true; }
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        if (_screenW != w || _screenH != h) {
            _screenW = w;
            _screenH = h;
            if (drawer != null) {
                drawer.resetCaches();
            }
        }
        if (drawer != null) { drawer.draw(dc, self); }
    }

    // ========================================================
    // LABEL CACHE & UTILITIES
    // ========================================================

    function refreshLabels() as Void {
        var app = Application.getApp() as EGYMApp;
        var prog = getActiveProg();
        var goal = app.getGoalName(EGYMConfig.getProgramGoalKey(prog));
        var method = app.getMethodName(EGYMConfig.getProgramMethodKey(prog));
        _cachedProgLabel = goal;
        _cachedIsExp = EGYMConfig.isExplosiveProgram(prog);
        _cachedExInfo = parseReps(EGYMConfig.getProgramRepsSpec(prog)).toString() + " " + _sReps + " | " + method.toUpper();

        if (index >= 0 && index < zirkel.size()) {
            _cachedExLabel = app.getExName(zirkel[index]).toUpper();
            if (index < zirkel.size() - 1) {
                _cachedNextExLabel = app.getExName(zirkel[index + 1]);
                _cachedNextExTruncated = truncate(_cachedNextExLabel, 18);
            } else {
                _cachedNextExLabel = "";
                _cachedNextExTruncated = "";
            }
        } else {
            _cachedExLabel = "";
            _cachedNextExLabel = "";
            _cachedNextExTruncated = "";
        }
    }

    function loadCachedStrings() as Void {
        if (_stringsLoaded) { return; }
        _stringsLoaded = true;
        _sNoCircuit = WatchUi.loadResource(Rez.Strings.UINoCircuit);
        _sHR = WatchUi.loadResource(Rez.Strings.UIHeaderHR);
        _sRound = WatchUi.loadResource(Rez.Strings.UIHeaderRound);
        _sAdjustKg = WatchUi.loadResource(Rez.Strings.UIAdjustKg);
        _sAdjustKgCompact = WatchUi.loadResource(Rez.Strings.UIAdjustKgCompact);
        _sNext = WatchUi.loadResource(Rez.Strings.UINext);
        _sRateWatt = WatchUi.loadResource(Rez.Strings.UIRateWatt);
        _sRateQuality = WatchUi.loadResource(Rez.Strings.UIRateQuality);
        _sAdjustConfirm = WatchUi.loadResource(Rez.Strings.UIAdjustConfirm);
        _sAdjustConfirmCompact = WatchUi.loadResource(Rez.Strings.UIAdjustConfirmCompact);
        _sBreak = WatchUi.loadResource(Rez.Strings.UIBreak);
        _sSkipHintShort = WatchUi.loadResource(Rez.Strings.UIHintSkipShort);
        _sBackHintShort = WatchUi.loadResource(Rez.Strings.UIHintBackShort);
        _sBreakContinueHint = WatchUi.loadResource(Rez.Strings.UIHintContinue);
        _sBreakContinueCompact = WatchUi.loadResource(Rez.Strings.UIHintContinueCompact);
        _sBreakPickHint = WatchUi.loadResource(Rez.Strings.UIHintPickNext);
        _sBreakPickCompact = WatchUi.loadResource(Rez.Strings.UIHintPickNextCompact);
        _sCircuitComplete = WatchUi.loadResource(Rez.Strings.UICircuitComplete);
        _sNewRecords = WatchUi.loadResource(Rez.Strings.UINewRecords);
        _sNoRecords = WatchUi.loadResource(Rez.Strings.UINoRecords);
        _sBackSave = WatchUi.loadResource(Rez.Strings.UIBackSave);
        _sRoundComplete = WatchUi.loadResource(Rez.Strings.UIRoundComplete);
        _sAnotherRound = WatchUi.loadResource(Rez.Strings.UIAnotherRound);
        _sYes = WatchUi.loadResource(Rez.Strings.UIYes);
        _sNo = WatchUi.loadResource(Rez.Strings.UINo);
        _sLastExercise = WatchUi.loadResource(Rez.Strings.UILastExercise);
        _sDiscarded = WatchUi.loadResource(Rez.Strings.UIDiscarded);
        _sSaveFailed = WatchUi.loadResource(Rez.Strings.UISaveFailed);
        _sConfirmProgChange = WatchUi.loadResource(Rez.Strings.UIConfirmProgChange);
        _sReps = WatchUi.loadResource(Rez.Strings.UIReps);
        _sIndividualAddNext = WatchUi.loadResource(Rez.Strings.UIIndividualAddNext);
        _sIndividualReplaceCurrent = WatchUi.loadResource(Rez.Strings.UIIndividualReplaceCurrent);
        _sIndividualUndoLast = WatchUi.loadResource(Rez.Strings.UIIndividualUndoLast);
        _sModeActive = WatchUi.loadResource(Rez.Strings.UIActiveMode);
        _sSummarySets = WatchUi.loadResource(Rez.Strings.UISummarySets);
        _sSummaryPrs = WatchUi.loadResource(Rez.Strings.UISummaryPrs);
        _sSummaryAvgQuality = WatchUi.loadResource(Rez.Strings.UISummaryAvgQuality);
        _sSummaryAvgWatt = WatchUi.loadResource(Rez.Strings.UISummaryAvgWatt);
        _sSummaryTopPr = WatchUi.loadResource(Rez.Strings.UISummaryTopPr);
        _sSummaryTrendVsLast = WatchUi.loadResource(Rez.Strings.UISummaryTrendVsLast);
        _sSummaryTrendSame = WatchUi.loadResource(Rez.Strings.UISummaryTrendSame);
        _sSummaryTrend = WatchUi.loadResource(Rez.Strings.UISummaryTrend);
        _sUnknown = WatchUi.loadResource(Rez.Strings.UIUnknown);
        _sUnitKg = WatchUi.loadResource(Rez.Strings.UIUnitKg);
        _sUnitW = WatchUi.loadResource(Rez.Strings.UIUnitW);
        _sUnitPercent = WatchUi.loadResource(Rez.Strings.UIUnitPercent);
        _sUnitSeconds = WatchUi.loadResource(Rez.Strings.UIUnitSeconds);
        _sUnitKcal = WatchUi.loadResource(Rez.Strings.UIUnitKcal);
        _sInstinctSet = WatchUi.loadResource(Rez.Strings.UIInstinctSet);
        _sInstinctRest = WatchUi.loadResource(Rez.Strings.UIInstinctRest);
        _sInstinctDefaultProgress = WatchUi.loadResource(Rez.Strings.UIInstinctDefaultProgress);
        _sHeaderNoHr = WatchUi.loadResource(Rez.Strings.UIHeaderNoHr);
        _sUnitKgSpaced = " " + _sUnitKg;
        _sUnitWSpaced = " " + _sUnitW;

        if (_enableViewLogs) {
            _sLogPrefix = WatchUi.loadResource(Rez.Strings.LogViewPrefix);
            _sLogPropWriteFailed = WatchUi.loadResource(Rez.Strings.LogViewPropWriteFailed);
            _sLogCreateAndStartFailed = WatchUi.loadResource(Rez.Strings.LogViewCreateAndStartFailed);
            _sLogUpdateSessionStatsFailed = WatchUi.loadResource(Rez.Strings.LogViewUpdateStatsFailed);
            _sLogCheckpointSaveFailed = WatchUi.loadResource(Rez.Strings.LogViewCheckpointSaveFailed);
            _sLogRestoreCheckpointPropFailed = WatchUi.loadResource(Rez.Strings.LogViewRestoreCheckpointPropFailed);
            _sLogRestoreCheckpointCreateStartFailed = WatchUi.loadResource(Rez.Strings.LogViewRestoreCheckpointCreateStartFailed);
            _sLogProgramChangeAborted = WatchUi.loadResource(Rez.Strings.LogViewProgramChangeAborted);
            _sLogStorageWriteFailedPrefix = WatchUi.loadResource(Rez.Strings.LogViewStorageWriteFailedPrefix);
            _sLogStorageWriteFailedMid = WatchUi.loadResource(Rez.Strings.LogViewStorageWriteFailedMid);
        }
    }

    function resetSessionState() as Void {
        _recordScrollIndex = 0;
        isIndividualMode = false;
        _pendingPowerTest = false;
        _individualPickMode = IND_PICK_ADD;
        _persistCompletedFreeflowOnSave = false;
        isWaitingForExercisePick = false;
        index = 0;
        currentRound = 1;
        currentPhase = PHASE_EXERCISE;
        qualityValue = 100;
        currentWeight = 0;
        sessionTotalKg = 0;
        sessionSetCount = 0;
        _sessionQualityTotal = 0;
        _sessionQualityCount = 0;
        _sessionWattTotal = 0;
        _sessionWattCount = 0;
        finalCalories = 0;
        _previousSessionVolume = 0;
        isAskingForNewRound = false;
        isShowingSuccess = false;
        isShowingSaveFailed = false;
        isFirstStart = true;
        sessionRecords = [] as Array<Dictionary>;
        breakStartTime = 0;
        _noBtnRect = null;
        _yesBtnRect = null;
        _cachedBtnW = 0;
        isShowingDiscarded = false;
        _pendingProgChange = -1;
        _checkpointTickSeconds = 0;
        _setCalcState[:setCount] = 0;
        _setCalcState[:qualityTotal] = 0;
        _setCalcState[:qualityCount] = 0;
        _setCalcState[:wattTotal] = 0;
        _setCalcState[:wattCount] = 0;
        _setCalcState[:sessionTotalKg] = 0;
        _setCalcState[:lastReps] = 0;
        _setCalcState[:lastWorkload] = 0;
        if (drawer != null) { drawer.resetCaches(); }
    }

    //! Normalize exercise names to a single ASCII key format for storage/properties.
    //! Example: umlaut variants and "ue/oe/ae" forms resolve to the same key.
    function cleanExName(exName as String) as String {
        if (_cleanNameCache.hasKey(exName)) {
            return _cleanNameCache[exName] as String;
        }

        // Apply umlaut substitution, then strip spaces/tabs.
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

    function truncate(str as String, maxLen as Number) as String {
        return str.length() > maxLen ? str.substring(0, maxLen) : str;
    }

    function fitSafeString(str as String?) as String {
        if (str == null) {
            return _sUnknown.length() > 0
                ? _sUnknown
                : WatchUi.loadResource(Rez.Strings.UIUnknown);
        }
        return str.length() > 23 ? str.substring(0, 23) : str;
    }

    function exDisplayName(key as String) as String {
        try {
            return (Application.getApp() as EGYMApp).getExName(key);
        } catch (e) {
            return key;
        }
    }

    function progDisplayName(prog as Dictionary) as String {
        var app = Application.getApp() as EGYMApp;
        return EGYMConfig.getProgramPrefix(prog) + ": " + app.getGoalName(EGYMConfig.getProgramGoalKey(prog));
    }

    function methodDisplayName(prog as Dictionary) as String {
        return (Application.getApp() as EGYMApp).getMethodName(EGYMConfig.getProgramMethodKey(prog));
    }

    function isExplonic(prog as Dictionary) as Boolean {
        return EGYMConfig.isExplosiveProgram(prog);
    }

    function compareStrings(a as String, b as String) as Number {
        return EGYMSafeStore.compareStrings(a, b);
    }

    // ========================================================
    // PROPERTY KEY MANAGEMENT
    // ========================================================

    function initKnownPropertyKeys() as Void {
        if (_knownPropertyKeys != null) { return; }
        _knownPropertyKeys = [] as Array<String>;
        var exercises = getKnownExercises();
        var prefixes = [EGYMKeys.RM_PREFIX, EGYMKeys.WATT_PREFIX];
        for (var i = 0; i < exercises.size(); i++) {
            for (var p = 0; p < prefixes.size(); p++) {
                (_knownPropertyKeys as Array<String>).add(prefixes[p] + exercises[i]);
            }
        }
    }

    function isKnownPropertyKey(key as String) as Boolean {
        initKnownPropertyKeys();
        var keys = _knownPropertyKeys as Array<String>;
        for (var i = 0; i < keys.size(); i++) {
            if (keys[i] == key) {
                return true;
            }
        }
        return false;
    }

    function getKnownExercises() as Array<String> {
        if (_knownExercisesCache != null) { return _knownExercisesCache as Array<String>; }
        var rawNames = EGYMConfig.getAllExercises();
        var cleaned = [] as Array<String>;
        for (var i = 0; i < rawNames.size(); i++) { cleaned.add(cleanExName(rawNames[i])); }
        _knownExercisesCache = cleaned;
        return cleaned;
    }

    // ========================================================
    // STATISTICS
    // ========================================================

    function updateSessionStats() as Void {
        var sessions = EGYMSafeStore.getStorageNumber(EGYMKeys.STAT_SESSIONS, 0);
        if (sessions < 0) { sessions = 0; }
        safeStoreSet(EGYMKeys.STAT_SESSIONS, sessions + 1, "updateSessionStats sessions");

        var totalVolume = EGYMSafeStore.getStorageNumber(EGYMKeys.STAT_TOTAL_VOLUME, 0);
        if (totalVolume < 0) { totalVolume = 0; }
        safeStoreSet(EGYMKeys.STAT_TOTAL_VOLUME, totalVolume + sessionTotalKg, "updateSessionStats totalVolume");

        var today = Time.today().value() / 86400;
        var lastDay = EGYMSafeStore.getStorageNumber(EGYMKeys.STAT_LAST_DAY, 0);
        if (lastDay < 0) { lastDay = 0; }

        var streak = EGYMSafeStore.getStorageNumber(EGYMKeys.STAT_STREAK, 0);
        if (streak < 0) { streak = 0; }

        if (today == lastDay + 1) {
            streak += 1;
        } else if (today != lastDay) {
            streak = 1;
        }

        safeStoreSet(EGYMKeys.STAT_STREAK, streak, "updateSessionStats streak");
        safeStoreSet(EGYMKeys.STAT_LAST_DAY, today, "updateSessionStats lastDay");
        safeStoreSet(EGYMKeys.LAST_SESSION_VOLUME, sessionTotalKg, "updateSessionStats lastSessionVolume");
    }

    function saveRMHistory(cleanName as String, newRM as Number) as Void {
        var key = EGYMKeys.RM_HISTORY_PREFIX + cleanName;
        var today = (Time.today().value() / 86400).toNumber();
        var history = EGYMSafeStore.getStorageValue(key);
        var arr = [] as Array<Number>;

        if (history != null && history instanceof Array) {
            var histArr = history as Array;
            for (var i = 0; i + 1 < histArr.size(); i += 2) {
                arr.add(EGYMSafeStore.toNumber(histArr[i], 0));
                arr.add(EGYMSafeStore.toNumber(histArr[i + 1], 0));
            }
        }

        if (arr.size() >= 2 && arr[arr.size() - 2] == today) {
            arr[arr.size() - 1] = newRM;
        } else {
            arr.add(today);
            arr.add(newRM);
        }

        // Keep the newest 5 day/value points (10 array slots total).
        if (arr.size() > 10) {
            var trimmed = [] as Array<Number>;
            for (var t = arr.size() - 10; t < arr.size(); t++) {
                trimmed.add(arr[t]);
            }
            arr = trimmed;
        }
        safeStoreSet(key, arr, "saveRMHistory");
    }

    function scrollRecords(delta as Number) as Void {
        if (sessionRecords.size() == 0) {
            return;
        }

        _recordScrollIndex += delta;

        if (_recordScrollIndex < 0) {
            _recordScrollIndex = 0;
        }

        var maxVisible = getMaxVisibleRecords();
        var maxScroll = sessionRecords.size() - maxVisible;
        if (maxScroll < 0) {
            maxScroll = 0;
        }

        if (_recordScrollIndex > maxScroll) {
            _recordScrollIndex = maxScroll;
        }

        WatchUi.requestUpdate();
    }

    function vibrateShort() as Void {
        if (Attention has :vibrate) { Attention.vibrate(_shortVibePattern); }
    }

    function vibrateLong() as Void {
        if (Attention has :vibrate) { Attention.vibrate(_longVibePattern); }
    }

    // ========================================================
    // PROGRAM INDEX LOADING
    // ========================================================

    function safeLoadProgIndex() as Number {
        var progIndex = EGYMSafeStore.getPropertyNumber(EGYMKeys.ACTIVE_PROGRAM, 0);

        if (progIndex < 0 || progIndex >= EGYMConfig.getActivePrograms().size()) {
            progIndex = 0;
        }
        return progIndex;
    }

    
    function requestProgramChange(newIndex as Number) as Void {
        if (sm.isRecording()) {
            _pendingProgChange = newIndex;
            WatchUi.switchToView(
                new WatchUi.Confirmation(_sConfirmProgChange),
                new EGYMProgChangeConfirmDelegate(self),
                WatchUi.SLIDE_UP
            );
            return;
        }

        if (updateProgram(newIndex)) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else {
            logViewIssue(_sLogProgramChangeAborted);
            WatchUi.requestUpdate();
        }
    }


    function getMaxVisibleRecords() as Number {
        if (_screenH <= 0) {
            return 1; // Defensive fallback.
        }

        var h = _screenH;
        var startY = (h * 0.76).toNumber();
        var bottomLimit = (h * 0.84).toNumber();
        var recordRowH = (h * 0.05).toNumber();
        if (recordRowH < 16) { recordRowH = 16; }

        var maxVisible = ((bottomLimit - startY) / recordRowH).toNumber();
        if (maxVisible < 1) { maxVisible = 1; }

        return maxVisible;
    }

    function getSessionSummaryPrimaryLine() as String {
        return _sSummarySets + ": " + sessionSetCount.toString() +
            " | " + _sSummaryPrs + ": " + sessionRecords.size().toString();
    }

    function getSessionSummaryAverageLine() as String {
        if (_sessionWattCount > 0 && _sessionWattCount >= _sessionQualityCount) {
            var avgWatt = ((_sessionWattTotal + (_sessionWattCount / 2)) / _sessionWattCount).toNumber();
            return _sSummaryAvgWatt + ": " + avgWatt.toString() + _sUnitWSpaced;
        }

        if (_sessionQualityCount > 0) {
            var avgQuality = ((_sessionQualityTotal + (_sessionQualityCount / 2)) / _sessionQualityCount).toNumber();
            return _sSummaryAvgQuality + ": " + avgQuality.toString() + _sUnitPercent;
        }

        return "";
    }

    function getSessionAverageFitValue() as String {
        if (_sessionWattCount > 0 && _sessionWattCount >= _sessionQualityCount) {
            var avgWatt = ((_sessionWattTotal + (_sessionWattCount / 2)) / _sessionWattCount).toNumber();
            return avgWatt.toString() + _sUnitWSpaced;
        }

        if (_sessionQualityCount > 0) {
            var avgQuality = ((_sessionQualityTotal + (_sessionQualityCount / 2)) / _sessionQualityCount).toNumber();
            return avgQuality.toString() + _sUnitPercent;
        }

        return "";
    }

    function getSessionSummaryTopRecordLine() as String {
        var bestName = null as String?;
        var bestDelta = -1;
        var bestUnit = "";

        for (var i = 0; i < sessionRecords.size(); i++) {
            var rec = sessionRecords[i] as Dictionary;
            if (!(rec[:n] instanceof String) || !(rec[:t] instanceof String)) {
                continue;
            }

            var delta = EGYMSafeStore.toNumber(rec[:d], -1);
            if (delta > bestDelta) {
                bestDelta = delta;
                bestName = rec[:n] as String;
                bestUnit = (rec[:t] as String).equals(RECORD_TYPE_WATT) ? _sUnitWSpaced : _sUnitKgSpaced;
            }
        }

        if (bestName == null || bestDelta < 0) {
            return "";
        }

        return _sSummaryTopPr + ": " + exDisplayName(bestName) +
            " +" + bestDelta.toString() + bestUnit;
    }
    function getSessionSummaryTrendLine() as String {
        if (_previousSessionVolume <= 0 || sessionTotalKg <= 0) {
            return "";
        }

        var diff = sessionTotalKg - _previousSessionVolume;
        if (diff == 0) {
            return _sSummaryTrend + ": " + _sSummaryTrendSame;
        }

        var absDiff = diff < 0 ? -diff : diff;
        var pct = Math.round((absDiff * 100.0) / _previousSessionVolume).toNumber();

        if (pct == 0) {
            pct = 1;
        }

        var signedPct = pct.toString() + _sUnitPercent;
        if (diff > 0) {
            signedPct = "+" + signedPct;
        } else {
            signedPct = "-" + signedPct;
        }

        return _sSummaryTrend + ": " + signedPct + " " + _sSummaryTrendVsLast;
    }

    private function safeStoreSet(key as String, value, context as String) as Boolean {
        var ok = EGYMSafeStore.setStorageValue(key, value);
        if (!ok) {
            logStorageWriteFailed(context, key);
        }
        return ok;
    }

    private function logViewIssueWithSuffix(prefix as String, suffix as String) as Void {
        if (!_enableViewLogs) {
            return;
        }
        ensureViewLogStringsLoaded();
        logViewIssue(prefix + suffix);
    }

    private function logStorageWriteFailed(context as String, key as String) as Void {
        if (!_enableViewLogs) {
            return;
        }
        ensureViewLogStringsLoaded();
        logViewIssue(_sLogStorageWriteFailedPrefix + context + _sLogStorageWriteFailedMid + key);
    }

    private function ensureViewLogStringsLoaded() as Void {
        if (_sLogPrefix.length() > 0) {
            return;
        }
        _sLogPrefix = WatchUi.loadResource(Rez.Strings.LogViewPrefix);
        _sLogPropWriteFailed = WatchUi.loadResource(Rez.Strings.LogViewPropWriteFailed);
        _sLogCreateAndStartFailed = WatchUi.loadResource(Rez.Strings.LogViewCreateAndStartFailed);
        _sLogUpdateSessionStatsFailed = WatchUi.loadResource(Rez.Strings.LogViewUpdateStatsFailed);
        _sLogCheckpointSaveFailed = WatchUi.loadResource(Rez.Strings.LogViewCheckpointSaveFailed);
        _sLogRestoreCheckpointPropFailed = WatchUi.loadResource(Rez.Strings.LogViewRestoreCheckpointPropFailed);
        _sLogRestoreCheckpointCreateStartFailed = WatchUi.loadResource(Rez.Strings.LogViewRestoreCheckpointCreateStartFailed);
        _sLogProgramChangeAborted = WatchUi.loadResource(Rez.Strings.LogViewProgramChangeAborted);
        _sLogStorageWriteFailedPrefix = WatchUi.loadResource(Rez.Strings.LogViewStorageWriteFailedPrefix);
        _sLogStorageWriteFailedMid = WatchUi.loadResource(Rez.Strings.LogViewStorageWriteFailedMid);
    }

    private function logViewIssue(message as String) as Void {
        if (!_enableViewLogs) {
            return;
        }
        ensureViewLogStringsLoaded();
        try {
            System.println(_sLogPrefix + message);
        } catch (ignored) {
            // Logging must never affect rendering or input flow.
        }
    }
}

















