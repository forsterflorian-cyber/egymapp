import Toybox.Application;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.WatchUi;

// ============================================================
// NEW EXERCISE CHECKLIST:
// [] EGYMConfig.mc     -> add to exercise array
// [] strings.xml       -> add ExName string (all locales)
// [] EGYMApp.mc        -> add to getExName() mapping
// [] properties.xml    -> add rm_ and watt_ properties
// [] settings XML      -> add Connect Mobile settings (optional)
// ============================================================

class EGYMApp extends Application.AppBase {

    // Instance state
    // The main workout view, created once in getInitialView().
    // Accessed by delegates, so kept package-visible.
    var mView as EGYMView?;

    // Lazy-loaded lookup tables (releasable)
    private var _resolvedExNames as Dictionary<String, String>?;
    private var _resolvedGoalNames as Dictionary<String, String>?;
    private var _resolvedMethodNames as Dictionary<String, String>?;
    private var _exerciseAliasMap as Dictionary<String, String>?;
    private var _cachedStorageSchema as Number = 0;
    private var _cachedMenuProgramSub as String = "";
    private var _cachedMenuCircleSub as String = "";
    private var _sanityLoggingUnavailable as Boolean = false;
    private var _pendingCalibrationReset as Boolean = false;
    private var _calibrationResetCompleted as Boolean = false;
    private var _recoverableCheckpoint as Dictionary? = null;

    // Storage schema for watch-side persisted data.
    private const CURRENT_STORAGE_SCHEMA_VERSION = 1;
    private const SANITY_LOG_PREFIX = "[EGYM sanity] ";
    private const APP_VERSION_TAG = "v0.6.3";
    // ========================================================
    // LIFECYCLE
    // ========================================================

    function initialize() {
        AppBase.initialize();
    }

    function getAppVersionTag() as String {
        return APP_VERSION_TAG;
    }

    function resetLearnedCalibration() as Void {
        var nextGen = EGYMSafeStore.getStorageNumber(EGYMKeys.LEARNED_FACTOR_GEN, 0) + 1;
        EGYMSafeStore.setStorageValue(EGYMKeys.LEARNED_FACTOR_GEN, nextGen);

        if (mView != null) {
            mView.refreshLearnedCalibrationGeneration();
        }
    }

    function isCalibrationResetPending() as Boolean {
        return _pendingCalibrationReset;
    }

    function beginCalibrationReset() as Void {
        _pendingCalibrationReset = true;
        _calibrationResetCompleted = false;
    }

    function markCalibrationResetDone() as Void {
        _pendingCalibrationReset = false;
        _calibrationResetCompleted = true;
    }

    function clearCalibrationResetState() as Void {
        _pendingCalibrationReset = false;
        _calibrationResetCompleted = false;
    }

    private function runLearnedCalibrationCleanup() as Void {
        var activeGen = EGYMSafeStore.getStorageNumber(EGYMKeys.LEARNED_FACTOR_GEN, 0);
        if (activeGen <= 0) {
            return;
        }

        var cleanupGen = EGYMSafeStore.getStorageNumber(EGYMKeys.LEARNED_FACTOR_CLEANUP_GEN, 0);
        if (cleanupGen < 0) {
            cleanupGen = 0;
        }
        if (cleanupGen >= activeGen) {
            return;
        }

        clearLearnedCalibrationGeneration(cleanupGen);
        EGYMSafeStore.setStorageValue(EGYMKeys.LEARNED_FACTOR_CLEANUP_GEN, cleanupGen + 1);
    }

    private function clearLearnedCalibrationGeneration(targetGen as Number) as Void {
        var cleanedExercises = EGYMConfig.getCleanedExerciseNames();
        var seenSuffixes = {} as Dictionary<String, Boolean>;

        clearLearnedCalibrationForPrograms(cleanedExercises, EGYMConfig.getBasicPrograms(), targetGen, seenSuffixes);
        clearLearnedCalibrationForPrograms(cleanedExercises, EGYMConfig.getAllPrograms(), targetGen, seenSuffixes);
    }

