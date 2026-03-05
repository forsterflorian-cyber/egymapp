import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.FitContributor;
import Toybox.StringUtil;
import Toybox.System;

// EGYMSessionManager - Encapsulates FIT recording session
// lifecycle: creation, field setup, lap data writing,
// session save/discard.
//
// Extracted from EGYMView to reduce file size and separate
// recording concerns from UI logic.
// ============================================================


class EGYMSessionManager {
    private const SESSION_LOG_PREFIX = "[EGYM session] ";
    // FIT field IDs

    private const REPS_FIELD_ID = 0;
    private const WEIGHT_FIELD_ID = 1;
    private const PERF_FIELD_ID = 2;
    private const WORKLOAD_FIELD_ID = 3;
    private const TOTAL_SESSION_FIELD_ID = 4;
    private const EXERCISE_NAME_FIELD_ID = 5;
    private const AVG_PERF_FIELD_ID = 6;
    private const PROGRAM_NAME_FIELD_ID = 7;
    private const WATT_RECORDS_FIELD_ID = 8;
    private const METHOD_NAME_FIELD_ID = 9;
    private const WATT_RECORDS_FIELD_COUNT = 48;
    private const WATT_RECORDS_SAFE_CHARS = 47;
    private const AVG_PERF_FIELD_COUNT = 12;
    private const METHOD_NAME_FIELD_COUNT = 16;
    // Session and FIT field handles

    var session as ActivityRecording.Session? = null;
    private var _repsField as FitContributor.Field? = null;
    private var _weightField as FitContributor.Field? = null;
    private var _performanceField as FitContributor.Field? = null;
    private var _workloadField as FitContributor.Field? = null;
    private var _totalWeightField as FitContributor.Field? = null;
    private var _exerciseNameField as FitContributor.Field? = null;
    private var _avgPerformanceField as FitContributor.Field? = null;
    private var _programNameField as FitContributor.Field? = null;
    private var _wattRecordsField as FitContributor.Field? = null;
    private var _methodNameField as FitContributor.Field? = null;
    // ========================================================
    // SESSION LIFECYCLE
    // ========================================================

    //! Creates a new recording session and starts it.
    //! @return true if session started successfully
    function createAndStart() as Boolean {
        if (!(Toybox has :ActivityRecording)) {
            return false;
        }

        // Clean up any existing session
        cleanup();

        session = createCompatibleSession();
        if (session == null) {
            return false;
        }

        // FIT fields are nice-to-have; session.start() is CRITICAL
        try {
            setupFitFields();
        } catch (e) {
            logSessionIssue("setupFitFields failed; continuing without custom FIT fields.");
            nullifyFields();
        }

        try {
            if (session != null) {
                session.start();
                return true;
            }
        } catch (e) {
            logSessionIssue("session.start failed.");
            session = null;
        }
        return false;
    }

    //! Creates a session using a compatibility-first fallback chain.
    //! Some Connect web render paths are stricter about sport/sub-sport combos.
    private function createCompatibleSession() as ActivityRecording.Session? {
        var name = fitSafeLength(WatchUi.loadResource(Rez.Strings.AppName) as String, 15);

        // 1) Preferred for resistance training rendering on web.
        try {
            return ActivityRecording.createSession({
                :name => name,
                :sport => Activity.SPORT_GENERIC,
                :subSport => Activity.SUB_SPORT_STRENGTH_TRAINING
            });
        } catch (e1) {
            logSessionIssue("preferred strength session unsupported; trying HIIT fallback" + describeError(e1));
        }

        // 2) HIIT explicit fallback.
        try {
            return ActivityRecording.createSession({
                :name => name,
                :sport => Activity.SPORT_HIIT,
                :subSport => Activity.SUB_SPORT_HIIT
            });
        } catch (e2) {
            logSessionIssue("explicit HIIT session unsupported; trying legacy HIIT fallback" + describeError(e2));
        }

        // 3) Legacy HIIT fallback.
        try {
            return ActivityRecording.createSession({
                :name => name,
                :sport => Activity.SPORT_HIIT
            });
        } catch (e3) {
            logSessionIssue("legacy HIIT session unsupported; trying generic fallback" + describeError(e3));
        }

        // 4) Last-resort generic activity.
        try {
            return ActivityRecording.createSession({
                :name => name,
                :sport => Activity.SPORT_GENERIC,
                :subSport => Activity.SUB_SPORT_GENERIC
            });
        } catch (e4) {
            logSessionIssue("generic session fallback failed" + describeError(e4));
        }

        return null;
    }

