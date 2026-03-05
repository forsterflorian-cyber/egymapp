import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Activity;
import Toybox.UserProfile;

// ============================================================
// EGYMViewDrawer - All rendering logic for the workout view.
// Reads state from EGYMView but never modifies it.
// Extracted to keep EGYMView focused on state & logic.
// ============================================================

class EGYMViewDrawer {

    // Color palette
    private const CLR_ACCENT    = CLR_ACCENT; // orange — headings, highlights
    private const CLR_POSITIVE  = CLR_POSITIVE; // green  — PRs, good values
    private const CLR_HIGHLIGHT = CLR_HIGHLIGHT; // blue   — exercise names, selection
    private const CLR_SECONDARY = CLR_SECONDARY; // light grey — labels, units
    private const CLR_DIM       = CLR_DIM; // dark grey  — muted / scroll arrows
    private const CLR_MID       = CLR_MID; // medium grey
    private const CLR_DARK      = CLR_DARK; // very dark  — bar backgrounds
    private const CLR_WARN      = CLR_WARN; // orange-red — save-failed, HR z4
    private const CLR_ERROR     = CLR_ERROR; // dark red   — discard
    private const CLR_DANGER    = CLR_DANGER; // red        — HR z5
    private const CLR_CAUTION   = CLR_CAUTION; // yellow     — HR z3
    private const CLR_OK        = CLR_OK; // dark green — confirmed action

    // Layout caches (reset on session change)
    private var _breakLayoutCached as Boolean = false;
    private var _yTimer as Number = 0;
    private var _yBreakHint as Number = 0;
    private var _yNextLabel as Number = 0;
    private var _yNextName as Number = 0;

    // Header string caches (prevents GC spikes)
    private var _lastTimeRaw as Number = -1;
    private var _cachedTimeStr as String = "00:00";
    private var _lastCals as Number = -1;
    private var _cachedHeaderRest as String = "";

    // Polygon caches (prevent array allocations)
    private var _boltPoints as Array< [Numeric, Numeric] > = [
        [0,0] as [Numeric, Numeric], [0,0] as [Numeric, Numeric], [0,0] as [Numeric, Numeric], 
        [0,0] as [Numeric, Numeric], [0,0] as [Numeric, Numeric], [0,0] as [Numeric, Numeric], 
        [0,0] as [Numeric, Numeric]
    ] as Array< [Numeric, Numeric] >;
    
    private var _upTriPoints as Array< [Numeric, Numeric] > = [ 
        [0,0] as [Numeric, Numeric], [0,0] as [Numeric, Numeric], [0,0] as [Numeric, Numeric] 
    ] as Array< [Numeric, Numeric] >;
    
    private var _downTriPoints as Array< [Numeric, Numeric] > = [ 
        [0,0] as [Numeric, Numeric], [0,0] as [Numeric, Numeric], [0,0] as [Numeric, Numeric] 
    ] as Array< [Numeric, Numeric] >;

    // HR zone cache
    private var _hrZones as Array<Number>? = null;

    // ========================================================
    // INITIALIZATION
    // ========================================================

    function initialize() {
    }

    //! Resets all layout caches. Call when session resets or
    //! screen size could change (e.g. settings change).
    function resetCaches() as Void {
        _breakLayoutCached = false;
        _lastTimeRaw = -1;
        _lastCals = -1;
    }

    // ========================================================
    // MAIN DISPATCH
    // ========================================================

    //! Called from EGYMView.onUpdate(). Clears the screen and
    //! dispatches to the appropriate draw method based on state.
    function draw(dc as Graphics.Dc, view as EGYMView) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // Black screen while a picker or menu is open
        if (view.isWaitingForTestConfirm || view.isWaitingForExercisePick) {
            return;
        }