    private function clearLearnedCalibrationForPrograms(
        cleanedExercises as Array<String>,
        programs as Array<Dictionary>,
        targetGen as Number,
        seenSuffixes as Dictionary<String, Boolean>
    ) as Void {
        for (var i = 0; i < programs.size(); i++) {
            var keySuffix = getLearnedCalibrationKeySuffix(programs[i] as Dictionary, targetGen);
            if (keySuffix.length() == 0 || seenSuffixes.hasKey(keySuffix)) {
                continue;
            }

            seenSuffixes[keySuffix] = true;
            for (var j = 0; j < cleanedExercises.size(); j++) {
                var cleanupKey = EGYMKeys.LEARNED_FACTOR_PREFIX + cleanedExercises[j] + keySuffix;
                if (EGYMSafeStore.getStorageValue(cleanupKey) != null) {
                    EGYMSafeStore.deleteStorageValue(cleanupKey);
                }
            }
        }
    }

    private function getLearnedCalibrationKeySuffix(program as Dictionary, targetGen as Number) as String {
        var factorBasis = getProgramFactorBasis(program);
        if (factorBasis <= 0) {
            return "";
        }

        var keySuffix = "_" +
            EGYMConfig.getProgramPrefix(program) + "_" +
            EGYMConfig.getProgramMethodKey(program) + "_" +
            factorBasis.toString();
        if (targetGen > 0) {
            keySuffix += "_g" + targetGen.toString();
        }
        return keySuffix;
    }

    private function getProgramFactorBasis(program as Dictionary) as Number {
        var factor = EGYMConfig.getProgramIntensityFactor(program);
        if (factor <= 0.0) {
            return 0;
        }

        var basis = Math.round(factor * (EGYMConfig.LEARNED_FACTOR_SCALE * 1.0)).toNumber();
        if (basis < EGYMConfig.MIN_LEARNED_FACTOR) {
            return EGYMConfig.MIN_LEARNED_FACTOR;
        }
        if (basis > EGYMConfig.MAX_LEARNED_FACTOR) {
            return EGYMConfig.MAX_LEARNED_FACTOR;
        }
        return basis;
    }

    //! Called when the app starts; syncs settings from Connect Mobile
    function onStart(state as Dictionary?) as Void {
        EGYMSafeStore.resetErrorCounters();
        runStorageMigrations();
        runLearnedCalibrationCleanup();
        syncAndMigrateProperties();
        refreshRecoverableCheckpoint();
        runStartupSanityValidator();
    }

    //! Called when the app stops; frees cached resource strings
    function onStop(state as Dictionary?) as Void {
        if (mView != null) {
            try {
                mView.persistSessionCheckpoint("app_onStop");
            } catch (e) {
                debugSanityLog("onStop checkpoint write failed.");
            }

            try {
                mView.emergencyStopAndSave();
            } catch (e2) {
                debugSanityLog("onStop emergency stop/save failed.");
            }
        }
        releaseResources();
    }

    function refreshRecoverableCheckpoint() as Void {
        _recoverableCheckpoint = EGYMSafeStore.loadCheckpoint();
    }

    function hasRecoverableCheckpoint() as Boolean {
        return _recoverableCheckpoint != null;
    }

    function discardRecoverableCheckpoint() as Void {
        _recoverableCheckpoint = null;
        EGYMSafeStore.clearCheckpoint();
    }

    function tryResumeRecoverableCheckpoint(view as EGYMView) as Boolean {
        if (_recoverableCheckpoint == null) {
            return false;
        }

        var checkpoint = _recoverableCheckpoint as Dictionary;
        var restored = view.restoreFromCheckpoint(checkpoint);
        if (restored) {
            _recoverableCheckpoint = null;
        }
        return restored;
    }

    // ========================================================
    // INPUT NAME RESOLUTION
    // ========================================================

