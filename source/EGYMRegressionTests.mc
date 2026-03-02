import Toybox.Test;
import Toybox.Lang;

(:test)
function testSafeStoreToNumber(logger) {
    Test.assertEqual(42, EGYMSafeStore.toNumber(42, -1));
    Test.assertEqual(17, EGYMSafeStore.toNumber("17", -1));
    Test.assertEqual(-1, EGYMSafeStore.toNumber("not-a-number", -1));
    return true;
}

(:test)
function testSafeStoreToBool(logger) {
    Test.assertEqual(true, EGYMSafeStore.toBool(true, false));
    Test.assertEqual(true, EGYMSafeStore.toBool(1, false));
    Test.assertEqual(false, EGYMSafeStore.toBool(0, true));
    Test.assertEqual(true, EGYMSafeStore.toBool("on", false));
    Test.assertEqual(false, EGYMSafeStore.toBool("off", true));
    return true;
}

(:test)
function testSafeStoreErrorCounterApi(logger) {
    EGYMSafeStore.resetErrorCounters();
    var counters = EGYMSafeStore.getErrorCounters();

    Test.assert(counters.hasKey("propertyReadErrors"));
    Test.assert(counters.hasKey("propertyWriteErrors"));
    Test.assert(counters.hasKey("storageReadErrors"));
    Test.assert(counters.hasKey("storageWriteErrors"));

    Test.assertEqual(0, counters["propertyReadErrors"]);
    Test.assertEqual(0, counters["propertyWriteErrors"]);
    Test.assertEqual(0, counters["storageReadErrors"]);
    Test.assertEqual(0, counters["storageWriteErrors"]);
    return true;
}

(:test)
function testAppParseZirkelStringMapping(logger) {
    var app = new EGYMApp();
    var parsed = app.parseZirkelString("chest press, squat, unknown");

    Test.assertEqual(3, parsed.size());
    Test.assertEqual("Brustpresse", parsed[0]);
    Test.assertEqual("Squat", parsed[1]);
    Test.assertEqual("unknown", parsed[2]);
    return true;
}

(:test)
function testAppRefreshRuntimeSnapshots(logger) {
    var app = new EGYMApp();

    app.refreshRuntimeSnapshots();

    Test.assert(app.getCachedStorageSchema() >= 0);
    Test.assert(app.getCachedMenuProgramSub().length() > 0);
    Test.assert(app.getCachedMenuCircleSub().length() > 0);
    return true;
}

(:test)
function testConfigProgramFieldFallbacks(logger) {
    var malformed = {
        :p => 12,
        :g => true,
        :m => null,
        :w => {},
        :i => "0.75"
    };

    Test.assertEqual("??", EGYMConfig.getProgramPrefix(malformed));
    Test.assertEqual("GoalUnknown", EGYMConfig.getProgramGoalKey(malformed));
    Test.assertEqual("REGULAR", EGYMConfig.getProgramMethodKey(malformed));
    Test.assertEqual("0", EGYMConfig.getProgramRepsSpec(malformed));

    var intensity = EGYMConfig.getProgramIntensityFactor(malformed);
    Test.assert(intensity > 0.74 && intensity < 0.76);
    return true;
}

(:test)
function testConfigExerciseListCopyIsolation(logger) {
    var first = EGYMConfig.getZirkelKraft();
    var baseline = first[0];
    first[0] = "MUTATED_LOCALLY";

    var second = EGYMConfig.getZirkelKraft();
    Test.assertEqual(baseline, second[0]);
    return true;
}

(:test)
function testViewParseHelpers(logger) {
    var view = new EGYMView();

    Test.assertEqual(0, view.parseTerm(null));
    Test.assertEqual(0, view.parseTerm(""));
    Test.assertEqual(16, view.parseTerm("2x8"));
    Test.assertEqual(16, view.parseTerm("2X8"));
    Test.assertEqual(15, view.parseTerm("3*5"));
    Test.assertEqual(16, view.parseTerm(" 2 x 8 "));
    Test.assertEqual(12, view.parseTerm("12"));
    Test.assertEqual(0, view.parseTerm("abc"));

    Test.assertEqual(0, view.parseReps(null));
    Test.assertEqual(0, view.parseReps(""));
    Test.assertEqual(20, view.parseReps("2x8+4"));
    Test.assertEqual(20, view.parseReps(" 2X8 + 4 "));
    Test.assertEqual(30, view.parseReps("2x10+2x5"));
    return true;
}