    //! Returns true if a session exists and is actively recording.
    function isRecording() as Boolean {
        return session != null && session.isRecording();
    }

    //! Returns true if a session object exists, even if recording already stopped.
    function hasSession() as Boolean {
        return session != null;
    }

    //! Stops the session, writes final data, and saves the FIT file.
    //! @param totalKg    Total session volume in kg
    //! @param progName   Program display name for FIT file
    //! @param avgPerfStr Average session performance summary (e.g. "85%" or "63 W")
    //! @param methodName Training method display name for FIT file
    //! @param recordsStr Watt records summary string
    //! @return true if save succeeded
    function stopAndSave(
        totalKg as Number,
        progName as String,
        avgPerfStr as String,
        methodName as String,
        recordsStr as String
    ) as Boolean {
        if (session == null) {
            return false;
        }

        var wasRecording = session.isRecording();

        if (!wasRecording) {
            // Session was never started; discard the empty session if possible.
            try {
                session.discard();
            } catch (e) {
                logSessionIssue("discard on unsaved session failed.");
            }
            session = null;
            nullifyFields();
            return false;
        }
        // Write final session-level data safely.
        safeSetField(_totalWeightField, totalKg != null ? totalKg : 0, "session total");

        var safeProgramName = fitSafe(progName);
        if (safeProgramName.length() > 0) {
            safeSetField(_programNameField, safeProgramName, "program name");
        }

        var safeAvgPerformance = fitSafeLength(avgPerfStr, AVG_PERF_FIELD_COUNT);
        if (safeAvgPerformance.length() > 0) {
            safeSetField(_avgPerformanceField, safeAvgPerformance, "average performance");
        }

        var safeMethodName = fitSafeLength(methodName, METHOD_NAME_FIELD_COUNT);
        if (safeMethodName.length() > 0) {
            safeSetField(_methodNameField, safeMethodName, "method name");
        }

        var safeRecords = fitSafeLength(recordsStr, WATT_RECORDS_SAFE_CHARS);
        if (safeRecords.length() > 0) {
            safeSetField(_wattRecordsField, safeRecords, "record summary");
        }

        try {
            session.stop();
        } catch (e) {
            logSessionIssue("session.stop failed.");
        }

        var saved = false;
        try {
            session.save();
            saved = true;
        } catch (e) {
            logSessionIssue("session.save failed.");
            try {
                session.discard();
            } catch (e2) {
                logSessionIssue("discard after save failure failed.");
            }
        }

        session = null;
        nullifyFields();
        return saved;
    }

    //! Discards the session without saving.
    function discard() as Void {
        cleanup();
    }

    //! Cleans up any existing session (stop + discard).
    function cleanup() as Void {
        if (session != null) {
            try {
                if (session.isRecording()) {
                    session.stop();
                }
                session.discard();
            } catch (e) {
                logSessionIssue("cleanup failed while stopping/discarding session.");
            }
            session = null;
        }
        nullifyFields();
    }

    // ========================================================
    // LAP DATA
    // ========================================================

    //! Writes exercise data for the current lap safely.
    function writeLapData(
        exName as String,
        workload as Number,
        reps as Number,
        weight as Number,
        performance as Number
    ) as Void {
        if (!isRecording()) {
            return;
        }
        
        // Keep field writes non-fatal, but log failures for diagnostics.
        safeSetField(_exerciseNameField, fitSafe(exName), "exercise name");
        safeSetField(_workloadField, workload, "workload");
        safeSetField(_repsField, reps, "reps");
        safeSetField(_weightField, weight, "weight");
        safeSetField(_performanceField, performance, "performance");
    }