    private function initExerciseNameMap() as Void {
        if (_resolvedExNames != null) {
            return;
        }

        _resolvedExNames = {
            "Brustpresse"       => WatchUi.loadResource(Rez.Strings.ExBrustpresse) as String,
            "Bauchtrainer"      => WatchUi.loadResource(Rez.Strings.ExBauchtrainer) as String,
            "Ruderzug"          => WatchUi.loadResource(Rez.Strings.ExRuderzug) as String,
            "Seitlicher Bauch"  => WatchUi.loadResource(Rez.Strings.ExSeitlicherBauch) as String,
            "SeitlicherBauch"   => WatchUi.loadResource(Rez.Strings.ExSeitlicherBauch) as String,
            "Beinpresse"        => WatchUi.loadResource(Rez.Strings.ExBeinpresse) as String,
            "Latzug"            => WatchUi.loadResource(Rez.Strings.ExLatzug) as String,
            "Butterfly"         => WatchUi.loadResource(Rez.Strings.ExButterfly) as String,
            "Rueckentrainer"    => WatchUi.loadResource(Rez.Strings.ExRueckentrainer) as String,
            "Reverse Butterfly" => WatchUi.loadResource(Rez.Strings.ExReverseButterfly) as String,
            "ReverseButterfly"  => WatchUi.loadResource(Rez.Strings.ExReverseButterfly) as String,
            "Schulterpresse"    => WatchUi.loadResource(Rez.Strings.ExSchulterpresse) as String,
            "Squat"             => WatchUi.loadResource(Rez.Strings.ExSquat) as String,
            "Beinstrecker"      => WatchUi.loadResource(Rez.Strings.ExBeinstrecker) as String,
            "Beinbeuger"        => WatchUi.loadResource(Rez.Strings.ExBeinbeuger) as String,
            "Abduktor"          => WatchUi.loadResource(Rez.Strings.ExAbduktor) as String,
            "Adduktor"          => WatchUi.loadResource(Rez.Strings.ExAdduktor) as String,
            "Hip Thrust"        => WatchUi.loadResource(Rez.Strings.ExHipThrust) as String,
            "HipThrust"         => WatchUi.loadResource(Rez.Strings.ExHipThrust) as String,
            "Bizepscurl"        => WatchUi.loadResource(Rez.Strings.ExBizepscurl) as String,
            "Trizepspresse"     => WatchUi.loadResource(Rez.Strings.ExTrizepspresse) as String,
            "Glutaeus"          => WatchUi.loadResource(Rez.Strings.ExGlutaeus) as String,
            "Wadentrainer"      => WatchUi.loadResource(Rez.Strings.ExWadentrainer) as String
        };
    }

    private function initGoalNameMap() as Void {
        if (_resolvedGoalNames != null) {
            return;
        }

        _resolvedGoalNames = {
            "GoalEndurance"      => WatchUi.loadResource(Rez.Strings.GoalEndurance),
            "GoalMuscleBuild"    => WatchUi.loadResource(Rez.Strings.GoalMuscleBuild),
            "GoalRobustness"     => WatchUi.loadResource(Rez.Strings.GoalRobustness),
            "GoalMaxStrength"    => WatchUi.loadResource(Rez.Strings.GoalMaxStrength),
            "GoalToning"         => WatchUi.loadResource(Rez.Strings.GoalToning),
            "GoalFatBurn"        => WatchUi.loadResource(Rez.Strings.GoalFatBurn),
            "GoalFatBurning"     => WatchUi.loadResource(Rez.Strings.GoalFatBurn),
            "GoalPower"          => WatchUi.loadResource(Rez.Strings.GoalPower),
            "GoalActivation"     => WatchUi.loadResource(Rez.Strings.GoalActivation),
            "GoalMetabolism"     => WatchUi.loadResource(Rez.Strings.GoalMetabolism),
            "GoalMetabolicFit"   => WatchUi.loadResource(Rez.Strings.GoalMetabolism),
            "GoalMobilization"   => WatchUi.loadResource(Rez.Strings.GoalMobilization),
            "GoalStrength"       => WatchUi.loadResource(Rez.Strings.GoalStrength),
            "GoalFunction"       => WatchUi.loadResource(Rez.Strings.GoalFunction),
            "GoalGettingStarted" => WatchUi.loadResource(Rez.Strings.GoalGettingStarted),
            "GoalProgress"       => WatchUi.loadResource(Rez.Strings.GoalProgress),
            "GoalIntensify"      => WatchUi.loadResource(Rez.Strings.GoalIntensify),
            "GoalSpeedStrength"  => WatchUi.loadResource(Rez.Strings.GoalSpeedStrength),
            "GoalMaximize"       => WatchUi.loadResource(Rez.Strings.GoalMaximize)
        };
    }

