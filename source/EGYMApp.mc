import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.StringUtil;
import Toybox.WatchUi;

// ============================================================
// NEW EXERCISE CHECKLIST:
// [] EGYMConfig.mc     -> add to exercise array
// [] strings.xml       -> add ExName string (all locales)
// [] EGYMApp.mc        -> add to getExName() mapping
// [] properties.xml    -> add rm_ and watt_ properties
// [] settings XML      -> add Connect Mobile settings (optional)
// [] EGYMView.mc       -> add to getKnownExercises() rawNames
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
    private var _cachedStorageSchema as Number = 0;
    private var _cachedMenuProgramSub as String = "";
    private var _cachedMenuCircleSub as String = "";
    private var _sanityLoggingUnavailable as Boolean = false;

    // Storage schema for watch-side persisted data.
    private const CURRENT_STORAGE_SCHEMA_VERSION = 1;
    private const SANITY_LOG_PREFIX = "[EGYM sanity] ";
    private const APP_VERSION_TAG = "v0.5";

    // ========================================================
    // LIFECYCLE
    // ========================================================

    function initialize() {
        AppBase.initialize();
    }

    //! Called when the app starts; syncs settings from Connect Mobile
    function onStart(state as Dictionary?) as Void {
        EGYMSafeStore.resetErrorCounters();
        enforceLowMemoryProfileSettings();
        runStorageMigrations();
        syncAndMigrateProperties();
        if (!isLowMemoryProfile()) {
            runStartupSanityValidator();
        }
    }

    //! Called when the app stops; frees cached resource strings
    function onStop(state as Dictionary?) as Void {
        releaseResources();
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
        var key = normalizeLookupKey(trimString(input).toLower());
        if (key.length() == 0) {
            return null;
        }
        return resolveExerciseAliasKey(key);
    }

    private function normalizeLookupKey(str as String) as String {
        var chars = str.toCharArray();
        var normalized = [] as Array<Char>;

        for (var i = 0; i < chars.size(); i++) {
            var c = chars[i];
            if (c == 0x00FC || c == 0x00DC) {
                normalized.add('u');
                normalized.add('e');
            } else if (c == 0x00F6 || c == 0x00D6) {
                normalized.add('o');
                normalized.add('e');
            } else if (c == 0x00E4 || c == 0x00C4) {
                normalized.add('a');
                normalized.add('e');
            } else if (c == 0x00DF) {
                normalized.add('s');
                normalized.add('s');
            } else {
                normalized.add(c);
            }
        }

        return normalized.size() > 0 ? StringUtil.charArrayToString(normalized) : "";
    }

    private function resolveExerciseAliasKey(key as String) as String? {
        if (key.equals("chest press") || key.equals("brustpresse")) {
            return "Brustpresse";
        }
        if (key.equals("ab trainer") || key.equals("bauchtrainer")) {
            return "Bauchtrainer";
        }
        if (key.equals("seated row") || key.equals("ruderzug") || key.equals("rudern")) {
            return "Ruderzug";
        }
        if (key.equals("oblique") || key.equals("seitlicher bauch")) {
            return "Seitlicher Bauch";
        }
        if (key.equals("leg press") || key.equals("beinpresse")) {
            return "Beinpresse";
        }
        if (key.equals("lat pulldown") || key.equals("latzug") || key.equals("lat ziehen")) {
            return "Latzug";
        }
        if (key.equals("butterfly")) {
            return "Butterfly";
        }
        if (key.equals("back extension") || key.equals("rueckentrainer")) {
            return "Rueckentrainer";
        }
        if (key.equals("reverse fly") || key.equals("reverse butterfly")) {
            return "Reverse Butterfly";
        }
        if (key.equals("shoulder press") || key.equals("schulterpresse")) {
            return "Schulterpresse";
        }
        if (key.equals("squat")) {
            return "Squat";
        }
        if (key.equals("leg extension") || key.equals("beinstrecker")) {
            return "Beinstrecker";
        }
        if (key.equals("leg curl") || key.equals("beinbeuger")) {
            return "Beinbeuger";
        }
        if (key.equals("abductor") || key.equals("abduktor")) {
            return "Abduktor";
        }
        if (key.equals("adductor") || key.equals("adduktor")) {
            return "Adduktor";
        }
        if (key.equals("hip thrust")) {
            return "Hip Thrust";
        }
        if (key.equals("bicep curl") || key.equals("bizepscurl")) {
            return "Bizepscurl";
        }
        if (key.equals("tricep press") || key.equals("trizepspresse")) {
            return "Trizepspresse";
        }
        if (key.equals("glute") || key.equals("glutaeus")) {
            return "Glutaeus";
        }
        if (key.equals("calf raise") || key.equals("calves") ||
            key.equals("wadentrainer") || key.equals("waden")) {
            return "Wadentrainer";
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

        enforceLowMemoryProfileSettings();
        var zirkelString = EGYMSafeStore.getPropertyString(EGYMKeys.ZIRKEL_ORDER, "");
        if (zirkelString.length() > 0) {
            var parsed = parseZirkelString(zirkelString);
            if (parsed.size() > 0) {
                EGYMSafeStore.setStorageValue(EGYMKeys.CUSTOM_ZIRKEL, parsed);
            }
        }

        syncAndMigrateProperties();
        
        if (view.sm.isRecording()) {
            view.initExercisePhase();
        } else {
            var freshMenu = createStartMenu();
            WatchUi.switchToView(
                freshMenu,
                new EGYMStartMenuDelegate(),
                WatchUi.SLIDE_IMMEDIATE
            );
        }
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
            var item = trimString(remainingStr.substring(0, commaIndex));
            if (item.length() > 0) {
                var resolved = resolveExerciseName(item);
                arr.add(resolved != null ? resolved : item);
            }
            
            // Move past the comma
            remainingStr = remainingStr.substring(commaIndex + 1, remainingStr.length());
            commaIndex = remainingStr.find(",");
        }

        // Handle the final token
        var finalItem = trimString(remainingStr);
        if (finalItem.length() > 0) {
            var resolved = resolveExerciseName(finalItem);
            arr.add(resolved != null ? resolved : finalItem);
        }

        return arr;
    }

    function trimString(str as String) as String {
        var s = 0;
        var e = str.length() - 1;
        if (e < 0) {
            return "";
        }
        var chars = str.toCharArray();
        while (s <= e && (chars[s] == 0x20 || chars[s] == 0x09)) {
            s++;
        }
        while (e >= s && (chars[e] == 0x20 || chars[e] == 0x09)) {
            e--;
        }
        if (s > e) {
            return "";
        }
        return str.substring(s, e + 1);
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
            if (isLowMemoryProfile()) {
                _cachedMenuProgramSub = EGYMConfig.getProgramPrefix(programs[currentIndex]) +
                    " " + EGYMConfig.getProgramRepsSpec(programs[currentIndex]);
            } else {
                _cachedMenuProgramSub = EGYMConfig.getProgramDisplayString(programs[currentIndex]);
            }
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

    function toSafeNumber(val as Object?) as Number {
        if (val instanceof Number) {
            return val as Number;
        }
        if (val instanceof String) {
            var str = val as String;
            if (str.length() > 0) {
                var parsed = str.toNumber();
                if (parsed != null) {
                    return parsed;
                }
            }
        }
        if (val != null && val has :toNumber) {
            try {
                var converted = val.toNumber();
                if (converted != null && converted instanceof Number) {
                    return converted as Number;
                }
            } catch (e) {
                System.println("[EGYM app] Numeric coercion failed; using fallback.");
            }
        }
        return -1;
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
        var isPlus = EGYMSafeStore.getPropertyBool(EGYMKeys.IS_EGYM_PLUS, true);
        if (isLowMemoryProfile()) {
            isPlus = false;
        }

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

        if (!isLowMemoryProfile()) {
            startMenu.addItem(
                new WatchUi.MenuItem(
                    WatchUi.loadResource(Rez.Strings.UIStats) as String,
                    WatchUi.loadResource(Rez.Strings.UIStatsSub) as String,
                    "open_stats",
                    {}
                )
            );
        }
        return startMenu;
    }

    function isLowMemoryProfile() as Boolean {
        try {
            var settings = System.getDeviceSettings();
            var maxEdge = settings.screenWidth > settings.screenHeight
                ? settings.screenWidth
                : settings.screenHeight;
            return maxEdge <= 208;
        } catch (e) {
            return false;
        }
    }

    private function enforceLowMemoryProfileSettings() as Void {
        if (!isLowMemoryProfile()) {
            return;
        }

        if (EGYMSafeStore.getPropertyBool(EGYMKeys.IS_EGYM_PLUS, true)) {
            EGYMSafeStore.setPropertyValue(EGYMKeys.IS_EGYM_PLUS, false);
        }

        var activeProgram = EGYMSafeStore.getPropertyNumber(EGYMKeys.ACTIVE_PROGRAM, 0);
        var basicCount = EGYMConfig.getBasicPrograms().size();
        if (activeProgram < 0 || activeProgram >= basicCount) {
            EGYMSafeStore.setPropertyValue(EGYMKeys.ACTIVE_PROGRAM, 0);
        }
    }
    private function getLastSetupMenuSubLabel() as String {
        if (EGYMSafeStore.getStorageBool(EGYMKeys.LAST_SETUP_EXISTS, false)) {
            return WatchUi.loadResource(Rez.Strings.UIRepeatLastSetupSub) as String;
        }
        return WatchUi.loadResource(Rez.Strings.UIRepeatLastSetupEmpty) as String;
    }
    private function formatMenuVersionTag(versionText as String) as String {
        var core = versionText;
        if (core.length() > 0) {
            var firstChar = core.substring(0, 1).toLower();
            if (firstChar.equals("v")) {
                core = core.substring(1, core.length());
            }
        }

        var firstDot = core.find(".");
        if (firstDot != null) {
            var searchFrom = firstDot + 1;
            var tail = core.substring(searchFrom, core.length());
            var secondDotRel = tail.find(".");
            if (secondDotRel != null) {
                core = core.substring(0, searchFrom + secondDotRel);
            }
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
    }
}