        if (view.isShowingDiscarded) {
            drawOverlayView(dc, w, h, view, true);
        } else if (view.isShowingSuccess) {
            drawOverlayView(dc, w, h, view, false);
        } else if (view.isAskingForNewRound) {
            drawEndView(dc, w, h, view);
        } else {
            drawMainView(dc, w, h, view);
        }
    }

    // ========================================================
    // OVERLAY: Success / Discarded
    // ========================================================

    private function drawOverlayView(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        view as EGYMView,
        isDiscard as Boolean
    ) as Void {
        if (isDiscard) {
            drawDiscardedOverlay(dc, w, h, view);
        } else {
            drawSuccessOverlay(dc, w, h, view);
        }
    }

    private function drawDiscardedOverlay(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        view as EGYMView
    ) as Void {
        var title = view.isShowingSaveFailed ? view._sSaveFailed : view._sDiscarded;
        dc.setColor(view.isShowingSaveFailed ? CLR_WARN : CLR_ERROR, -1);
        dc.drawText(
            w / 2, h * 0.35, Graphics.FONT_MEDIUM,
            title, Graphics.TEXT_JUSTIFY_CENTER
        );

        dc.setColor(CLR_DIM, -1);
        dc.drawText(
            w / 2, h * 0.55, Graphics.FONT_XTINY,
            view._sBackSave, Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    private function drawSuccessOverlay(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        view as EGYMView
    ) as Void {
        dc.setColor(CLR_POSITIVE, -1);
        dc.drawText(
            w / 2, h * 0.2, Graphics.FONT_SMALL,
            view._sCircuitComplete, Graphics.TEXT_JUSTIFY_CENTER
        );

        dc.setColor(Graphics.COLOR_WHITE, -1);
        dc.drawText(
            w / 2, h * 0.3, Graphics.FONT_SMALL,
            view.sessionTotalKg.toString() + " kg",
            Graphics.TEXT_JUSTIFY_CENTER
        );

        dc.setColor(CLR_ACCENT, -1);
        dc.drawText(
            w / 2, h * 0.4, Graphics.FONT_SMALL,
            view.finalCalories.toString() + " kcal",
            Graphics.TEXT_JUSTIFY_CENTER
        );

        var startY = drawSessionSummary(dc, w, h, view, (h * 0.50).toNumber());
        var recordsStartY = (h * 0.68).toNumber();
        if (startY > recordsStartY) {
            recordsStartY = startY;
        }

        if (view.sessionRecords.size() > 0) {
            drawRecordsList(dc, w, h, view, recordsStartY);
        } else {
            dc.setColor(CLR_DIM, -1);
            dc.drawText(
                w / 2, recordsStartY, Graphics.FONT_XTINY,
                view._sNoRecords, Graphics.TEXT_JUSTIFY_CENTER
            );
        }

        dc.setColor(CLR_DIM, -1);
        dc.drawText(
            w / 2, h * 0.9, Graphics.FONT_XTINY,
            view._sBackSave, Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    private function drawSessionSummary(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        view as EGYMView,
        startY as Number
    ) as Number {
        var lineY = startY;
        var maxWidth = getSafeContentWidth(w);

        var primary = fitTextToWidth(
            dc,
            view.getSessionSummaryPrimaryLine(),
            Graphics.FONT_XTINY,
            maxWidth
        );
        dc.setColor(CLR_SECONDARY, -1);
        dc.drawText(
            w / 2, lineY, Graphics.FONT_XTINY,
            primary, Graphics.TEXT_JUSTIFY_CENTER
        );

        var average = view.getSessionSummaryAverageLine();
        if (average.length() > 0) {
            lineY += getSuccessSummaryLineGap(h);
            dc.drawText(
                w / 2, lineY, Graphics.FONT_XTINY,
                fitTextToWidth(dc, average, Graphics.FONT_XTINY, maxWidth),
                Graphics.TEXT_JUSTIFY_CENTER
            );
        }

        var trend = view.getSessionSummaryTrendLine();
        if (trend.length() > 0) {
            lineY += getSuccessSummaryLineGap(h);
            dc.setColor(CLR_HIGHLIGHT, -1);
            dc.drawText(
                w / 2, lineY, Graphics.FONT_XTINY,
                fitTextToWidth(dc, trend, Graphics.FONT_XTINY, maxWidth),
                Graphics.TEXT_JUSTIFY_CENTER
            );
        }

        return lineY + getSuccessSummaryTailGap(h);
    }

    private function drawRecordsList(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        view as EGYMView,
        startY as Number
    ) as Void {
        dc.setColor(Graphics.COLOR_WHITE, -1);
        dc.drawText(
            w / 2, startY, Graphics.FONT_XTINY,
            view._sNewRecords, Graphics.TEXT_JUSTIFY_CENTER
        );

        var recordRowH = (h * 0.05).toNumber();
        var minRowH = getRecordRowMinHeight(h); if (recordRowH < minRowH) { recordRowH = minRowH; }
        startY += (h * 0.08).toNumber();

        var maxVisible = view.getMaxVisibleRecords();
        if (maxVisible < 1) { maxVisible = 1; }

        var endIdx = view._recordScrollIndex + maxVisible;
        if (endIdx > view.sessionRecords.size()) {
            endIdx = view.sessionRecords.size();
        }


        for (var i = view._recordScrollIndex; i < endIdx; i++) {
            var rec = view.sessionRecords[i] as Dictionary;
            if (!(rec[:n] instanceof String) || !(rec[:t] instanceof String)) {
                continue;
            }

            var splitOffset = getRecordSplitOffset(w);
            var nameWidth = ((w / 2) - splitOffset - getContentInset(w)).toNumber();
            var name = fitTextToWidth(dc, view.exDisplayName(rec[:n] as String), Graphics.FONT_XTINY, nameWidth);
            var unit = (rec[:t] as String).equals("W") ? " W" : " kg";
            var deltaStr = rec[:d] != null ? rec[:d].toString() : "0";

            dc.setColor(CLR_SECONDARY, -1);
            dc.drawText(
                w / 2 - splitOffset, startY, Graphics.FONT_XTINY,
                name, Graphics.TEXT_JUSTIFY_RIGHT
            );

            drawBolt(dc, w / 2 - getRecordBoltXOffset(w), startY + getRecordBoltYOffset(h), h);

            dc.setColor(CLR_POSITIVE, -1);
            dc.drawText(
                w / 2 + splitOffset, startY, Graphics.FONT_XTINY,
                "+" + deltaStr + unit,
                Graphics.TEXT_JUSTIFY_LEFT
            );
            startY += recordRowH;
        }

        if (view.sessionRecords.size() > maxVisible) {
            drawScrollIndicators(dc, w, h);
        }
    }

    //! OPTIMIZED: Reuses a single pre-allocated 2D array to eliminate memory leaks.
    private function drawBolt(
        dc as Graphics.Dc,
        bx as Number,
        by as Number,
        screenH as Number
    ) as Void {
        var boltH = (screenH * 0.028).toNumber();
        var minBoltH = getBoltMinHeight(screenH); if (boltH < minBoltH) { boltH = minBoltH; }
        var bw = (boltH * 0.4).toNumber();

        _boltPoints[0][0] = bx;          _boltPoints[0][1] = by;
        _boltPoints[1][0] = bx - bw;     _boltPoints[1][1] = by + (boltH * 6) / 10;
        _boltPoints[2][0] = bx;          _boltPoints[2][1] = by + (boltH * 6) / 10;
        _boltPoints[3][0] = bx - 1;      _boltPoints[3][1] = by + boltH;
        _boltPoints[4][0] = bx + bw + 1; _boltPoints[4][1] = by + (boltH * 4) / 10;
        _boltPoints[5][0] = bx + 1;      _boltPoints[5][1] = by + (boltH * 4) / 10;
        _boltPoints[6][0] = bx + 2;      _boltPoints[6][1] = by;

        dc.setColor(CLR_CAUTION, -1);
        dc.fillPolygon(_boltPoints);
    }

    //! OPTIMIZED: Reuses pre-allocated 2D arrays.
    private function drawScrollIndicators(
        dc as Graphics.Dc,
        w as Number,
        h as Number
    ) as Void {
        var cx = w / 2;
        var iy = (h * 0.84).toNumber();
        var triSize = (h * 0.015).toNumber();
        if (triSize < 3) { triSize = 3; }
        var gap = (h * 0.01).toNumber();
        if (gap < 2) { gap = 2; }

        // Up triangle
        _upTriPoints[0][0] = cx - triSize; _upTriPoints[0][1] = iy;
        _upTriPoints[1][0] = cx + triSize; _upTriPoints[1][1] = iy;
        _upTriPoints[2][0] = cx;           _upTriPoints[2][1] = iy - triSize;

        // Down triangle
        _downTriPoints[0][0] = cx - triSize; _downTriPoints[0][1] = iy + gap;
        _downTriPoints[1][0] = cx + triSize; _downTriPoints[1][1] = iy + gap;
        _downTriPoints[2][0] = cx;           _downTriPoints[2][1] = iy + gap + triSize;

        dc.setColor(CLR_DIM, -1);
        dc.fillPolygon(_upTriPoints);
        dc.fillPolygon(_downTriPoints);
    }

    // ========================================================
    // MAIN WORKOUT VIEW
    // ========================================================

    private function drawMainView(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        view as EGYMView
    ) as Void {
        if (view.zirkel.size() == 0) {
            dc.setColor(Graphics.COLOR_WHITE, -1);
            dc.drawText(
                w / 2, h / 2, Graphics.FONT_MEDIUM,
                view._sNoCircuit, Graphics.TEXT_JUSTIFY_CENTER
            );
            return;
        }

        var info = Activity.getActivityInfo();
        var hr = "--";
        var hrNum = 0;
        var timeRaw = 0;
        var cals = 0;

        if (info != null) {
            if (info.calories != null && info.calories > view.finalCalories) {
                view.finalCalories = info.calories;
            }
            if (info.currentHeartRate != null) {
                hrNum = info.currentHeartRate;
                hr = info.currentHeartRate.toString();
            }
            timeRaw = info.timerTime != null ? info.timerTime / 1000 : 0;
            cals = info.calories != null ? info.calories : 0;
        }

        drawHeader(dc, w, h, view, hr, hrNum, timeRaw, cals);

        var summaryText = view._cachedProgLabel + " | " + view._sRound + " " + view.currentRound;
        summaryText = fitTextToWidth(
            dc,
            summaryText,
            Graphics.FONT_XTINY,
            getSafeContentWidth(w)
        );

        dc.setColor(Graphics.COLOR_WHITE, -1);
        dc.drawText(
            w / 2, getProgramSummaryY(h), Graphics.FONT_XTINY,
            summaryText,
            Graphics.TEXT_JUSTIFY_CENTER
        );

        drawProgressBar(dc, w, h, view);

        if (view.currentPhase == view.PHASE_EXERCISE) {
            drawExercisePhase(dc, w, h, view);
        } else if (view.currentPhase == view.PHASE_ADJUST) {
            drawAdjustPhase(dc, w, h, view);
        } else if (view.currentPhase == view.PHASE_BREAK) {
            drawBreakPhase(dc, w, h, view);
        }

    }

    //! OPTIMIZED: Uses string caches to avoid formatting Strings and Arrays every frame
    private function drawHeader(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        view as EGYMView,
        hr as String,
        hrNum as Number,
        timeRaw as Number,
        cals as Number
    ) as Void {
        var timeChanged = (timeRaw != _lastTimeRaw);
        var calsChanged = (cals != _lastCals);

        // Only re-format the time string if the second changed.
        if (timeChanged) {
            _lastTimeRaw = timeRaw;
            var m = timeRaw / 60;
            var s = timeRaw % 60;
            _cachedTimeStr = m.format("%02d") + ":" + s.format("%02d");
        }

        // Rebuild suffix when either time or calories changed.
        if (timeChanged || calsChanged) {
            _lastCals = cals;
            _cachedHeaderRest = " | " + _cachedTimeStr + " | " + cals + " kcal";
        }

        var hrStr = view._sHR + ": " + hr;
        var safeWidth = getSafeContentWidth(w);
        var hrText = hrStr;
        var restText = _cachedHeaderRest;
        var hrW = dc.getTextWidthInPixels(hrText, Graphics.FONT_XTINY);

        if (hrW > safeWidth) {
            hrText = fitTextToWidth(dc, hrText, Graphics.FONT_XTINY, safeWidth);
            restText = "";
            hrW = dc.getTextWidthInPixels(hrText, Graphics.FONT_XTINY);
        } else {
            var availableRest = (safeWidth - hrW).toNumber();
            if (availableRest < 0) {
                availableRest = 0;
            }
            restText = fitTextToWidth(dc, restText, Graphics.FONT_XTINY, availableRest);
        }

        var restW = dc.getTextWidthInPixels(restText, Graphics.FONT_XTINY);
        var startX = (w - (hrW + restW)) / 2;
        var minX = getContentInset(w);
        if (startX < minX) {
            startX = minX;
        }

        dc.setColor(getHRZoneColor(hrNum), -1);
        dc.drawText(
            startX, h * 0.1, Graphics.FONT_XTINY,
            hrText, Graphics.TEXT_JUSTIFY_LEFT
        );
        
        dc.setColor(CLR_SECONDARY, -1);
        dc.drawText(
            startX + hrW, h * 0.1, Graphics.FONT_XTINY,
            restText, Graphics.TEXT_JUSTIFY_LEFT
        );
    }

    //! OPTIMIZED: Fast integer math prevents floating point conversion overhead.
    private function drawProgressBar(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        view as EGYMView
    ) as Void {
        var barW = getProgressBarWidth(w);
        var completed = view.index;
        if (view.currentPhase == view.PHASE_ADJUST ||
            view.currentPhase == view.PHASE_BREAK) {
            completed = view.index + 1;
        }
        var total = view.zirkel.size();
        if (total == 0) { return; }
        
        // Integer math is massively faster than Float division
        var progress = (completed * barW) / total;
        var barY = getWorkoutProgressBarY(h);

        dc.setColor(CLR_DARK, -1);
        dc.fillRectangle((w - barW) / 2, barY, barW, getProgressBarHeight(h));
        dc.setColor(CLR_ACCENT, -1);
        dc.fillRectangle((w - barW) / 2, barY, progress, getProgressBarHeight(h));
    }

    // ========================================================
    // EXERCISE PHASE
    // ========================================================

    private function drawExercisePhase(
        dc as Graphics.Dc,
        w as Number,
        dh as Number,
        view as EGYMView
    ) as Void {
        var infoY = getMetricInfoY(dh);
        var labelY = getMetricLabelY(dh);

        dc.setColor(CLR_SECONDARY, -1);
        dc.drawText(
            w / 2, infoY, Graphics.FONT_XTINY,
            view._cachedExInfo, Graphics.TEXT_JUSTIFY_CENTER
        );

        var exLabel = fitTextToWidth(dc, view._cachedExLabel, Graphics.FONT_XTINY, getSafeContentWidth(w));

        dc.setColor(CLR_POSITIVE, -1);
        dc.drawText(
            w / 2, labelY, Graphics.FONT_XTINY,
            exLabel, Graphics.TEXT_JUSTIFY_CENTER
        );

        drawLargeWeight(dc, w, dh, view.currentWeight);

        var hintText = isCompactLayout(dh) ? view._sAdjustKgCompact : view._sAdjustKg;
        drawExerciseHintBlock(dc, w, dh, hintText, view._sSkipHintShort);

        drawNextExerciseHint(dc, w, dh, view);
    }

    private function drawLargeWeight(
        dc as Graphics.Dc,
        w as Number,
        dh as Number,
        weight as Number
    ) as Void {
        dc.setColor(Graphics.COLOR_WHITE, -1);
        var valueFont = getWeightValueFont(dh);
        var weightWidth = dc.getTextWidthInPixels(weight.toString(), valueFont);
        var kgWidth = dc.getTextWidthInPixels("kg", Graphics.FONT_MEDIUM);
        var gap = getMetricUnitGap(dh);
        var startX = (w - (weightWidth + gap + kgWidth)) / 2;
        var centerY = getMetricValueY(dh);

        dc.drawText(
            startX, centerY, valueFont,
            weight.toString(),
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );

        dc.setColor(CLR_SECONDARY, -1);
        dc.drawText(
            startX + weightWidth + gap, centerY, Graphics.FONT_MEDIUM,
            "kg",
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    private function drawNextExerciseHint(
        dc as Graphics.Dc,
        w as Number,
        dh as Number,
        view as EGYMView
    ) as Void {
        var labelY = getWorkoutBottomLabelY(dh);
        var nameY = getWorkoutBottomNameY(dh);
        var nameFont = getWorkoutNextNameFont(dh);

        if (view.index < view.zirkel.size() - 1) {
            var nextName = fitTextToWidth(
                dc,
                view._cachedNextExLabel,
                nameFont,
                getSafeContentWidth(w)
            );

            dc.setColor(CLR_HIGHLIGHT, -1);
            dc.drawText(
                w / 2, labelY, Graphics.FONT_XTINY,
                view._sNext, Graphics.TEXT_JUSTIFY_CENTER
            );
            dc.setColor(Graphics.COLOR_WHITE, -1);
            dc.drawText(
                w / 2, nameY, nameFont,
                nextName, Graphics.TEXT_JUSTIFY_CENTER
            );
        } else if (!view.isIndividualMode) {
            dc.setColor(CLR_SECONDARY, -1);
            dc.drawText(
                w / 2, labelY, Graphics.FONT_XTINY,
                view._sLastExercise, Graphics.TEXT_JUSTIFY_CENTER
            );
        }
    }

    // ========================================================
    // ADJUST PHASE
    // ========================================================

    private function drawAdjustPhase(
        dc as Graphics.Dc,
        w as Number,
        dh as Number,
        view as EGYMView
    ) as Void {
        var isExp = view._cachedIsExp;
        var infoY = getMetricInfoY(dh);
        var labelY = getMetricLabelY(dh);

        dc.setColor(CLR_ACCENT, -1);
        dc.drawText(
            w / 2, infoY, Graphics.FONT_XTINY,
            isExp ? view._sRateWatt : view._sRateQuality,
            Graphics.TEXT_JUSTIFY_CENTER
        );

        var exFont = isCompactLayout(dh) ? Graphics.FONT_XTINY : Graphics.FONT_SMALL;
        var exLabel = fitTextToWidth(dc, view._cachedExLabel, exFont, getSafeContentWidth(w));

        dc.drawText(
            w / 2, labelY, exFont,
            exLabel, Graphics.TEXT_JUSTIFY_CENTER
        );

        var suffix = isExp ? " W" : "%";
        var numStr = view.qualityValue.toString();
        var centerY = getAdjustMetricValueY(dh);
        var valueFont = getAdjustValueFont(dh, isExp);

        var numW = dc.getTextWidthInPixels(numStr, valueFont);
        var suffW = dc.getTextWidthInPixels(suffix, Graphics.FONT_MEDIUM);
        var gap = getMetricUnitGap(dh);
        var startX = (w - (numW + gap + suffW)) / 2;

        dc.setColor(CLR_ACCENT, -1);
        dc.drawText(
            startX, centerY, valueFont,
            numStr,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );

        dc.setColor(CLR_SECONDARY, -1);
        dc.drawText(
            startX + numW + gap, centerY, Graphics.FONT_MEDIUM,
            suffix,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );

        var confirmText = isCompactLayout(dh) ? view._sAdjustConfirmCompact : view._sAdjustConfirm;
        drawExerciseHintBlock(dc, w, dh, confirmText, view._sBackHintShort);
    }

    // ========================================================
    // BREAK PHASE
    // ========================================================

    private function drawBreakPhase(
        dc as Graphics.Dc,
        w as Number,
        dh as Number,
        view as EGYMView
    ) as Void {
        var titleY = getBreakTitleY(dh);

        if (!_breakLayoutCached) {
            _breakLayoutCached = true;
            _yTimer = getMetricValueY(dh);
            _yBreakHint = getWorkoutActionHintY(dh);
            _yNextLabel = getWorkoutBottomLabelY(dh);
            _yNextName = getWorkoutBottomNameY(dh);
        }

        var elapsed = (System.getTimer() - view.breakStartTime) / 1000;

        dc.setColor(CLR_HIGHLIGHT, -1);
        dc.drawText(
            w / 2, titleY, Graphics.FONT_XTINY,
            view._sBreak, Graphics.TEXT_JUSTIFY_CENTER
        );

        var breakHint = view.isIndividualMode
            ? (isCompactLayout(dh) ? view._sBreakPickCompact : view._sBreakPickHint)
            : (isCompactLayout(dh) ? view._sBreakContinueCompact : view._sBreakContinueHint);
        dc.setColor(CLR_HIGHLIGHT, -1);
        dc.drawText(
            w / 2, _yTimer, Graphics.FONT_NUMBER_HOT,
            elapsed.toString(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        drawActionHint(
            dc, w, _yBreakHint, breakHint
        );

        if (view.index < view.zirkel.size() - 1) {
            var nextFont = getWorkoutNextNameFont(dh);
            var nextName = fitTextToWidth(
                dc,
                view._cachedNextExLabel,
                nextFont,
                getSafeContentWidth(w)
            );
            dc.setColor(CLR_HIGHLIGHT, -1);
            dc.drawText(
                w / 2, _yNextLabel, Graphics.FONT_XTINY,
                view._sNext, Graphics.TEXT_JUSTIFY_CENTER
            );
            dc.setColor(Graphics.COLOR_WHITE, -1);
            dc.drawText(
                w / 2, _yNextName,
                nextFont,
                nextName, Graphics.TEXT_JUSTIFY_CENTER
            );
        } else if (!view.isIndividualMode) {
            dc.setColor(CLR_SECONDARY, -1);
            dc.drawText(
                w / 2, _yNextLabel, Graphics.FONT_XTINY,
                view._sLastExercise, Graphics.TEXT_JUSTIFY_CENTER
            );
        }
    }

    private function drawActionHint(
        dc as Graphics.Dc,
        w as Number,
        y as Number,
        text as String
    ) as Void {
        if (text.length() == 0) {
            return;
        }

        dc.setColor(CLR_MID, -1);
        dc.drawText(
            w / 2, y, Graphics.FONT_XTINY,
            text, Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    private function drawExerciseHintBlock(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        hintText as String,
        sideHint as String
    ) as Void {
        var splitIdx = hintText.find(",");
        var line1 = hintText;
        var line2 = "";
        var maxWidth = getSafeContentWidth(w);

        if (splitIdx != null) {
            line1 = trimAsciiText(hintText.substring(0, splitIdx));
            line2 = trimAsciiText(hintText.substring(splitIdx + 1, hintText.length()));
        }
        line1 = fitTextToWidth(dc, line1, Graphics.FONT_XTINY, maxWidth);

        if (line2.length() > 0 && sideHint.length() > 0) {
            line2 = mergeTrailingHint(dc, line2, sideHint, maxWidth);
        } else if (line2.length() == 0 && sideHint.length() > 0) {
            line2 = fitTextToWidth(dc, sideHint, Graphics.FONT_XTINY, maxWidth);
        } else if (line2.length() > 0) {
            line2 = fitTextToWidth(dc, line2, Graphics.FONT_XTINY, maxWidth);
        }

        var baseY = getWorkoutActionHintY(h);
        var lineGap = getExerciseHintLineGap(h);
        var line1Y = baseY;
        var line2Y = baseY;

        if (line2.length() > 0) {
            line1Y = baseY - (lineGap / 2);
            line2Y = line1Y + lineGap;
        }

        dc.setColor(CLR_DIM, -1);
        dc.drawText(
            w / 2, line1Y, Graphics.FONT_XTINY,
            line1, Graphics.TEXT_JUSTIFY_CENTER
        );

        if (line2.length() > 0) {
            dc.drawText(
                w / 2, line2Y, Graphics.FONT_XTINY,
                line2, Graphics.TEXT_JUSTIFY_CENTER
            );
            return;
        }
    }

    private function mergeTrailingHint(
        dc as Graphics.Dc,
        baseText as String,
        trailingHint as String,
        maxWidth as Number
    ) as String {
        if (trailingHint.length() == 0) {
            return fitTextToWidth(dc, baseText, Graphics.FONT_XTINY, maxWidth);
        }

        var joiner = "  ";
        var hintWidth = dc.getTextWidthInPixels(trailingHint, Graphics.FONT_XTINY);
        var joinerWidth = dc.getTextWidthInPixels(joiner, Graphics.FONT_XTINY);
        var reserved = hintWidth + joinerWidth;

        if (reserved >= maxWidth) {
            return trailingHint;
        }

        var baseWidth = maxWidth - reserved;
        var fittedBase = fitTextToWidth(dc, baseText, Graphics.FONT_XTINY, baseWidth);
        if (fittedBase.length() == 0) {
            return trailingHint;
        }

        return fittedBase + joiner + trailingHint;
    }

    private function isCompactLayout(h as Number) as Boolean {
        return h <= 220;
    }

    private function getProgressBarY(h as Number) as Number {
        return (h * getHeightProfileValue(h, [
            0.74, 0.745, 0.75, 0.752, 0.754, 0.756, 0.758,
            0.762, 0.768, 0.772, 0.776, 0.78, 0.784
        ])).toNumber();
    }

    private function getBottomNameY(h as Number) as Number {
        return getProgressBarY(h) - getBottomNameGap(h);
    }

    private function getWorkoutProgressBarY(h as Number) as Number {
        return getProgressBarY(h)
            - getWorkoutBarLift(h)
            - getWorkoutFooterShift(h);
    }

    private function getWorkoutBottomNameY(h as Number) as Number {
        return getWorkoutBottomLabelY(h) + getWorkoutFooterLineGap(h);
    }

    private function getBottomLabelY(h as Number) as Number {
        return getBottomNameY(h) - getBottomLabelGap(h);
    }

    private function getWorkoutBottomLabelY(h as Number) as Number {
        return getWorkoutProgressBarY(h)
            + getProgressBarHeight(h)
            + getWorkoutFooterTopGap(h);
    }

    private function getActionHintY(h as Number) as Number {
        return getProgressBarY(h) + getActionHintGap(h);
    }

    private function getWorkoutActionHintY(h as Number) as Number {
        return getWorkoutBottomNameY(h)
            + getWorkoutFooterHintGap(h)
            + (getExerciseHintLineGap(h) / 2);
    }

    private function getPhaseHintY(h as Number) as Number {
        return getActionHintY(h);
    }

    private function getAdjustHintY(h as Number) as Number {
        return getActionHintY(h);
    }

    private function getProgramSummaryY(h as Number) as Number {
        return (h * getHeightProfileValue(h, [
            0.16, 0.17, 0.175, 0.182, 0.186, 0.19, 0.195,
            0.20, 0.205, 0.21, 0.215, 0.22, 0.225
        ])).toNumber();
    }

    private function getMetricInfoY(h as Number) as Number {
        return getProgramSummaryY(h) + getMetricInfoGap(h);
    }

    private function getMetricLabelY(h as Number) as Number {
        return getMetricInfoY(h) + getMetricLabelGap(h);
    }

    private function getMetricValueY(h as Number) as Number {
        return getMetricLabelY(h) + getMetricValueGap(h);
    }

    private function getAdjustMetricValueY(h as Number) as Number {
        return getMetricValueY(h) + getAdjustValueExtraGap(h);
    }

    private function getBreakTitleY(h as Number) as Number {
        return getMetricInfoY(h) + getBreakTitleGap(h);
    }

    private function getWeightValueFont(h as Number) as Graphics.FontType {
        return h <= 240 ? Graphics.FONT_LARGE : Graphics.FONT_NUMBER_HOT;
    }

    private function getWorkoutNextNameFont(h as Number) as Graphics.FontType {
        if (h >= 360) {
            return Graphics.FONT_XTINY;
        }
        return isCompactLayout(h) ? Graphics.FONT_XTINY : Graphics.FONT_SMALL;
    }

    private function getAdjustValueFont(h as Number, isExp as Boolean) as Graphics.FontType {
        if (isExp) {
            return Graphics.FONT_LARGE;
        }
        if (h >= 360) {
            return Graphics.FONT_LARGE;
        }
        return Graphics.FONT_NUMBER_HOT;
    }

    private function fitTextToWidth(
        dc as Graphics.Dc,
        text as String,
        font as Graphics.FontType,
        maxWidth as Number
    ) as String {
        if (text.length() == 0) {
            return text;
        }
        if (dc.getTextWidthInPixels(text, font) <= maxWidth) {
            return text;
        }

        var ellipsis = "...";
        if (dc.getTextWidthInPixels(ellipsis, font) > maxWidth) {
            return "";
        }

        var end = text.length();
        while (end > 0) {
            var candidate = text.substring(0, end) + ellipsis;
            if (dc.getTextWidthInPixels(candidate, font) <= maxWidth) {
                return candidate;
            }
            end--;
        }

        return ellipsis;
    }

    private function getSafeContentWidth(w as Number) as Number {
        var width = (w - (getContentInset(w) * 2)).toNumber();
        return width > 0 ? width : w;
    }

    private function getContentInset(w as Number) as Number {
        return getWidthProfileValue(w, [
            10, 10, 10, 12, 12, 14, 14,
            16, 12, 16, 20, 22, 18, 24
        ]);
    }

    private function getMetricInfoGap(h as Number) as Number {
        return getHeightProfileValue(h, [
            12, 12, 13, 15, 16, 18, 20,
            22, 24, 26, 28, 30, 32
        ]);
    }

    private function getMetricLabelGap(h as Number) as Number {
        return getHeightProfileValue(h, [
            12, 12, 13, 15, 16, 18, 20,
            22, 24, 26, 28, 30, 32
        ]);
    }

    private function getMetricValueGap(h as Number) as Number {
        return getHeightProfileValue(h, [
            24, 26, 28, 32, 36, 42, 46,
            50, 60, 66, 72, 78, 84
        ]);
    }

    private function getBreakTitleGap(h as Number) as Number {
        return getHeightProfileValue(h, [
            3, 3, 4, 5, 5, 6, 7,
            8, 9, 10, 11, 12, 13
        ]);
    }

    private function getBottomNameGap(h as Number) as Number {
        return getHeightProfileValue(h, [
            8, 8, 9, 10, 11, 12, 13,
            14, 16, 17, 18, 19, 20
        ]);
    }

    private function getBottomLabelGap(h as Number) as Number {
        return getHeightProfileValue(h, [
            10, 10, 11, 12, 13, 14, 15,
            16, 18, 19, 20, 21, 22
        ]);
    }

    private function getActionHintGap(h as Number) as Number {
        return getHeightProfileValue(h, [
            8, 9, 10, 10, 11, 12, 13,
            14, 15, 16, 17, 18, 20
        ]);
    }

    private function getWorkoutBarLift(h as Number) as Number {
        return getHeightProfileValue(h, [
            6, 6, 7, 8, 9, 10, 11,
            12, 14, 15, 16, 18, 20
        ]);
    }

    private function getWorkoutFooterShift(h as Number) as Number {
        return getBottomNameGap(h) + getBottomLabelGap(h) - 2;
    }

    private function getWorkoutFooterTopGap(h as Number) as Number {
        return getHeightProfileValue(h, [
            0, 0, 0, 0, 1, 1, 1,
            2, 2, 3, 4, 5, 6
        ]);
    }

    private function getWorkoutFooterLineGap(h as Number) as Number {
        return getHeightProfileValue(h, [
            8, 8, 9, 10, 11, 12, 12,
            13, 12, 14, 16, 17, 18
        ]);
    }

    private function getWorkoutFooterHintGap(h as Number) as Number {
        return getHeightProfileValue(h, [
            18, 18, 19, 20, 22, 23, 24,
            26, 42, 50, 56, 60, 64
        ]);
    }

    private function getAdjustValueExtraGap(h as Number) as Number {
        return getHeightProfileValue(h, [
            0, 0, 1, 2, 3, 4, 5,
            6, 7, 8, 9, 10, 12
        ]);
    }

    private function getSuccessSummaryLineGap(h as Number) as Number {
        return getHeightProfileValue(h, [
            16, 16, 17, 18, 18, 19, 20,
            20, 21, 22, 23, 24, 25
        ]);
    }

    private function getSuccessSummaryTailGap(h as Number) as Number {
        return getHeightProfileValue(h, [
            14, 14, 14, 15, 15, 16, 16,
            17, 18, 19, 20, 21, 22
        ]);
    }

    private function getExerciseHintLineGap(h as Number) as Number {
        return getHeightProfileValue(h, [
            10, 10, 11, 12, 13, 14, 15,
            16, 20, 22, 24, 26, 28
        ]);
    }

    private function getProgressBarWidth(w as Number) as Number {
        return getWidthProfileValue(w, [
            86, 90, 96, 104, 112, 124, 140,
            154, 170, 186, 200, 214, 230, 240
        ]);
    }

    // Exact screen classes from the products in manifest.xml (via local SDK docs):
    // heights: 156, 166, 176, 208, 218, 240, 260, 280, 360, 390, 416, 454, 486
    // widths:  163, 166, 176, 208, 218, 240, 260, 280, 320, 360, 390, 416, 448, 454
    private function getHeightProfileValue(h as Number, values as Array) {
        var idx = 0;
        if (h <= 160) {
            idx = 0;
        } else if (h <= 170) {
            idx = 1;
        } else if (h <= 180) {
            idx = 2;
        } else if (h <= 212) {
            idx = 3;
        } else if (h <= 220) {
            idx = 4;
        } else if (h <= 250) {
            idx = 5;
        } else if (h <= 270) {
            idx = 6;
        } else if (h <= 320) {
            idx = 7;
        } else if (h <= 375) {
            idx = 8;
        } else if (h <= 402) {
            idx = 9;
        } else if (h <= 435) {
            idx = 10;
        } else if (h <= 470) {
            idx = 11;
        } else {
            idx = 12;
        }

        if (idx >= values.size()) {
            idx = values.size() - 1;
        }
        return values[idx];
    }

    private function getWidthProfileValue(w as Number, values as Array) {
        var idx = 0;
        if (w <= 163) {
            idx = 0;
        } else if (w <= 166) {
            idx = 1;
        } else if (w <= 176) {
            idx = 2;
        } else if (w <= 208) {
            idx = 3;
        } else if (w <= 218) {
            idx = 4;
        } else if (w <= 240) {
            idx = 5;
        } else if (w <= 260) {
            idx = 6;
        } else if (w <= 280) {
            idx = 7;
        } else if (w <= 320) {
            idx = 8;
        } else if (w <= 360) {
            idx = 9;
        } else if (w <= 390) {
            idx = 10;
        } else if (w <= 416) {
            idx = 11;
        } else if (w <= 448) {
            idx = 12;
        } else {
            idx = 13;
        }

        if (idx >= values.size()) {
            idx = values.size() - 1;
        }
        return values[idx];
    }

    private function trimAsciiText(str as String) as String {
        if (str.length() == 0) {
            return str;
        }

        var chars = str.toCharArray();
        var start = 0;
        var endPos = chars.size() - 1;

        while (start <= endPos && (chars[start] == 0x20 || chars[start] == 0x09)) {
            start++;
        }
        while (endPos >= start && (chars[endPos] == 0x20 || chars[endPos] == 0x09)) {
            endPos--;
        }

        if (start > endPos) {
            return "";
        }
        return str.substring(start, endPos + 1);
    }

    private function drawSideActionHint(
        dc as Graphics.Dc,
        w as Number,
        y as Number,
        centerText as String,
        sideText as String,
        isLeft as Boolean,
        fallbackText as String
    ) as Void {
        var hintText = sideText;
        if (hintText.length() == 0) {
            return;
        }

        var safeInset = getSideHintInset(w);
        var centerWidth = dc.getTextWidthInPixels(centerText, Graphics.FONT_XTINY);
        var availableWidth = ((w - centerWidth) / 2 - safeInset - getSideHintGap(w)).toNumber();
        if (availableWidth <= 0) {
            return;
        }
        var hintWidth = dc.getTextWidthInPixels(hintText, Graphics.FONT_XTINY);

        if (hintWidth > availableWidth) {
            hintText = fallbackText;
            hintWidth = dc.getTextWidthInPixels(hintText, Graphics.FONT_XTINY);
            if (hintWidth > availableWidth) {
                return;
            }
        }

        dc.setColor(CLR_MID, -1);
        dc.drawText(
            isLeft ? safeInset : w - safeInset,
            y,
            Graphics.FONT_XTINY,
            hintText,
            isLeft ? Graphics.TEXT_JUSTIFY_LEFT : Graphics.TEXT_JUSTIFY_RIGHT
        );
    }

    private function getSideHintInset(w as Number) as Number {
        return getContentInset(w);
    }

    private function getRecordRowMinHeight(h as Number) as Number {
        return getHeightProfileValue(h, [
            14, 14, 14, 15, 16, 16, 16,
            18, 20, 22, 24, 26, 28
        ]);
    }

    private function getRecordSplitOffset(w as Number) as Number {
        return getWidthProfileValue(w, [
            10, 10, 10, 11, 12, 12, 13,
            14, 16, 18, 20, 22, 24, 24
        ]);
    }

    private function getRecordBoltXOffset(w as Number) as Number {
        return getWidthProfileValue(w, [
            2, 2, 2, 2, 2, 2, 2,
            3, 3, 3, 4, 4, 4, 4
        ]);
    }

    private function getRecordBoltYOffset(h as Number) as Number {
        return getHeightProfileValue(h, [
            1, 1, 1, 2, 2, 2, 2,
            3, 3, 3, 4, 4, 4
        ]);
    }

    private function getBoltMinHeight(h as Number) as Number {
        return getHeightProfileValue(h, [
            7, 7, 7, 8, 8, 8, 9,
            10, 11, 12, 13, 14, 15
        ]);
    }

    private function getProgressBarHeight(h as Number) as Number {
        return getHeightProfileValue(h, [
            3, 3, 3, 4, 4, 4, 4,
            5, 6, 6, 6, 7, 7
        ]);
    }

    private function getMetricUnitGap(h as Number) as Number {
        return getHeightProfileValue(h, [
            3, 3, 3, 4, 4, 4, 4,
            5, 5, 6, 6, 6, 7
        ]);
    }

    private function getSideHintGap(w as Number) as Number {
        return getWidthProfileValue(w, [
            3, 3, 3, 4, 4, 4, 4,
            5, 6, 6, 7, 8, 8, 8
        ]);
    }

    private function getDecisionButtonGap(w as Number) as Number {
        return getWidthProfileValue(w, [
            12, 12, 12, 13, 14, 15, 16,
            18, 20, 22, 24, 26, 28, 28
        ]);
    }

    private function getDecisionButtonRadius(w as Number) as Number {
        return getWidthProfileValue(w, [
            6, 6, 6, 7, 7, 8, 8,
            9, 10, 10, 11, 12, 12, 12
        ]);
    }

    // ========================================================
    // END-OF-ROUND VIEW
    // ========================================================

    private function drawEndView(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        view as EGYMView
    ) as Void {
        dc.setColor(CLR_POSITIVE, -1);
        dc.drawText(
            w / 2, h * 0.2, Graphics.FONT_SMALL,
            view._sRoundComplete, Graphics.TEXT_JUSTIFY_CENTER
        );

        dc.setColor(Graphics.COLOR_WHITE, -1);
        dc.drawText(
            w / 2, h / 2, Graphics.FONT_SMALL,
            view._sAnotherRound, Graphics.TEXT_JUSTIFY_CENTER
        );

        if (view._cachedBtnW != w || view._noBtnRect == null) {
            view._cachedBtnW = w;
            var btnW = (w * 0.3).toNumber();
            var btnH = (h * 0.2).toNumber();
            var gap = getDecisionButtonGap(w);
            var startY = (h / 2 + h * 0.2).toNumber();
            var leftX = (w / 2 - btnW - gap / 2).toNumber();
            var rightX = (w / 2 + gap / 2).toNumber();
            view._noBtnRect = [leftX, startY, btnW, btnH] as Array<Number>;
            view._yesBtnRect = [rightX, startY, btnW, btnH] as Array<Number>;
        }

        var nr = view._noBtnRect as Array<Number>;
        dc.setColor(CLR_ERROR, -1);
        dc.fillRoundedRectangle(nr[0], nr[1], nr[2], nr[3], getDecisionButtonRadius(w));
        dc.setColor(Graphics.COLOR_WHITE, -1);
        dc.drawText(
            nr[0] + nr[2] / 2, nr[1] + nr[3] / 2,
            Graphics.FONT_SMALL, view._sNo,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        var yr = view._yesBtnRect as Array<Number>;
        dc.setColor(CLR_OK, -1);
        dc.fillRoundedRectangle(yr[0], yr[1], yr[2], yr[3], getDecisionButtonRadius(w));
        dc.setColor(Graphics.COLOR_WHITE, -1);
        dc.drawText(
            yr[0] + yr[2] / 2, yr[1] + yr[3] / 2,
            Graphics.FONT_SMALL, view._sYes,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    // ========================================================
    // HR ZONE COLORS
    // ========================================================

    function getHRZones() as Array<Number>? {
        if (_hrZones != null) {
            return _hrZones;
        }
        try {
            var zones = UserProfile.getHeartRateZones(
                UserProfile.HR_ZONE_SPORT_GENERIC
            ) as Array<Number>?;
            if (zones != null && zones.size() >= 6) {
                _hrZones = zones;
                return _hrZones;
            }
        } catch (e) {
            // HR zones unavailable on this device
        }
        return null;
    }

    function getHRZoneColor(hr as Number) as Number {
        if (hr <= 0) {
            return CLR_SECONDARY;
        }

        var zones = getHRZones();
        if (zones != null) {
            if (hr >= zones[4]) { return CLR_DANGER; }  
            if (hr >= zones[3]) { return CLR_WARN; }  
            if (hr >= zones[2]) { return CLR_ACCENT; }  
            if (hr >= zones[1]) { return CLR_CAUTION; }  
            if (hr >= zones[0]) { return CLR_POSITIVE; }  
            return CLR_HIGHLIGHT;                           
        }

        if (hr < 100) { return CLR_HIGHLIGHT; }
        if (hr < 120) { return CLR_POSITIVE; }
        if (hr < 140) { return CLR_CAUTION; }
        if (hr < 160) { return CLR_ACCENT; }
        if (hr < 180) { return CLR_WARN; }
        return CLR_DANGER;
    }
}