    //! Adds a lap marker safely when advancing to the next set.
    function addLapAndReset() as Void {
        if (!isRecording()) {
            return;
        }

        try {
            session.addLap();
        } catch (e) {
            logSessionIssue("session.addLap failed.");
        }
    }

    //! Reserved for live mid-session watt-records updates (currently disabled;
    //! final value is written in stopAndSave instead).
    function writeRecordsField(recordsStr as String) as Void {
    }

    //! Exposes the safe char budget for records summary strings.
    function getRecordsSafeLength() as Number {
        return WATT_RECORDS_SAFE_CHARS;
    }

    // ========================================================
    // FIT FIELD SETUP (PRIVATE)
    // ========================================================

    //! Creates all custom FIT fields. Each is individually
    //! try/caught so one failure doesn't block others.
    private function setupFitFields() as Void {
        if (session == null) {
            return;
        }

        try {
            _repsField = session.createField(
                WatchUi.loadResource(Rez.Strings.FitRepsLabel) as String,
                REPS_FIELD_ID, FitContributor.DATA_TYPE_UINT16,
                { :mesgType => FitContributor.MESG_TYPE_LAP }
            );
        } catch (e) {
            logSessionIssue("createField failed: reps");
            _repsField = null;
        }

        try {
            _weightField = session.createField(
                WatchUi.loadResource(Rez.Strings.FitWeightLabel) as String,
                WEIGHT_FIELD_ID, FitContributor.DATA_TYPE_UINT16,
                { :mesgType => FitContributor.MESG_TYPE_LAP }
            );
        } catch (e) {
            logSessionIssue("createField failed: weight");
            _weightField = null;
        }

        try {
            _performanceField = session.createField(
                WatchUi.loadResource(Rez.Strings.FitPerfLabel) as String,
                PERF_FIELD_ID, FitContributor.DATA_TYPE_UINT16,
                { :mesgType => FitContributor.MESG_TYPE_LAP }
            );
        } catch (e) {
            logSessionIssue("createField failed: performance");
            _performanceField = null;
        }

        try {
            _workloadField = session.createField(
                WatchUi.loadResource(Rez.Strings.FitWorkloadLabel) as String,
                WORKLOAD_FIELD_ID, FitContributor.DATA_TYPE_UINT32,
                { :mesgType => FitContributor.MESG_TYPE_LAP }
            );
        } catch (e) {
            logSessionIssue("createField failed: workload");
            _workloadField = null;
        }

        try {
            _exerciseNameField = session.createField(
                WatchUi.loadResource(Rez.Strings.FitExerciseLabel) as String,
                EXERCISE_NAME_FIELD_ID, FitContributor.DATA_TYPE_STRING,
                { :mesgType => FitContributor.MESG_TYPE_LAP, :count => 24 }
            );
        } catch (e) {
            logSessionIssue("createField failed: exercise name");
            _exerciseNameField = null;
        }

        try {
            _totalWeightField = session.createField(
                WatchUi.loadResource(Rez.Strings.FitTotalSessionLabel) as String,
                TOTAL_SESSION_FIELD_ID, FitContributor.DATA_TYPE_UINT32,
                { :mesgType => FitContributor.MESG_TYPE_SESSION }
            );
        } catch (e) {
            logSessionIssue("createField failed: session total");
            _totalWeightField = null;
        }

        try {
            _avgPerformanceField = session.createField(
                WatchUi.loadResource(Rez.Strings.FitAverageLabel) as String,
                AVG_PERF_FIELD_ID, FitContributor.DATA_TYPE_STRING,
                { :mesgType => FitContributor.MESG_TYPE_SESSION, :count => AVG_PERF_FIELD_COUNT }
            );
        } catch (e) {
            logSessionIssue("createField failed: average performance");
            _avgPerformanceField = null;
        }

        try {
            _programNameField = session.createField(
                WatchUi.loadResource(Rez.Strings.FitProgramLabel) as String,
                PROGRAM_NAME_FIELD_ID, FitContributor.DATA_TYPE_STRING,
                { :mesgType => FitContributor.MESG_TYPE_SESSION, :count => 24 }
            );
        } catch (e) {
            logSessionIssue("createField failed: program name");
            _programNameField = null;
        }

        try {
            _wattRecordsField = session.createField(
                WatchUi.loadResource(Rez.Strings.FitWattRecordsLabel) as String,
                WATT_RECORDS_FIELD_ID, FitContributor.DATA_TYPE_STRING,
                { :mesgType => FitContributor.MESG_TYPE_SESSION, :count => WATT_RECORDS_FIELD_COUNT }
            );
        } catch (e) {
            logSessionIssue("createField failed: record summary");
            _wattRecordsField = null;
        }

        try {
            _methodNameField = session.createField(
                WatchUi.loadResource(Rez.Strings.FitMethodLabel) as String,
                METHOD_NAME_FIELD_ID, FitContributor.DATA_TYPE_STRING,
                { :mesgType => FitContributor.MESG_TYPE_SESSION, :count => METHOD_NAME_FIELD_COUNT }
            );
        } catch (e) {
            logSessionIssue("createField failed: method name");
            _methodNameField = null;
        }
    }

