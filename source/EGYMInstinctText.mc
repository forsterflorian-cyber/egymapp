import Toybox.Lang;
class EGYMInstinctText {

    public static function getStartMenuTitle(isPlus as Boolean) as String {
        return isPlus ? "EGYM+" : "EGYM";
    }

    public static function getStartCircleLabel() as String {
        return "Circle";
    }

    public static function getStartProgramLabel() as String {
        return "Program";
    }

    public static function getStartTrainingLabel() as String {
        return "Go!";
    }

    public static function getProgramMenuTitle() as String {
        return "Program";
    }

    public static function getRepsLabel() as String {
        return "Reps";
    }

    public static function getCircleMenuTitle() as String {
        return "Circle";
    }

    public static function getCircleLabel(circleId as Number) as String {
        switch (circleId) {
            case 0: return "Strength";
            case 1: return "Legs";
            case 2: return "Custom";
            case 3: return "Free";
            default: return "Circle";
        }
    }

    public static function getCircleSubLabel(circleId as Number) as String {
        switch (circleId) {
            case 0: return "Default strength";
            case 1: return "Leg workout";
            case 2: return "Custom list";
            case 3: return "Free exercises";
            default: return "";
        }
    }

    public static function getGoalName(key as String) as String {
        switch (key) {
            case "GoalEndurance": return "Endurance";
            case "GoalMuscleBuild": return "Muscle";
            case "GoalRobustness": return "Robust";
            case "GoalMaxStrength": return "Max Strength";
            case "GoalToning": return "Toning";
            case "GoalFatBurn":
            case "GoalFatBurning": return "Fat Burn";
            case "GoalPower": return "Power";
            case "GoalActivation": return "Activation";
            case "GoalMetabolism":
            case "GoalMetabolicFit": return "Metabolism";
            case "GoalMobilization": return "Mobility";
            case "GoalStrength": return "Strength";
            case "GoalFunction": return "Function";
            case "GoalGettingStarted": return "Start";
            case "GoalProgress": return "Progress";
            case "GoalIntensify": return "Intensity";
            case "GoalSpeedStrength": return "Speed";
            case "GoalMaximize": return "Max";
            default: return key;
        }
    }

    public static function getMethodName(key as String) as String {
        switch (key) {
            case "REGULAR": return "Regular";
            case "ADAPTIVE": return "Adaptive";
            case "NEGATIVE": return "Negative";
            case "EXPLOSIVE":
            case "EXPLONIC": return "Explosive";
            case "ISOKINETIC": return "Isokinetic";
            default: return key;
        }
    }

    public static function getExerciseName(key as String) as String {
        switch (key) {
            case "Brustpresse": return "Chest Press";
            case "Bauchtrainer": return "Ab Trainer";
            case "Ruderzug": return "Seated Row";
            case "Seitlicher Bauch":
            case "SeitlicherBauch": return "Oblique";
            case "Beinpresse": return "Leg Press";
            case "Latzug": return "Lat Pull";
            case "Rueckentrainer": return "Back Ext";
            case "Reverse Butterfly":
            case "ReverseButterfly": return "Reverse Fly";
            case "Schulterpresse": return "Shoulder";
            case "Beinstrecker": return "Leg Ext";
            case "Beinbeuger": return "Leg Curl";
            case "Abduktor": return "Abductor";
            case "Adduktor": return "Adductor";
            case "HipThrust": return "Hip Thrust";
            case "Bizepscurl": return "Biceps";
            case "Trizepspresse": return "Triceps";
            case "Glutaeus": return "Glutes";
            case "Wadentrainer": return "Calf Raise";
            default: return key;
        }
    }

    public static function getProgramEmptyLabel() as String {
        return "Program";
    }

    public static function getWorkoutMenuTitle() as String {
        return "Menu";
    }

    public static function getWorkoutMenuSave() as String {
        return "Save";
    }

    public static function getWorkoutMenuSaveFlow() as String {
        return "Save Flow";
    }

    public static function getWorkoutMenuSaveFlowSub() as String {
        return "Save workout";
    }

    public static function getWorkoutMenuDiscard() as String {
        return "Discard";
    }

    public static function getWorkoutMenuDiscardSub() as String {
        return "Delete workout";
    }

    public static function getPickExerciseTitle() as String {
        return "Exercise";
    }

    public static function getPickExerciseFinish() as String {
        return "Done";
    }

    public static function getPickExerciseFinishSub() as String {
        return "Finish workout";
    }

    public static function getConfirmDiscard() as String {
        return "Discard workout?";
    }

    public static function getWeightLabel() as String {
        return "Weight";
    }

    public static function getKgLabel() as String {
        return "kg";
    }

    public static function getSetsLabel() as String {
        return "Sets";
    }

    public static function getDoneLabel() as String {
        return "Done";
    }

    public static function getDoneStatusLabel() as String {
        return "Done!";
    }

    public static function getDoneUpperLabel() as String {
        return "DONE";
    }

    public static function getGoLabel() as String {
        return "Go!";
    }

    public static function getNextLabel() as String {
        return "Next";
    }

    public static function formatNextExerciseLabel(name as String) as String {
        var safeName = name;
        if (safeName == null || safeName.length() == 0) {
            return getNextLabel();
        }
        return getNextLabel() + ": " + safeName;
    }