    private function initMethodNameMap() as Void {
        if (_resolvedMethodNames != null) {
            return;
        }

        _resolvedMethodNames = {
            "REGULAR"    => WatchUi.loadResource(Rez.Strings.MethodRegular),
            "ADAPTIVE"   => WatchUi.loadResource(Rez.Strings.MethodAdaptive),
            "NEGATIVE"   => WatchUi.loadResource(Rez.Strings.MethodNegative),
            "EXPLOSIVE"  => WatchUi.loadResource(Rez.Strings.MethodExplonic),
            "EXPLONIC"   => WatchUi.loadResource(Rez.Strings.MethodExplonic),
            "ISOKINETIC" => WatchUi.loadResource(Rez.Strings.MethodIsokinetic)
        };
    }

    // ========================================================
    // HELPER ACCESSORS
    // ========================================================

    function getExName(key as String) as String {
        initExerciseNameMap();
        if (_resolvedExNames != null && _resolvedExNames.hasKey(key)) {
            return _resolvedExNames[key] as String;
        }
        return key;
    }

    function getGoalName(key as String) as String {
        initGoalNameMap();
        if (_resolvedGoalNames != null && _resolvedGoalNames.hasKey(key)) {
            return _resolvedGoalNames[key] as String;
        }
        return key;
    }

    function getMethodName(key as String) as String {
        initMethodNameMap();
        if (_resolvedMethodNames != null && _resolvedMethodNames.hasKey(key)) {
            return _resolvedMethodNames[key] as String;
        }
        return key;
    }

    function resolveExerciseName(input as String?) as String? {
        if (input == null) {
            return null;
        }
        var key = EGYMSafeStore.applyUmlautSubstitution(EGYMSafeStore.trimWhitespace(input).toLower());
        if (key.length() == 0) {
            return null;
        }
        return resolveExerciseAliasKey(key);
    }

    private function initExerciseAliasMap() as Void {
        if (_exerciseAliasMap != null) {
            return;
        }
        _exerciseAliasMap = {
            "chest press"       => "Brustpresse",
            "brustpresse"       => "Brustpresse",
            "ab trainer"        => "Bauchtrainer",
            "bauchtrainer"      => "Bauchtrainer",
            "seated row"        => "Ruderzug",
            "ruderzug"          => "Ruderzug",
            "rudern"            => "Ruderzug",
            "oblique"           => "Seitlicher Bauch",
            "seitlicher bauch"  => "Seitlicher Bauch",
            "leg press"         => "Beinpresse",
            "beinpresse"        => "Beinpresse",
            "lat pulldown"      => "Latzug",
            "latzug"            => "Latzug",
            "lat ziehen"        => "Latzug",
            "butterfly"         => "Butterfly",
            "back extension"    => "Rueckentrainer",
            "rueckentrainer"    => "Rueckentrainer",
            "reverse fly"       => "Reverse Butterfly",
            "reverse butterfly" => "Reverse Butterfly",
            "shoulder press"    => "Schulterpresse",
            "schulterpresse"    => "Schulterpresse",
            "squat"             => "Squat",
            "leg extension"     => "Beinstrecker",
            "beinstrecker"      => "Beinstrecker",
            "leg curl"          => "Beinbeuger",
            "beinbeuger"        => "Beinbeuger",
            "abductor"          => "Abduktor",
            "abduktor"          => "Abduktor",
            "adductor"          => "Adduktor",
            "adduktor"          => "Adduktor",
            "hip thrust"        => "Hip Thrust",
            "bicep curl"        => "Bizepscurl",
            "bizepscurl"        => "Bizepscurl",
            "tricep press"      => "Trizepspresse",
            "trizepspresse"     => "Trizepspresse",
            "glute"             => "Glutaeus",
            "glutaeus"          => "Glutaeus",
            "calf raise"        => "Wadentrainer",
            "calves"            => "Wadentrainer",
            "wadentrainer"      => "Wadentrainer",
            "waden"             => "Wadentrainer"
        } as Dictionary<String, String>;
    }

    private function resolveExerciseAliasKey(key as String) as String? {
        initExerciseAliasMap();
        if (_exerciseAliasMap != null && _exerciseAliasMap.hasKey(key)) {
            return _exerciseAliasMap[key] as String;
        }
        return null;
    }

    // ========================================================
    // VIEW SETUP
    // ========================================================

    function ensureMainView() as EGYMView {
        if (mView == null) {
            mView = new EGYMView();
        }
        return mView as EGYMView;
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var startMenu = createStartMenu();
        return [startMenu, new EGYMStartMenuDelegate()];
    }