(:test)
function testViewStringHelpers(logger) {
    var view = new EGYMView();

    Test.assertEqual("ReverseButterfly", view.cleanExName("Reverse Butterfly"));
    Test.assertEqual("Abduktor", view.cleanExName("Abduktor"));
    Test.assertEqual("abc", view.truncate("abcdef", 3));
    Test.assertEqual("abc", view.truncate("abc", 5));

    Test.assertEqual(-1, view.compareStrings("abc", "abd"));
    Test.assertEqual(1, view.compareStrings("abd", "abc"));
    Test.assertEqual(0, view.compareStrings("abc", "abc"));
    return true;
}

(:test)
function testViewResetSessionState(logger) {
    var view = new EGYMView();

    view.isIndividualMode = true;
    view.isWaitingForExercisePick = true;
    view.index = 4;
    view.currentRound = 3;
    view.currentPhase = view.PHASE_BREAK;
    view.qualityValue = 77;
    view.currentWeight = 42;
    view.sessionTotalKg = 999;
    view.finalCalories = 123;
    view.isAskingForNewRound = true;
    view.isShowingSuccess = true;
    view.isShowingSaveFailed = true;
    view.isShowingDiscarded = true;
    view._pendingProgChange = 6;
    view._recordScrollIndex = 5;
    view.sessionRecords = [ { :n => "Squat", :d => 5, :t => "RM" } ] as Array<Dictionary>;

    view.resetSessionState();

    Test.assertEqual(false, view.isIndividualMode);
    Test.assertEqual(false, view.isWaitingForExercisePick);
    Test.assertEqual(0, view.index);
    Test.assertEqual(1, view.currentRound);
    Test.assertEqual(view.PHASE_EXERCISE, view.currentPhase);
    Test.assertEqual(100, view.qualityValue);
    Test.assertEqual(0, view.currentWeight);
    Test.assertEqual(0, view.sessionTotalKg);
    Test.assertEqual(0, view.finalCalories);
    Test.assertEqual(false, view.isAskingForNewRound);
    Test.assertEqual(false, view.isShowingSuccess);
    Test.assertEqual(false, view.isShowingSaveFailed);
    Test.assertEqual(false, view.isShowingDiscarded);
    Test.assertEqual(-1, view._pendingProgChange);
    Test.assertEqual(0, view._recordScrollIndex);
    Test.assertEqual(0, view.sessionRecords.size());
    return true;
}

(:test)
function testViewDiscardSessionClearsOverlayState(logger) {
    var view = new EGYMView();

    view.sessionTotalKg = 321;
    view.finalCalories = 88;
    view.currentPhase = view.PHASE_BREAK;
    view.isAskingForNewRound = true;
    view.isShowingSuccess = true;
    view.isShowingSaveFailed = true;
    view.sessionRecords = [ { :n => "Ruderzug", :d => 7, :t => "W" } ] as Array<Dictionary>;

    view.discardSession();

    Test.assertEqual(0, view.sessionTotalKg);
    Test.assertEqual(0, view.finalCalories);
    Test.assertEqual(view.PHASE_EXERCISE, view.currentPhase);
    Test.assertEqual(false, view.isAskingForNewRound);
    Test.assertEqual(false, view.isShowingSuccess);
    Test.assertEqual(false, view.isShowingSaveFailed);
    Test.assertEqual(true, view.isShowingDiscarded);
    Test.assertEqual(0, view.sessionRecords.size());
    return true;
}

(:test)
function testViewIndividualSelectionModes(logger) {
    var view = new EGYMView();
    view.zirkel = [ "Squat", "Latzug" ] as Array<String>;
    view.index = 1;

    view._individualPickMode = view.IND_PICK_REPLACE;
    view.applyIndividualExerciseSelection("Beinpresse");

    Test.assertEqual(2, view.zirkel.size());
    Test.assertEqual("Beinpresse", view.zirkel[1]);
    Test.assertEqual(view.IND_PICK_ADD, view._individualPickMode);

    view.removeLastIndividualExercise();

    Test.assertEqual(1, view.zirkel.size());
    Test.assertEqual("Squat", view.zirkel[0]);
    Test.assertEqual(0, view.index);
    return true;
}