    public static function getTakeBreakLabel() as String {
        return "Take a break";
    }

    public static function getBreakLabel() as String {
        return "Break";
    }

    public static function formatPreviousExerciseLabel(name as String) as String {
        var safeName = name;
        if (safeName == null || safeName.length() == 0) {
            return "Prev";
        }
        return "Prev: " + safeName;
    }

    public static function getUndoLabel() as String {
        return "Undo";
    }

    public static function getRoundLabel() as String {
        return "Round";
    }

    public static function getNoCircuitLabel() as String {
        return "No Circuit";
    }

    public static function getDiscardedLabel() as String {
        return "Discarded";
    }

    public static function getSaveFailedLabel() as String {
        return "Save Failed";
    }

    public static function getExitFooterLabel() as String {
        return "Esc Exit";
    }

    public static function getRoundFooterLabel() as String {
        return "Enter Yes / Esc No";
    }

    public static function getAnotherRoundLabel() as String {
        return "Another Round?";
    }

    public static function getUnknown() as String {
        return "Unknown";
    }

    (:high_res)
    public static function assignViewStrings(view) as Void {
        view._sNoCircuit = "No Circuit";
        view._sHR = "HR";
        view._sRound = "Round";
        view._sAdjustKg = "UP/DN Weight";
        view._sAdjustKgCompact = "UP/DN kg";
        view._sNext = "Next";
        view._sRateWatt = "WATT";
        view._sRateQuality = "Quality";
        view._sAdjustConfirm = "OK confirm";
        view._sAdjustConfirmCompact = "OK";
        view._sBreak = "Break";
        view._sSkipHintShort = "< skip";
        view._sBackHintShort = "back >";
        view._sBreakContinueHint = "OK next";
        view._sBreakContinueCompact = "OK";
        view._sBreakPickHint = "OK pick";
        view._sBreakPickCompact = "OK pick";
        view._sCircuitComplete = "Done";
        view._sNewRecords = "Records";
        view._sNoRecords = "No PRs";
        view._sBackSave = "OK/BACK";
        view._sRoundComplete = "Round Done";
        view._sAnotherRound = "Another Round?";
        view._sYes = "Yes";
        view._sNo = "No";
        view._sLastExercise = "Last Exercise";
        view._sDiscarded = "Discarded";
        view._sSaveFailed = "Save Failed";
        view._sConfirmProgChange = "Discard Workout?";
        view._sReps = "Reps";
        view._sIndividualAddNext = "Next";
        view._sIndividualReplaceCurrent = "Replace";
        view._sIndividualUndoLast = "Undo";
        view._sModeActive = "Active";
        view._sSummarySets = "Sets";
        view._sSummaryPrs = "PRs";
        view._sSummaryAvgQuality = "Quality";
        view._sSummaryAvgWatt = "Watt";
        view._sSummaryTopPr = "Top";
        view._sSummaryTrendVsLast = "vs last";
        view._sSummaryTrendSame = "same";
        view._sSummaryTrend = "Trend";
        view._sUnknown = getUnknown();
        view._sUnitKg = "kg";
        view._sUnitW = "W";
        view._sUnitPercent = "%";
        view._sUnitSeconds = "s";
        view._sUnitKcal = "kcal";
        view._sInstinctSet = "Set";
        view._sInstinctRest = "Rest";
        view._sInstinctDefaultProgress = "1/1";
        view._sHeaderNoHr = "--";
        view._sUnitKgSpaced = " kg";
        view._sUnitWSpaced = " W";
        assignViewLogStrings(view);
    }

    (:high_res)
    public static function assignViewLogStrings(view) as Void {
        view._sLogPrefix = "[View] ";
        view._sLogPropWriteFailed = "Prop write failed";
        view._sLogCreateAndStartFailed = "FIT start failed";
        view._sLogUpdateSessionStatsFailed = "Stats update failed";
        view._sLogCheckpointSaveFailed = "Checkpoint failed";
        view._sLogRestoreCheckpointPropFailed = "Restore prop failed";
        view._sLogRestoreCheckpointCreateStartFailed = "Restore start failed";
        view._sLogProgramChangeAborted = "Program change aborted";
        view._sLogStorageWriteFailedPrefix = "Store failed ";
        view._sLogStorageWriteFailedMid = " key=";
    }

    public static function getWeightPickerTitle() as String {
        return "Strength Test";
    }

    public static function getWeightPickerChange() as String {
        return "UP/DN change";
    }

    public static function getWeightPickerConfirm() as String {
        return "OK confirm";
    }

    public static function getFitAppName() as String {
        return "EGYM Training";
    }

    public static function getFitRepsLabel() as String {
        return "Reps";
    }

    public static function getFitWeightLabel() as String {
        return "Weight";
    }

    public static function getFitPerfLabel() as String {
        return "Perf";
    }

    public static function getFitWorkloadLabel() as String {
        return "Workload";
    }

    public static function getFitExerciseLabel() as String {
        return "Exercise";
    }

    public static function getFitTotalSessionLabel() as String {
        return "Total Load";
    }

    public static function getFitAverageLabel() as String {
        return "Avg Perf";
    }

    public static function getFitProgramLabel() as String {
        return "Program";
    }

    public static function getFitWattRecordsLabel() as String {
        return "Records";
    }

    public static function getFitMethodLabel() as String {
        return "Method";
    }
}