    // ========================================================
    // SETTINGS SYNC 
    // ========================================================

    function onSettingsChanged() as Void {
        var view = mView;
        if (view == null) {
            return;
        }

        var zirkelString = EGYMSafeStore.getPropertyString(EGYMKeys.ZIRKEL_ORDER, "");
        if (zirkelString.length() > 0) {
            var parsed = parseZirkelString(zirkelString);
            if (parsed.size() > 0) {
                EGYMSafeStore.setStorageValue(EGYMKeys.CUSTOM_ZIRKEL, parsed);
            }
        }

        syncAndMigrateProperties();

        if (view.sm.isRecording()) {
            // Refresh weight suggestions mid-workout with the new settings.
            view.initExercisePhase();
        }
        // If not recording, data is already synced above. Don't navigate
        // away - the user may be browsing Stats or Diagnostics.
    }

    // ========================================================
    // STRING PARSING
    // ========================================================

    //! Parses comma-separated names using String.find() for low overhead.
    function parseZirkelString(str as String) as Array<String> {
        var arr = [] as Array<String>;
        var remainingStr = str;
        var commaIndex = remainingStr.find(",");

        while (commaIndex != null) {
            var item = EGYMSafeStore.trimWhitespace(remainingStr.substring(0, commaIndex));
            if (item.length() > 0) {
                var resolved = resolveExerciseName(item);
                arr.add(resolved != null ? resolved : item);
            }
            
            // Move past the comma
            remainingStr = remainingStr.substring(commaIndex + 1, remainingStr.length());
            commaIndex = remainingStr.find(",");
        }

        // Handle the final token
        var finalItem = EGYMSafeStore.trimWhitespace(remainingStr);
        if (finalItem.length() > 0) {
            var resolved = resolveExerciseName(finalItem);
            arr.add(resolved != null ? resolved : finalItem);
        }

        return arr;
    }

    // ========================================================
    // UTILITIES
    // ========================================================

    function getDefaultZirkel() as Array<String> {
        return EGYMConfig.getZirkelKraft();
    }

    function copyArray(src as Array?) as Array<String> {
        if (src == null) {
            return [] as Array<String>;
        }
        var dst = [] as Array<String>;
        for (var i = 0; i < src.size(); i++) {
            var item = src[i];
            if (item instanceof String) {
                dst.add(item as String);
            }
        }
        return dst;
    }

    // ========================================================
    // STORAGE MIGRATIONS
    // ========================================================

    private function runStorageMigrations() as Void {
        var schema = EGYMSafeStore.getStorageNumber(EGYMKeys.STORAGE_SCHEMA_VERSION, 0);

        // Apply migrations sequentially so upgrades remain idempotent.
        if (schema < 1) {
            migrateStorageToV1();
            EGYMSafeStore.setStorageValue(EGYMKeys.STORAGE_SCHEMA_VERSION, 1);
            schema = 1;
        }

        if (schema > CURRENT_STORAGE_SCHEMA_VERSION) {
            // Forward-compat fallback: keep running with current defaults.
            _cachedStorageSchema = schema;
            return;
        }
        _cachedStorageSchema = schema;
    }

    function getCachedStorageSchema() as Number {
        return _cachedStorageSchema;
    }

    function getCachedMenuProgramSub() as String {
        return _cachedMenuProgramSub;
    }

    function getCachedMenuCircleSub() as String {
        return _cachedMenuCircleSub;
    }

    function refreshRuntimeSnapshots() as Void {
        var schema = EGYMSafeStore.getStorageNumber(
            EGYMKeys.STORAGE_SCHEMA_VERSION,
            _cachedStorageSchema
        );
        if (schema > 0) {
            _cachedStorageSchema = schema;
        }

        var programs = EGYMConfig.getActivePrograms();
        var currentIndex = EGYMSafeStore.getPropertyNumber(EGYMKeys.ACTIVE_PROGRAM, 0);
        if (currentIndex < 0 || currentIndex >= programs.size()) {
            currentIndex = 0;
        }

        _cachedMenuProgramSub = WatchUi.loadResource(Rez.Strings.UIProgramEmpty) as String;
        if (programs.size() > 0) {
            _cachedMenuProgramSub = EGYMConfig.getProgramDisplayString(programs[currentIndex]);
        }

        _cachedMenuCircleSub = EGYMConfig.getCircleName();
    }