(:test)
function testViewSessionSummaryHelpers(logger) {
    var view = new EGYMView();

    view._sSummarySets = "Sets";
    view._sSummaryPrs = "PRs";
    view._sSummaryAvgQuality = "Avg Quality";
    view._sSummaryAvgWatt = "Avg Watt";
    view._sSummaryTopPr = "Top PR";

    view.sessionSetCount = 3;
    view._sessionQualityTotal = 255;
    view._sessionQualityCount = 3;
    view.sessionRecords = [
        { :n => "Squat", :d => 4, :t => "RM" }
    ] as Array<Dictionary>;

    Test.assertEqual("Sets: 3 | PRs: 1", view.getSessionSummaryPrimaryLine());
    Test.assertEqual("Avg Quality: 85%", view.getSessionSummaryAverageLine());
    Test.assertEqual("85%", view.getSessionAverageFitValue());
    Test.assertEqual("Top PR: Squat +4 kg", view.getSessionSummaryTopRecordLine());

    view._sessionWattTotal = 180;
    view._sessionWattCount = 3;
    Test.assertEqual("60 W", view.getSessionAverageFitValue());
    return true;
}

(:test)
function testViewForceEndWithoutSessionShowsSaveFailed(logger) {
    var view = new EGYMView();

    view.sessionSetCount = 1;
    view.sessionTotalKg = 120;
    view.finalCalories = 12;

    view.forceEndZirkel();

    Test.assertEqual(false, view.isShowingSuccess);
    Test.assertEqual(true, view.isShowingDiscarded);
    Test.assertEqual(true, view.isShowingSaveFailed);
    return true;
}

(:test)
function testStatsViewFilterCycleReloadKeepsArraysAligned(logger) {
    var view = new EGYMStatsView();

    view.onShow();
    assertStatsArraysAligned(view);
    Test.assert(view._visibleCount >= 1);
    Test.assert(view._summarySessions >= 0);

    view.cycleFilter();
    Test.assertEqual(1, view._filterMode);
    assertStatsArraysAligned(view);

    view.cycleFilter();
    Test.assertEqual(2, view._filterMode);
    assertStatsArraysAligned(view);

    view.cycleFilter();
    Test.assertEqual(0, view._filterMode);
    assertStatsArraysAligned(view);
    return true;
}

function assertStatsArraysAligned(view as EGYMStatsView) as Void {
    var count = view._exercises.size();
    Test.assertEqual(count, view._cleanNames.size());
    Test.assertEqual(count, view._displayNames.size());
    Test.assertEqual(count, view._rmValues.size());
    Test.assertEqual(count, view._wattValues.size());
    Test.assertEqual(count, view._historyLines.size());

    var catalogCount = view._catalogExercises.size();
    Test.assertEqual(catalogCount, view._catalogCleanNames.size());
    Test.assertEqual(catalogCount, view._catalogDisplayNames.size());
    Test.assertEqual(catalogCount, view._catalogRmValues.size());
    Test.assertEqual(catalogCount, view._catalogWattValues.size());
    Test.assertEqual(catalogCount, view._catalogHistoryLines.size());
}



(:test)
function testStatsDelegateSelectCyclesFilter(logger) {
    var view = new EGYMStatsView();
    var delegate = new EGYMStatsDelegate(view);

    view.onShow();
    Test.assertEqual(0, view._filterMode);
    Test.assertEqual(true, delegate.onSelect());
    Test.assertEqual(1, view._filterMode);
    return true;
}

(:test)
function testDiagnosticsDelegateSelectResetsCounters(logger) {
    var view = new EGYMDiagnosticsView();
    var delegate = new EGYMDiagnosticsDelegate(view);

    view.onShow();
    Test.assertEqual(true, delegate.onSelect());
    return true;
}

(:test)
function testDiagnosticsViewRefreshAndResetSmoke(logger) {
    var view = new EGYMDiagnosticsView();

    view.onShow();
    view.resetCounters();
    return true;
}