    //! Releases all field references for GC.
    private function nullifyFields() as Void {
        _repsField = null;
        _weightField = null;
        _performanceField = null;
        _workloadField = null;
        _totalWeightField = null;
        _exerciseNameField = null;
        _avgPerformanceField = null;
        _programNameField = null;
        _wattRecordsField = null;
        _methodNameField = null;
    }

    private function safeSetField(field as FitContributor.Field?, value, context as String) as Void {
        if (field == null) {
            return;
        }

        try {
            field.setData(value);
        } catch (e) {
            logSessionIssue("field write failed: " + context);
        }
    }

    private function logSessionIssue(message as String) as Void {
        try {
            System.println(SESSION_LOG_PREFIX + message);
        } catch (ignored) {
            // Logging must never affect workout flow.
        }
    }

    private function describeError(err as Object?) as String {
        if (err == null) {
            return "";
        }

        try {
            if (err has :getErrorMessage) {
                var detail = err.getErrorMessage();
                if (detail != null) {
                    return ": " + detail.toString();
                }
            }
        } catch (ignored) {
            // Fall back to toString() below.
        }

        try {
            return ": " + err.toString();
        } catch (ignored2) {
            return "";
        }
    }

    //! Truncates a string safely. Since strings can contain multi-byte characters
    //! (like umlauts), normalize to ASCII first so :count limits are byte-safe.
    private function fitSafe(str as String?) as String {
        return fitSafeLength(str, 23);
    }
    
    //! Helper to truncate to a specific maximum length.
    private function fitSafeLength(str as String?, maxChars as Number) as String {
        if (str == null) {
            return "Unknown";
        }
        var ascii = toFitAscii(str);
        if (ascii.length() > maxChars) {
            return ascii.substring(0, maxChars);
        }
        return ascii;
    }

    //! Keep FIT strings strictly ASCII to avoid parser differences between platforms.
    //! Umlauts are transliterated via the shared utility; remaining non-printable
    //! characters are replaced with '_'.
    private function toFitAscii(str as String) as String {
        var substituted = EGYMSafeStore.applyUmlautSubstitution(str);
        var chars = substituted.toCharArray();
        var out = [] as Array<Char>;

        for (var i = 0; i < chars.size(); i++) {
            var c = chars[i];
            if (c >= 0x20 && c <= 0x7E) {
                out.add(c);
            } else {
                out.add('_');
            }
        }

        return out.size() > 0 ? StringUtil.charArrayToString(out) : "Unknown";
    }
}