    private function migrateStorageToV1() as Void {
        // Coerce potentially stale/corrupt settings into safe defaults.
        var isPlus = EGYMSafeStore.getPropertyBool(EGYMKeys.IS_EGYM_PLUS, true);
        var isTest = EGYMSafeStore.getPropertyBool(EGYMKeys.IS_TEST_MODE, false);
        var activeCircle = EGYMSafeStore.getPropertyNumber(EGYMKeys.ACTIVE_CIRCLE, 0);
        var activeProgram = EGYMSafeStore.getPropertyNumber(EGYMKeys.ACTIVE_PROGRAM, 0);

        if (activeCircle < 0 || activeCircle > 3) {
            activeCircle = 0;
        }

        var programs = EGYMConfig.getActivePrograms();
        if (activeProgram < 0 || activeProgram >= programs.size()) {
            activeProgram = 0;
        }

        EGYMSafeStore.setPropertyValue(EGYMKeys.IS_EGYM_PLUS, isPlus);
        EGYMSafeStore.setPropertyValue(EGYMKeys.IS_TEST_MODE, isTest);
        EGYMSafeStore.setPropertyValue(EGYMKeys.ACTIVE_CIRCLE, activeCircle);
        EGYMSafeStore.setPropertyValue(EGYMKeys.ACTIVE_PROGRAM, activeProgram);

        if (EGYMSafeStore.getStorageValue(EGYMKeys.LAST_SYNC_IS_EGYM_PLUS) == null) {
            EGYMSafeStore.setStorageValue(EGYMKeys.LAST_SYNC_IS_EGYM_PLUS, isPlus);
        }

        var custom = EGYMSafeStore.getStorageStringArray(EGYMKeys.CUSTOM_ZIRKEL);
        if (custom != null) {
            EGYMSafeStore.setStorageValue(EGYMKeys.CUSTOM_ZIRKEL, custom);
        }

        var sessions = EGYMSafeStore.getStorageNumber(EGYMKeys.STAT_SESSIONS, 0);
        var volume = EGYMSafeStore.getStorageNumber(EGYMKeys.STAT_TOTAL_VOLUME, 0);
        var streak = EGYMSafeStore.getStorageNumber(EGYMKeys.STAT_STREAK, 0);
        var lastDay = EGYMSafeStore.getStorageNumber(EGYMKeys.STAT_LAST_DAY, 0);

        EGYMSafeStore.setStorageValue(EGYMKeys.STAT_SESSIONS, sessions < 0 ? 0 : sessions);
        EGYMSafeStore.setStorageValue(EGYMKeys.STAT_TOTAL_VOLUME, volume < 0 ? 0 : volume);
        EGYMSafeStore.setStorageValue(EGYMKeys.STAT_STREAK, streak < 0 ? 0 : streak);
        EGYMSafeStore.setStorageValue(EGYMKeys.STAT_LAST_DAY, lastDay < 0 ? 0 : lastDay);
    }

    function syncAndMigrateProperties() as Void {
        var curBool = EGYMSafeStore.getPropertyBool(EGYMKeys.IS_EGYM_PLUS, true);
        var lastPlusRaw = EGYMSafeStore.getStorageValue(EGYMKeys.LAST_SYNC_IS_EGYM_PLUS);
        var lastBool = (lastPlusRaw instanceof Boolean) ? (lastPlusRaw as Boolean) : curBool;

        if (lastPlusRaw != null && curBool != lastBool) {
            if (!curBool) {
                EGYMSafeStore.setPropertyValue(EGYMKeys.ACTIVE_PROGRAM, 0);
            }
        }
        EGYMSafeStore.setStorageValue(EGYMKeys.LAST_SYNC_IS_EGYM_PLUS, curBool);

        var exercises = (mView != null) ? mView.getKnownExercises() : EGYMConfig.getCleanedExerciseNames();
        
        // Defensive cast: ignore unexpected non-array values.
        var exercisesArray = [] as Array<String>;
        if (exercises instanceof Array) {
            exercisesArray = exercises as Array<String>;
        }

        var prefixes = [EGYMKeys.RM_PREFIX, EGYMKeys.WATT_PREFIX];
        for (var i = 0; i < exercisesArray.size(); i++) {
            for (var p = 0; p < prefixes.size(); p++) {
                var key = prefixes[p] + exercisesArray[i];
                var propVal = EGYMSafeStore.getPropertyValue(key);
                if (propVal != null) {
                    var propNum = EGYMSafeStore.toNumber(propVal, -1);
                    if (propNum > 0) {
                        var lastSync = EGYMSafeStore.getStorageNumber(key + "_lastSync", 0);
                        if (propNum != lastSync) {
                            EGYMSafeStore.setStorageValue(key, propNum);
                            EGYMSafeStore.setStorageValue(key + "_lastSync", propNum);
                        }
                    }
                }
            }
        }
    }

    // ========================================================
    // DEBUG SANITY VALIDATION
    // ========================================================

    private function runStartupSanityValidator() as Void {
        var issues = [] as Array<String>;
        var warnings = [] as Array<String>;

        var allExercises = EGYMConfig.getAllExercises();
        var cleanedExercises = EGYMConfig.getCleanedExerciseNames();

        if (allExercises.size() != cleanedExercises.size()) {
            issues.add("Exercise count mismatch raw=" + allExercises.size().toString() + " cleaned=" + cleanedExercises.size().toString());
        }

        initExerciseNameMap();
        var mappedNames = _resolvedExNames;
        var seenRaw = {} as Dictionary<String, Boolean>;
        var seenClean = {} as Dictionary<String, Boolean>;

        for (var i = 0; i < allExercises.size(); i++) {
            var raw = allExercises[i];

            if (seenRaw.hasKey(raw)) {
                warnings.add("Duplicate raw exercise: " + raw);
            } else {
                seenRaw.put(raw, true);
            }

            if (mappedNames == null || !(mappedNames as Dictionary<String, String>).hasKey(raw)) {
                issues.add("Missing getExName mapping: " + raw);
            }

            if (i >= cleanedExercises.size()) {
                continue;
            }

            var clean = cleanedExercises[i];
            if (seenClean.hasKey(clean)) {
                warnings.add("Duplicate cleaned key: " + clean);
            } else {
                seenClean.put(clean, true);
            }

            var rmKey = EGYMKeys.RM_PREFIX + clean;
            var wattKey = EGYMKeys.WATT_PREFIX + clean;
            if (!hasPropertyKey(rmKey)) {
                issues.add("Missing property key: " + rmKey);
            }
            if (!hasPropertyKey(wattKey)) {
                issues.add("Missing property key: " + wattKey);
            }
        }

        var counters = EGYMSafeStore.getErrorCounters();
        var propReads = counters["propertyReadErrors"] as Number;
        var propWrites = counters["propertyWriteErrors"] as Number;
        var storageReads = counters["storageReadErrors"] as Number;
        var storageWrites = counters["storageWriteErrors"] as Number;

        if (propReads > 0 || propWrites > 0 || storageReads > 0 || storageWrites > 0) {
            warnings.add(
                "SafeStore exceptions: propRead=" + propReads.toString() +
                " propWrite=" + propWrites.toString() +
                " storageRead=" + storageReads.toString() +
                " storageWrite=" + storageWrites.toString()
            );
        }

        if (issues.size() == 0 && warnings.size() == 0) { return; }

        debugSanityLog("Startup checks found " + issues.size().toString() + " issue(s), " + warnings.size().toString() + " warning(s).");
        for (var j = 0; j < issues.size(); j++) {
            debugSanityLog("ERROR: " + issues[j]);
        }
        for (var k = 0; k < warnings.size(); k++) {
            debugSanityLog("WARN: " + warnings[k]);
        }
    }

    private function hasPropertyKey(key as String) as Boolean {
        try {
            Application.Properties.getValue(key);
            return true;
        } catch (e) {
            // Broad catch intentional: Connect IQ throws different exception
            // types for missing property keys across firmware versions.
            // This function is only called from the startup sanity validator.
            return false;
        }
    }

    private function debugSanityLog(message as String) as Void {
        if (_sanityLoggingUnavailable) {
            return;
        }

        try {
            System.println(SANITY_LOG_PREFIX + message);
        } catch (e) {
            _sanityLoggingUnavailable = true;
        }
    }

    // ========================================================
    // START MENU
    // ========================================================

    function createStartMenu() as WatchUi.Menu2 {
        refreshRecoverableCheckpoint();
        var isPlus = EGYMSafeStore.getPropertyBool(EGYMKeys.IS_EGYM_PLUS, true);

        var menuTitle = isPlus
            ? WatchUi.loadResource(Rez.Strings.UIStartTitlePlus) as String
            : WatchUi.loadResource(Rez.Strings.UIStartTitleBasis) as String;
        var versionText = APP_VERSION_TAG;
        if (versionText.length() > 0) {
            menuTitle += " " + formatMenuVersionTag(versionText);
        }
        var startMenu = new WatchUi.Menu2({ :title => menuTitle });

        if (EGYMSafeStore.getStorageBool(EGYMKeys.LAST_SETUP_EXISTS, false)) {
            startMenu.addItem(
                new WatchUi.MenuItem(
                    WatchUi.loadResource(Rez.Strings.UIRepeatLastSetup) as String,
                    getLastSetupMenuSubLabel(),
                    "repeat_last_setup",
                    {}
                )
            );
        }

        var savedFreeflow = EGYMSafeStore.getStorageStringArray(EGYMKeys.LAST_SAVED_FREEFLOW);
        if (savedFreeflow != null && savedFreeflow.size() > 0) {
            startMenu.addItem(
                new WatchUi.MenuItem(
                    WatchUi.loadResource(Rez.Strings.UIRepeatLastFreeflow) as String,
                    WatchUi.loadResource(Rez.Strings.UIRepeatLastFreeflowSub) as String,
                    "repeat_last_freeflow",
                    {}
                )
            );
        }

        refreshRuntimeSnapshots();
        var programSub = _cachedMenuProgramSub;

        startMenu.addItem(
            new WatchUi.MenuItem(
                WatchUi.loadResource(Rez.Strings.UIMenuProgram) as String,
                programSub,
                "select_program",
                {}
            )
        );

        var circleSub = _cachedMenuCircleSub;
        startMenu.addItem(
            new WatchUi.MenuItem(
                WatchUi.loadResource(Rez.Strings.UIChooseCircle) as String,
                circleSub,
                "select_circle",
                {}
            )
        );
        var isTest = EGYMSafeStore.getPropertyBool(EGYMKeys.IS_TEST_MODE, false);

        startMenu.addItem(
            new WatchUi.ToggleMenuItem(
                WatchUi.loadResource(Rez.Strings.UIStrengthTestToggle) as String,
                null,
                "toggle_test",
                isTest,
                {}
            )
        );

        startMenu.addItem(
            new WatchUi.MenuItem(
                WatchUi.loadResource(Rez.Strings.UIStartTraining) as String,
                null,
                "start_workout",
                {}
            )
        );

        startMenu.addItem(
            new WatchUi.MenuItem(
                WatchUi.loadResource(Rez.Strings.UIStats) as String,
                WatchUi.loadResource(Rez.Strings.UIStatsSub) as String,
                "open_stats",
                {}
            )
        );

        startMenu.addItem(
            new WatchUi.MenuItem(
                WatchUi.loadResource(Rez.Strings.UIResetCalibration) as String,
                getResetCalibrationSubLabel(),
                "reset_calibration",
                {}
            )
        );
        return startMenu;
    }
    private function getLastSetupMenuSubLabel() as String {
        return WatchUi.loadResource(Rez.Strings.UIRepeatLastSetupSub) as String;
    }

    private function getResetCalibrationSubLabel() as String {
        if (_pendingCalibrationReset) {
            return WatchUi.loadResource(Rez.Strings.UIResetCalibrationConfirm) as String;
        }
        if (_calibrationResetCompleted) {
            return WatchUi.loadResource(Rez.Strings.UIResetCalibrationDone) as String;
        }
        return WatchUi.loadResource(Rez.Strings.UIResetCalibrationSub) as String;
    }
    private function formatMenuVersionTag(versionText as String) as String {
        var core = versionText;
        if (core.length() > 0 && core.substring(0, 1).toLower().equals("v")) {
            core = core.substring(1, core.length());
        }
        return "v" + core;
    }

    // ========================================================
    // RESOURCE MANAGEMENT
    // ========================================================

    function releaseResources() as Void {
        _resolvedExNames = null;
        _resolvedGoalNames = null;
        _resolvedMethodNames = null;
        _exerciseAliasMap = null;
    }
}









