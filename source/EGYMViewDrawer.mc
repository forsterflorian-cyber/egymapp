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

(:high_res)
class EGYMViewDrawer {

    // Color palette
    private const CLR_ACCENT    = 0xffaa00; // orange — headings, highlights
    private const CLR_POSITIVE  = 0x00ff00; // green  — PRs, good values
    private const CLR_HIGHLIGHT = 0x00aaff; // blue   — exercise names, selection
    private const CLR_SECONDARY = 0xaaaaaa; // light grey — labels, units
    private const CLR_DIM       = 0x555555; // dark grey  — muted / scroll arrows
    private const CLR_MID       = 0x777777; // medium grey
    private const CLR_WARN      = 0xff5500; // orange-red — save-failed, HR z4
    private const CLR_ERROR     = 0xaa0000; // dark red   — discard
    private const CLR_DANGER    = 0xff0000; // red        — HR z5
    private const CLR_CAUTION   = 0xffff00; // yellow     — HR z3
    private const CLR_OK        = 0x00aa00; // dark green — confirmed action

    // Layout caches (reset on session change)
    private var _breakLayoutCached as Boolean = false;
    private var _yTimer as Number = 0;
    private var _yBreakHint as Number = 0;
    private var _yNextLabel as Number = 0;
    private var _yNextName as Number = 0;

    // Header string caches (prevents GC spikes)
    private var _lastTimeRaw as Number = -1;
    private var _cachedTimeStr as String = "";
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

    // Device/layout cache
    private var _deviceType as Symbol = :unknown;
    private var _deviceTypeW as Number = -1;
    private var _deviceTypeH as Number = -1;
    private var _subscreenBounds as Graphics.BoundingBox? = null;
    private var _subscreenX as Number = 0;
    private var _subscreenY as Number = 0;
    private var _subscreenW as Number = 0;
    private var _subscreenH as Number = 0;
    private var _hasValidSubscreen as Boolean = false;

    // Text-fit cache (bounded to avoid unbounded growth)
    private const FIT_TEXT_CACHE_LIMIT = 120;
    private var _fitTextCache as Dictionary<String, String> = {} as Dictionary<String, String>;
    private var _fitTextCacheCount as Number = 0;

    // Width profile tables (initialized once, reused every frame)
    private var _wpContentInset as Array<Number> = [
        10, 10, 10, 12, 12, 14, 14,
        16, 12, 16, 20, 22, 18, 24
    ] as Array<Number>;

    private var _wpProgressBarWidth as Array<Number> = [
        86, 90, 96, 104, 112, 124, 140,
        154, 170, 186, 200, 214, 230, 240
    ] as Array<Number>;

    private var _wpRecordSplitOffset as Array<Number> = [
        10, 10, 10, 11, 12, 12, 13,
        14, 16, 18, 20, 22, 24, 24
    ] as Array<Number>;

    private var _wpRecordBoltXOffset as Array<Number> = [
        2, 2, 2, 2, 2, 2, 2,
        3, 3, 3, 4, 4, 4, 4
    ] as Array<Number>;

    private var _wpSideHintGap as Array<Number> = [
        3, 3, 3, 4, 4, 4, 4,
        5, 6, 6, 7, 8, 8, 8
    ] as Array<Number>;

    private var _wpDecisionButtonGap as Array<Number> = [
        12, 12, 12, 13, 14, 15, 16,
        18, 20, 22, 24, 26, 28, 28
    ] as Array<Number>;

    private var _wpDecisionButtonRadius as Array<Number> = [
        6, 6, 6, 7, 7, 8, 8,
        9, 10, 10, 11, 12, 12, 12
    ] as Array<Number>;

    // Height profile tables (initialized once, reused every frame)
    private var _hpProgramSummaryScale as Array<Number> = [
        0.16, 0.17, 0.175, 0.182, 0.186, 0.19, 0.195,
        0.20, 0.205, 0.21, 0.215, 0.22, 0.225
    ] as Array<Number>;

    private var _hpProgressBarScale as Array<Number> = [
        0.74, 0.745, 0.75, 0.752, 0.754, 0.756, 0.758,
        0.762, 0.768, 0.772, 0.776, 0.78, 0.784
    ] as Array<Number>;

    private var _hpMetricInfoLabelGap as Array<Number> = [
        12, 12, 13, 15, 16, 18, 20,
        22, 24, 26, 28, 30, 32
    ] as Array<Number>;

    private var _hpMetricValueGap as Array<Number> = [
        24, 26, 28, 32, 36, 42, 46,
        50, 60, 66, 72, 78, 84
    ] as Array<Number>;

    private var _hpBreakTitleGap as Array<Number> = [
        3, 3, 4, 5, 5, 6, 7,
        8, 9, 10, 11, 12, 13
    ] as Array<Number>;

    private var _hpBottomNameGap as Array<Number> = [
        8, 8, 9, 10, 11, 12, 13,
        14, 16, 17, 18, 19, 20
    ] as Array<Number>;

    private var _hpBottomLabelGap as Array<Number> = [
        10, 10, 11, 12, 13, 14, 15,
        16, 18, 19, 20, 21, 22
    ] as Array<Number>;

    private var _hpActionHintGap as Array<Number> = [
        8, 9, 10, 10, 11, 12, 13,
        14, 15, 16, 17, 18, 20
    ] as Array<Number>;

    private var _hpWorkoutBarLift as Array<Number> = [
        6, 6, 7, 8, 9, 10, 11,
        12, 14, 15, 16, 18, 20
    ] as Array<Number>;

    private var _hpWorkoutFooterTopGap as Array<Number> = [
        0, 0, 0, 0, 1, 1, 1,
        2, 2, 3, 4, 5, 6
    ] as Array<Number>;

    private var _hpWorkoutFooterLineGap as Array<Number> = [
        8, 8, 9, 10, 11, 12, 12,
        13, 12, 14, 16, 17, 18
    ] as Array<Number>;

    private var _hpWorkoutFooterHintGap as Array<Number> = [
        18, 18, 19, 20, 22, 23, 24,
        26, 42, 50, 56, 60, 64
    ] as Array<Number>;

    private var _hpAdjustValueExtraGap as Array<Number> = [
        0, 0, 1, 2, 3, 4, 5,
        6, 7, 8, 9, 10, 12
    ] as Array<Number>;

    private var _hpSuccessSummaryLineGap as Array<Number> = [
        16, 16, 17, 18, 18, 19, 20,
        20, 21, 22, 23, 24, 25
    ] as Array<Number>;

    private var _hpSuccessSummaryTailGap as Array<Number> = [
        14, 14, 14, 15, 15, 16, 16,
        17, 18, 19, 20, 21, 22
    ] as Array<Number>;

    private var _hpExerciseHintLineGap as Array<Number> = [
        10, 10, 11, 12, 13, 14, 15,
        16, 20, 22, 24, 26, 28
    ] as Array<Number>;

    private var _hpRecordRowMinHeight as Array<Number> = [
        14, 14, 14, 15, 16, 16, 16,
        18, 20, 22, 24, 26, 28
    ] as Array<Number>;

    private var _hpRecordBoltYOffset as Array<Number> = [
        1, 1, 1, 2, 2, 2, 2,
        3, 3, 3, 4, 4, 4
    ] as Array<Number>;

    private var _hpBoltMinHeight as Array<Number> = [
        7, 7, 7, 8, 8, 8, 9,
        10, 11, 12, 13, 14, 15
    ] as Array<Number>;

    private var _hpProgressBarHeight as Array<Number> = [
        3, 3, 3, 4, 4, 4, 4,
        5, 6, 6, 6, 7, 7
    ] as Array<Number>;

    private var _hpMetricUnitGap as Array<Number> = [
        3, 3, 3, 4, 4, 4, 4,
        5, 5, 6, 6, 6, 7
    ] as Array<Number>;

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
        _fitTextCache = {} as Dictionary<String, String>;
        _fitTextCacheCount = 0;
        _deviceType = :unknown;
        _deviceTypeW = -1;
        _deviceTypeH = -1;
        _subscreenBounds = null;
        _subscreenX = 0;
        _subscreenY = 0;
        _subscreenW = 0;
        _subscreenH = 0;
        _hasValidSubscreen = false;
    }

    // ========================================================
    // MAIN DISPATCH
    // ========================================================

    //! Called from EGYMView.onUpdate(). Clears the screen and
    //! dispatches to the appropriate draw method based on state.
    function draw(dc as Graphics.Dc, view as EGYMView) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        resolveDeviceType(w, h);
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

    private function resolveDeviceType(w as Number, h as Number) as Symbol {
        if (_deviceType != :unknown &&
            _deviceTypeW == w &&
            _deviceTypeH == h) {
            return _deviceType;
        }

        _deviceTypeW = w;
        _deviceTypeH = h;
        _deviceType = :default;
        _subscreenBounds = null;
        _subscreenX = 0;
        _subscreenY = 0;
        _subscreenW = 0;
        _subscreenH = 0;
        _hasValidSubscreen = false;

        var subscreen = null;
        if (WatchUi has :getSubscreen) {
            try {
                subscreen = WatchUi.getSubscreen();
            } catch (ignored) {
                subscreen = null;
            }
        }
        if (subscreen != null) {
            _subscreenBounds = subscreen as Graphics.BoundingBox;
            var box = _subscreenBounds as Graphics.BoundingBox;
            _subscreenX = box.x.toNumber();
            _subscreenY = box.y.toNumber();
            _subscreenW = box.width.toNumber();
            _subscreenH = box.height.toNumber();
            _hasValidSubscreen = _subscreenW > 0 && _subscreenH > 0;
        }

        var isMono = false;
        try {
            var settings = System.getDeviceSettings();
            if (settings != null && settings has :colorDepth && settings.colorDepth != null) {
                isMono = settings.colorDepth <= 1;
            }
        } catch (ignored2) {
            isMono = false;
        }

        var hasSubscreen = _hasValidSubscreen;
        var compact = (w <= 176 && h <= 176);
        if (EGYMBuildProfile.isInstinctLowMemoryBuild() || (hasSubscreen && compact && isMono)) {
            _deviceType = :instinct2;
        }

        return _deviceType;
    }

    private function isInstinct2Layout(w as Number, h as Number) as Boolean {
        return EGYMBuildProfile.isInstinctLowMemoryBuild() || resolveDeviceType(w, h) == :instinct2;
    }

    private function isInstinct2Active() as Boolean {
        return EGYMBuildProfile.isInstinctLowMemoryBuild() || _deviceType == :instinct2;
    }

    private function getInstinctMainLeft() as Number {
        return 6;
    }

    private function getInstinctMainRight(w as Number) as Number {
        var right = w - 6;
        if (_hasValidSubscreen) {
            var candidate = (_subscreenX - 4).toNumber();
            if (candidate > 72) {
                right = candidate;
            }
        } else if (EGYMBuildProfile.isInstinctLowMemoryBuild()) {
            right = w - 54;
        }
        if (right <= getInstinctMainLeft() + 40) {
            right = w - 6;
        }
        return right;
    }

    private function getInstinctMainWidth(w as Number) as Number {
        var width = (getInstinctMainRight(w) - getInstinctMainLeft()).toNumber();
        return width > 0 ? width : w;
    }

    private function getInstinctMainCenterX(w as Number) as Number {
        return getInstinctMainLeft() + (getInstinctMainWidth(w) / 2);
    }

    private function getPhaseContentCenterX(w as Number, h as Number) as Number {
        if (isInstinct2Layout(w, h)) {
            return getInstinctMainCenterX(w);
        }
        return w / 2;
    }

    private function getPhaseContentWidth(w as Number, h as Number) as Number {
        if (isInstinct2Layout(w, h)) {
            return getInstinctMainWidth(w);
        }
        return getSafeContentWidth(w);
    }

    private function getPhaseContentLeft(w as Number, h as Number) as Number {
        if (isInstinct2Layout(w, h)) {
            return getInstinctMainLeft();
        }
        return getContentInset(w);
    }

    private function getPhaseContentStartX(w as Number, h as Number, contentWidth as Number) as Number {
        return getPhaseContentLeft(w, h) + ((getPhaseContentWidth(w, h) - contentWidth) / 2);
    }

    private function getMonochromeAwareTextColor(defaultColor as Number) as Number {
        return isInstinct2Active() ? Graphics.COLOR_WHITE : defaultColor;
    }

    private function getMetaTextFont() as Graphics.FontType {
        return (EGYMBuildProfile.useSystemFontsOnly() && isInstinct2Active())
            ? Graphics.FONT_TINY
            : Graphics.FONT_XTINY;
    }

    private function getUnitTextFont() as Graphics.FontType {
        return (EGYMBuildProfile.useSystemFontsOnly() && isInstinct2Active())
            ? Graphics.FONT_TINY
            : Graphics.FONT_MEDIUM;
    }

    private function getProminentTextFont() as Graphics.FontType {
        return (EGYMBuildProfile.useSystemFontsOnly() && isInstinct2Active())
            ? Graphics.FONT_MEDIUM
            : Graphics.FONT_SMALL;
    }

    private function getBreakTimerFont() as Graphics.FontType {
        return (EGYMBuildProfile.useSystemFontsOnly() && isInstinct2Active())
            ? Graphics.FONT_MEDIUM
            : Graphics.FONT_NUMBER_HOT;
    }

    (:color_ui)
    private function drawVerticalPattern(
        dc as Graphics.Dc,
        x as Number,
        y as Number,
        width as Number,
        height as Number,
        step as Number
    ) as Void {
        if (width <= 0 || height <= 0) {
            return;
        }
        var stride = step < 1 ? 1 : step;
        var endX = x + width;
        var endY = y + height - 1;
        var px = x;
        while (px < endX) {
            dc.drawLine(px, y, px, endY);
            px += stride;
        }
    }

    (:is_instinct)
    private function drawVerticalPattern(
        dc as Graphics.Dc,
        x as Number,
        y as Number,
        width as Number,
        height as Number,
        step as Number
    ) as Void {
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
        if (isInstinct2Layout(w, h)) {
            drawOverlayViewInstinct2(dc, w, h, view, isDiscard);
            return;
        }
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
        dc.setColor(getMonochromeAwareTextColor(view.isShowingSaveFailed ? CLR_WARN : CLR_ERROR), -1);
        dc.drawText(
            w / 2, h * 0.35, Graphics.FONT_MEDIUM,
            title, Graphics.TEXT_JUSTIFY_CENTER
        );

        dc.setColor(getMonochromeAwareTextColor(CLR_DIM), -1);
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
        dc.setColor(getMonochromeAwareTextColor(CLR_POSITIVE), -1);
        dc.drawText(
            w / 2, h * 0.2, Graphics.FONT_SMALL,
            view._sCircuitComplete, Graphics.TEXT_JUSTIFY_CENTER
        );

        dc.setColor(Graphics.COLOR_WHITE, -1);
        dc.drawText(
            w / 2, h * 0.3, Graphics.FONT_SMALL,
            view.sessionTotalKg.toString() + view._sUnitKgSpaced,
            Graphics.TEXT_JUSTIFY_CENTER
        );

        dc.setColor(getMonochromeAwareTextColor(CLR_ACCENT), -1);
        dc.drawText(
            w / 2, h * 0.4, Graphics.FONT_SMALL,
            view.finalCalories.toString() + " " + view._sUnitKcal,
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
            dc.setColor(getMonochromeAwareTextColor(CLR_DIM), -1);
            dc.drawText(
                w / 2, recordsStartY, Graphics.FONT_XTINY,
                view._sNoRecords, Graphics.TEXT_JUSTIFY_CENTER
            );
        }

        dc.setColor(getMonochromeAwareTextColor(CLR_DIM), -1);
        dc.drawText(
            w / 2, h * 0.9, Graphics.FONT_XTINY,
            view._sBackSave, Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    private function drawOverlayViewInstinct2(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        view as EGYMView,
        isDiscard as Boolean
    ) as Void {
        var boxX = getInstinctMainLeft();
        var boxW = getInstinctMainWidth(w);
        var boxY = (h * 0.24).toNumber();
        var boxH = 30;
        var centerX = getInstinctMainCenterX(w);
        var labelFont = getMetaTextFont();
        var titleFont = getProminentTextFont();
        var title = isDiscard
            ? (view.isShowingSaveFailed ? view._sSaveFailed : view._sDiscarded)
            : view._sCircuitComplete;

        if (isDiscard) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.drawRectangle(boxX, boxY, boxW, boxH);
            drawVerticalPattern(dc, boxX + 2, boxY + 2, boxW - 4, boxH - 4, 4);
            dc.drawText(
                centerX, boxY + boxH / 2, titleFont,
                fitTextToWidth(dc, title, titleFont, boxW - 6),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
            dc.setColor(Graphics.COLOR_WHITE, -1);
            dc.drawText(
                centerX, h * 0.52, labelFont,
                fitTextToWidth(dc, view._sBackSave, labelFont, boxW),
                Graphics.TEXT_JUSTIFY_CENTER
            );
            return;
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        dc.fillRectangle(boxX, boxY, boxW, boxH);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        drawVerticalPattern(dc, boxX + 1, boxY + 1, boxW - 2, boxH - 2, 3);
        dc.drawText(
            centerX, boxY + boxH / 2, titleFont,
            fitTextToWidth(dc, title, titleFont, boxW - 6),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        dc.setColor(Graphics.COLOR_WHITE, -1);
        dc.drawText(
            centerX, h * 0.43, titleFont,
            view.sessionTotalKg.toString() + view._sUnitKgSpaced,
            Graphics.TEXT_JUSTIFY_CENTER
        );
        dc.drawText(
            centerX, h * 0.53, titleFont,
            view.finalCalories.toString() + " " + view._sUnitKcal,
            Graphics.TEXT_JUSTIFY_CENTER
        );

        var hint = fitTextToWidth(dc, view._sBackSave, labelFont, boxW);
        dc.drawText(
            centerX, h * 0.9, labelFont,
            hint, Graphics.TEXT_JUSTIFY_CENTER
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
        dc.setColor(getMonochromeAwareTextColor(CLR_SECONDARY), -1);
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
            dc.setColor(getMonochromeAwareTextColor(CLR_HIGHLIGHT), -1);
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
            var unit = (rec[:t] as String).equals(view.RECORD_TYPE_WATT) ? view._sUnitWSpaced : view._sUnitKgSpaced;
            var deltaStr = EGYMSafeStore.toNumber(rec[:d], 0).toString();

            dc.setColor(getMonochromeAwareTextColor(CLR_SECONDARY), -1);
            dc.drawText(
                w / 2 - splitOffset, startY, Graphics.FONT_XTINY,
                name, Graphics.TEXT_JUSTIFY_RIGHT
            );

            drawBolt(dc, w / 2 - getRecordBoltXOffset(w), startY + getRecordBoltYOffset(h), h);

            dc.setColor(getMonochromeAwareTextColor(CLR_POSITIVE), -1);
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

        dc.setColor(getMonochromeAwareTextColor(CLR_CAUTION), -1);
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

        dc.setColor(getMonochromeAwareTextColor(CLR_DIM), -1);
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
        var hr = view._sHeaderNoHr;
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
        var summaryWidth = getSafeContentWidth(w);
        var summaryX = w / 2;
        var summaryFont = getMetaTextFont();
        if (isInstinct2Layout(w, h)) {
            summaryWidth = getInstinctMainWidth(w);
            summaryX = getInstinctMainCenterX(w);
        }
        summaryText = fitTextToWidth(
            dc,
            summaryText,
            summaryFont,
            summaryWidth
        );

        dc.setColor(Graphics.COLOR_WHITE, -1);
        dc.drawText(
            summaryX, getProgramSummaryY(h), summaryFont,
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
        if (isInstinct2Layout(w, h)) {
            drawHeaderInstinct2(dc, w, h, view, hr, timeRaw);
            return;
        }

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
            _cachedHeaderRest = " | " + _cachedTimeStr + " | " + cals + " " + view._sUnitKcal;
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

    private function drawHeaderInstinct2(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        view as EGYMView,
        hr as String,
        timeRaw as Number
    ) as Void {
        var timeChanged = (timeRaw != _lastTimeRaw);
        if (timeChanged) {
            _lastTimeRaw = timeRaw;
            var m = timeRaw / 60;
            var s = timeRaw % 60;
            _cachedTimeStr = m.format("%02d") + ":" + s.format("%02d");
        }

        var headerFont = getMetaTextFont();
        var headerText = view._sHR + ":" + hr + " " + _cachedTimeStr;
        var maxW = getInstinctMainWidth(w);
        headerText = fitTextToWidth(dc, headerText, headerFont, maxW);

        var x = getInstinctMainLeft();
        var y = h <= 176 ? 8 : (h * 0.1).toNumber();
        dc.setColor(Graphics.COLOR_WHITE, -1);
        dc.drawText(x, y, headerFont, headerText, Graphics.TEXT_JUSTIFY_LEFT);
        var dividerY = y + dc.getFontHeight(headerFont) + 2;
        dc.drawLine(x, dividerY, x + maxW, dividerY);

        drawInstinctSubWindowStatus(dc, w, h, view);
    }

    private function drawInstinctSubWindowStatus(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        view as EGYMView
    ) as Void {
        if (!_hasValidSubscreen) {
            return;
        }

        var sx = _subscreenX;
        var sy = _subscreenY;
        var sw = _subscreenW;
        var sh = _subscreenH;
        if (sw < 20 || sh < 20) {
            return;
        }

        var label = view._sInstinctSet;
        var value = view._sInstinctDefaultProgress;
        if (view.currentPhase == view.PHASE_BREAK) {
            label = view._sInstinctRest;
            var elapsed = ((System.getTimer() - view.breakStartTime) / 1000).toNumber();
            if (elapsed < 0) {
                elapsed = 0;
            }
            value = elapsed.toString() + view._sUnitSeconds;
        } else {
            var total = view.zirkel.size();
            if (total < 1) {
                total = 1;
            }
            var current = view.index + 1;
            if (current < 1) {
                current = 1;
            } else if (current > total) {
                current = total;
            }
            value = current.toString() + "/" + total.toString();
        }

        dc.setClip(sx, sy, sw, sh);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        dc.fillRectangle(sx, sy, sw, sh);

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.drawRectangle(sx, sy, sw, sh);
        drawVerticalPattern(dc, sx + 1, sy + 1, sw - 2, 10, 3);

        var labelFont = getMetaTextFont();
        var valueFont = EGYMBuildProfile.useSystemFontsOnly()
            ? Graphics.FONT_MEDIUM
            : Graphics.FONT_SMALL;
        var maxLabelW = sw - 6;
        var maxValueW = sw - 6;
        dc.drawText(
            sx + sw / 2, sy + 4, labelFont,
            fitTextToWidth(dc, label, labelFont, maxLabelW),
            Graphics.TEXT_JUSTIFY_CENTER
        );

        if (dc.getTextWidthInPixels(value, valueFont) > maxValueW) {
            valueFont = labelFont;
        }
        dc.drawText(
            sx + sw / 2, sy + (sh * 0.62).toNumber(), valueFont,
            fitTextToWidth(dc, value, valueFont, maxValueW),
            Graphics.TEXT_JUSTIFY_CENTER
        );
        dc.clearClip();
    }

    //! OPTIMIZED: Fast integer math prevents floating point conversion overhead.
    private function drawProgressBar(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        view as EGYMView
    ) as Void {
        if (isInstinct2Layout(w, h)) {
            drawProgressBarInstinct2(dc, w, h, view);
            return;
        }

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

        dc.setColor(CLR_DIM, -1); // CLR_DIM (0x555555) visible on both AMOLED and MIP
        dc.fillRectangle((w - barW) / 2, barY, barW, getProgressBarHeight(h));
        dc.setColor(CLR_ACCENT, -1);
        dc.fillRectangle((w - barW) / 2, barY, progress, getProgressBarHeight(h));
    }

    private function drawProgressBarInstinct2(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        view as EGYMView
    ) as Void {
        var total = view.zirkel.size();
        if (total == 0) {
            return;
        }

        var completed = view.index;
        if (view.currentPhase == view.PHASE_ADJUST ||
            view.currentPhase == view.PHASE_BREAK) {
            completed = view.index + 1;
        }
        if (completed < 0) {
            completed = 0;
        } else if (completed > total) {
            completed = total;
        }

        var barX = getInstinctMainLeft();
        var barW = getInstinctMainWidth(w);
        var barY = getWorkoutProgressBarY(h);
        if (barY < 66) {
            barY = 66;
        }
        var barH = getProgressBarHeight(h) + 3;
        if (barH < 5) {
            barH = 5;
        }

        var fillW = ((completed * (barW - 2)) / total).toNumber();
        if (fillW < 0) {
            fillW = 0;
        } else if (fillW > barW - 2) {
            fillW = barW - 2;
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawRectangle(barX, barY, barW, barH);
        drawVerticalPattern(dc, barX + 1, barY + 1, barW - 2, barH - 2, 5);

        if (fillW > 0) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
            dc.fillRectangle(barX + 1, barY + 1, fillW, barH - 2);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            drawVerticalPattern(dc, barX + 1, barY + 1, fillW, barH - 2, 2);
        }

        var status = completed.toString() + "/" + total.toString();
        var statusFont = getMetaTextFont();
        dc.setColor(Graphics.COLOR_WHITE, -1);
        dc.drawText(
            barX + barW, barY - 13, statusFont,
            fitTextToWidth(dc, status, statusFont, barW),
            Graphics.TEXT_JUSTIFY_RIGHT
        );
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
        var centerX = getPhaseContentCenterX(w, dh);
        var contentWidth = getPhaseContentWidth(w, dh);
        var labelFont = getMetaTextFont();

        dc.setColor(getMonochromeAwareTextColor(CLR_SECONDARY), -1);
        dc.drawText(
            centerX, infoY, labelFont,
            view._cachedExInfo, Graphics.TEXT_JUSTIFY_CENTER
        );

        var exLabel = fitTextToWidth(dc, view._cachedExLabel, labelFont, contentWidth);

        dc.setColor(getMonochromeAwareTextColor(CLR_POSITIVE), -1);
        dc.drawText(
            centerX, labelY, labelFont,
            exLabel, Graphics.TEXT_JUSTIFY_CENTER
        );

        drawLargeWeight(dc, w, dh, view.currentWeight, view);

        var hintText = isCompactLayout(dh) ? view._sAdjustKgCompact : view._sAdjustKg;
        drawExerciseHintBlock(dc, w, dh, hintText, view._sSkipHintShort);

        drawNextExerciseHint(dc, w, dh, view);
    }

    private function drawLargeWeight(
        dc as Graphics.Dc,
        w as Number,
        dh as Number,
        weight as Number,
        view as EGYMView
    ) as Void {
        dc.setColor(Graphics.COLOR_WHITE, -1);
        var valueFont = getWeightValueFont(dh);
        var unitFont = getUnitTextFont();
        var weightWidth = dc.getTextWidthInPixels(weight.toString(), valueFont);
        var kgWidth = dc.getTextWidthInPixels(view._sUnitKg, unitFont);
        var gap = getMetricUnitGap(dh);
        var totalWidth = weightWidth + gap + kgWidth;
        var startX = getPhaseContentStartX(w, dh, totalWidth);
        var centerY = getMetricValueY(dh);

        dc.drawText(
            startX, centerY, valueFont,
            weight.toString(),
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );

        dc.setColor(getMonochromeAwareTextColor(CLR_SECONDARY), -1);
        dc.drawText(
            startX + weightWidth + gap, centerY, unitFont,
            view._sUnitKg,
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
        var centerX = getPhaseContentCenterX(w, dh);
        var contentWidth = getPhaseContentWidth(w, dh);
        var labelFont = getMetaTextFont();

        if (view.index < view.zirkel.size() - 1) {
            var nextName = fitTextToWidth(
                dc,
                view._cachedNextExLabel,
                nameFont,
                contentWidth
            );

            dc.setColor(getMonochromeAwareTextColor(CLR_HIGHLIGHT), -1);
            dc.drawText(
                centerX, labelY, labelFont,
                view._sNext, Graphics.TEXT_JUSTIFY_CENTER
            );
            dc.setColor(Graphics.COLOR_WHITE, -1);
            dc.drawText(
                centerX, nameY, nameFont,
                nextName, Graphics.TEXT_JUSTIFY_CENTER
            );
        } else if (!view.isIndividualMode) {
            dc.setColor(getMonochromeAwareTextColor(CLR_SECONDARY), -1);
            dc.drawText(
                centerX, labelY, labelFont,
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
        var centerX = getPhaseContentCenterX(w, dh);
        var contentWidth = getPhaseContentWidth(w, dh);
        var labelFont = getMetaTextFont();

        dc.setColor(getMonochromeAwareTextColor(CLR_ACCENT), -1);
        dc.drawText(
            centerX, infoY, labelFont,
            isExp ? view._sRateWatt : view._sRateQuality,
            Graphics.TEXT_JUSTIFY_CENTER
        );

        var exFont = (EGYMBuildProfile.useSystemFontsOnly() && isInstinct2Active())
            ? Graphics.FONT_TINY
            : (isCompactLayout(dh) ? Graphics.FONT_XTINY : Graphics.FONT_SMALL);
        var exLabel = fitTextToWidth(dc, view._cachedExLabel, exFont, contentWidth);

        dc.drawText(
            centerX, labelY, exFont,
            exLabel, Graphics.TEXT_JUSTIFY_CENTER
        );

        var suffix = isExp ? view._sUnitWSpaced : view._sUnitPercent;
        var numStr = view.qualityValue.toString();
        var centerY = getAdjustMetricValueY(dh);
        var valueFont = getAdjustValueFont(dh, isExp);
        var unitFont = getUnitTextFont();

        var numW = dc.getTextWidthInPixels(numStr, valueFont);
        var suffW = dc.getTextWidthInPixels(suffix, unitFont);
        var gap = getMetricUnitGap(dh);
        var startX = getPhaseContentStartX(w, dh, numW + gap + suffW);

        dc.setColor(getMonochromeAwareTextColor(CLR_ACCENT), -1);
        dc.drawText(
            startX, centerY, valueFont,
            numStr,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );

        dc.setColor(getMonochromeAwareTextColor(CLR_SECONDARY), -1);
        dc.drawText(
            startX + numW + gap, centerY, unitFont,
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
        var centerX = getPhaseContentCenterX(w, dh);
        var contentWidth = getPhaseContentWidth(w, dh);
        var labelFont = getMetaTextFont();

        dc.setColor(getMonochromeAwareTextColor(CLR_HIGHLIGHT), -1);
        dc.drawText(
            centerX, titleY, labelFont,
            view._sBreak, Graphics.TEXT_JUSTIFY_CENTER
        );

        var breakHint = view.isIndividualMode
            ? (isCompactLayout(dh) ? view._sBreakPickCompact : view._sBreakPickHint)
            : (isCompactLayout(dh) ? view._sBreakContinueCompact : view._sBreakContinueHint);
        dc.setColor(getMonochromeAwareTextColor(CLR_HIGHLIGHT), -1);
        dc.drawText(
            centerX, _yTimer, getBreakTimerFont(),
            elapsed.toString(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        drawActionHint(
            dc, w, dh, _yBreakHint, breakHint
        );

        if (view.index < view.zirkel.size() - 1) {
            var nextFont = getWorkoutNextNameFont(dh);
            var nextName = fitTextToWidth(
                dc,
                view._cachedNextExLabel,
                nextFont,
                contentWidth
            );
            dc.setColor(getMonochromeAwareTextColor(CLR_HIGHLIGHT), -1);
            dc.drawText(
                centerX, _yNextLabel, labelFont,
                view._sNext, Graphics.TEXT_JUSTIFY_CENTER
            );
            dc.setColor(Graphics.COLOR_WHITE, -1);
            dc.drawText(
                centerX, _yNextName,
                nextFont,
                nextName, Graphics.TEXT_JUSTIFY_CENTER
            );
        } else if (!view.isIndividualMode) {
            dc.setColor(getMonochromeAwareTextColor(CLR_SECONDARY), -1);
            dc.drawText(
                centerX, _yNextLabel, labelFont,
                view._sLastExercise, Graphics.TEXT_JUSTIFY_CENTER
            );
        }
    }

    private function drawActionHint(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        y as Number,
        text as String
    ) as Void {
        if (text.length() == 0) {
            return;
        }

        dc.setColor(getMonochromeAwareTextColor(CLR_MID), -1);
        dc.drawText(
            getPhaseContentCenterX(w, h), y, getMetaTextFont(),
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
        var maxWidth = getPhaseContentWidth(w, h);
        var centerX = getPhaseContentCenterX(w, h);
        var hintFont = getMetaTextFont();

        if (splitIdx != null) {
            line1 = trimAsciiText(hintText.substring(0, splitIdx));
            line2 = trimAsciiText(hintText.substring(splitIdx + 1, hintText.length()));
        }
        line1 = fitTextToWidth(dc, line1, hintFont, maxWidth);

        if (line2.length() > 0 && sideHint.length() > 0) {
            line2 = mergeTrailingHint(dc, line2, sideHint, maxWidth);
        } else if (line2.length() == 0 && sideHint.length() > 0) {
            line2 = fitTextToWidth(dc, sideHint, hintFont, maxWidth);
        } else if (line2.length() > 0) {
            line2 = fitTextToWidth(dc, line2, hintFont, maxWidth);
        }

        var baseY = getWorkoutActionHintY(h);
        var lineGap = getExerciseHintLineGap(h);
        var line1Y = baseY;
        var line2Y = baseY;

        if (line2.length() > 0) {
            line1Y = baseY - (lineGap / 2);
            line2Y = line1Y + lineGap;
        }

        dc.setColor(getMonochromeAwareTextColor(CLR_DIM), -1);
        dc.drawText(
            centerX, line1Y, hintFont,
            line1, Graphics.TEXT_JUSTIFY_CENTER
        );

        if (line2.length() > 0) {
            dc.drawText(
                centerX, line2Y, hintFont,
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
        var hintFont = getMetaTextFont();
        if (trailingHint.length() == 0) {
            return fitTextToWidth(dc, baseText, hintFont, maxWidth);
        }

        var joiner = "  ";
        var hintWidth = dc.getTextWidthInPixels(trailingHint, hintFont);
        var joinerWidth = dc.getTextWidthInPixels(joiner, hintFont);
        var reserved = hintWidth + joinerWidth;

        if (reserved >= maxWidth) {
            return trailingHint;
        }

        var baseWidth = maxWidth - reserved;
        var fittedBase = fitTextToWidth(dc, baseText, hintFont, baseWidth);
        if (fittedBase.length() == 0) {
            return trailingHint;
        }

        return fittedBase + joiner + trailingHint;
    }

    private function isCompactLayout(h as Number) as Boolean {
        return h <= 220;
    }

    private function getProgressBarY(h as Number) as Number {
        return (h * getHeightProfileValue(h, _hpProgressBarScale)).toNumber();
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
        return (h * getHeightProfileValue(h, _hpProgramSummaryScale)).toNumber();
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
        if (EGYMBuildProfile.useSystemFontsOnly() && isInstinct2Active()) {
            return Graphics.FONT_MEDIUM;
        }
        if (isInstinct2Active()) {
            return Graphics.FONT_LARGE;
        }
        return h <= 240 ? Graphics.FONT_LARGE : Graphics.FONT_NUMBER_HOT;
    }

    private function getWorkoutNextNameFont(h as Number) as Graphics.FontType {
        if (EGYMBuildProfile.useSystemFontsOnly() && isInstinct2Active()) {
            return Graphics.FONT_TINY;
        }
        if (h >= 360) {
            return Graphics.FONT_XTINY;
        }
        return isCompactLayout(h) ? Graphics.FONT_XTINY : Graphics.FONT_SMALL;
    }

    private function getAdjustValueFont(h as Number, isExp as Boolean) as Graphics.FontType {
        if (EGYMBuildProfile.useSystemFontsOnly() && isInstinct2Active()) {
            return Graphics.FONT_MEDIUM;
        }
        if (isInstinct2Active()) {
            return isExp ? Graphics.FONT_LARGE : Graphics.FONT_NUMBER_MILD;
        }
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
        if (maxWidth <= 0) {
            return "";
        }

        if (dc.getTextWidthInPixels(text, font) <= maxWidth) {
            return text;
        }

        var cacheKey = buildFitTextCacheKey(text, font, maxWidth);
        if (_fitTextCache.hasKey(cacheKey)) {
            return _fitTextCache[cacheKey] as String;
        }

        var ellipsis = "...";
        if (dc.getTextWidthInPixels(ellipsis, font) > maxWidth) {
            cacheFitTextResult(cacheKey, "");
            return "";
        }

        var end = text.length();
        while (end > 0) {
            var candidate = text.substring(0, end) + ellipsis;
            if (dc.getTextWidthInPixels(candidate, font) <= maxWidth) {
                cacheFitTextResult(cacheKey, candidate);
                return candidate;
            }
            end--;
        }

        cacheFitTextResult(cacheKey, ellipsis);
        return ellipsis;
    }

    private function buildFitTextCacheKey(
        text as String,
        font as Graphics.FontType,
        maxWidth as Number
    ) as String {
        return font.toString() + "|" + maxWidth.toString() + "|" + text;
    }

    private function cacheFitTextResult(key as String, value as String) as Void {
        if (_fitTextCacheCount >= FIT_TEXT_CACHE_LIMIT) {
            _fitTextCache = {} as Dictionary<String, String>;
            _fitTextCacheCount = 0;
        }

        if (!_fitTextCache.hasKey(key)) {
            _fitTextCacheCount += 1;
        }
        _fitTextCache[key] = value;
    }

    private function getSafeContentWidth(w as Number) as Number {
        var width = (w - (getContentInset(w) * 2)).toNumber();
        return width > 0 ? width : w;
    }

    private function getContentInset(w as Number) as Number {
        return getWidthProfileValue(w, _wpContentInset);
    }

    private function getMetricInfoGap(h as Number) as Number {
        return getHeightProfileValue(h, _hpMetricInfoLabelGap);
    }

    private function getMetricLabelGap(h as Number) as Number {
        return getHeightProfileValue(h, _hpMetricInfoLabelGap);
    }

    private function getMetricValueGap(h as Number) as Number {
        return getHeightProfileValue(h, _hpMetricValueGap);
    }

    private function getBreakTitleGap(h as Number) as Number {
        return getHeightProfileValue(h, _hpBreakTitleGap);
    }

    private function getBottomNameGap(h as Number) as Number {
        return getHeightProfileValue(h, _hpBottomNameGap);
    }

    private function getBottomLabelGap(h as Number) as Number {
        return getHeightProfileValue(h, _hpBottomLabelGap);
    }

    private function getActionHintGap(h as Number) as Number {
        return getHeightProfileValue(h, _hpActionHintGap);
    }

    private function getWorkoutBarLift(h as Number) as Number {
        return getHeightProfileValue(h, _hpWorkoutBarLift);
    }

    private function getWorkoutFooterShift(h as Number) as Number {
        return getBottomNameGap(h) + getBottomLabelGap(h) - 2;
    }

    private function getWorkoutFooterTopGap(h as Number) as Number {
        return getHeightProfileValue(h, _hpWorkoutFooterTopGap);
    }

    private function getWorkoutFooterLineGap(h as Number) as Number {
        return getHeightProfileValue(h, _hpWorkoutFooterLineGap);
    }

    private function getWorkoutFooterHintGap(h as Number) as Number {
        return getHeightProfileValue(h, _hpWorkoutFooterHintGap);
    }

    private function getAdjustValueExtraGap(h as Number) as Number {
        return getHeightProfileValue(h, _hpAdjustValueExtraGap);
    }

    private function getSuccessSummaryLineGap(h as Number) as Number {
        return getHeightProfileValue(h, _hpSuccessSummaryLineGap);
    }

    private function getSuccessSummaryTailGap(h as Number) as Number {
        return getHeightProfileValue(h, _hpSuccessSummaryTailGap);
    }

    private function getExerciseHintLineGap(h as Number) as Number {
        return getHeightProfileValue(h, _hpExerciseHintLineGap);
    }

    private function getProgressBarWidth(w as Number) as Number {
        return getWidthProfileValue(w, _wpProgressBarWidth);
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

        dc.setColor(getMonochromeAwareTextColor(CLR_MID), -1);
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
        return getHeightProfileValue(h, _hpRecordRowMinHeight);
    }

    private function getRecordSplitOffset(w as Number) as Number {
        return getWidthProfileValue(w, _wpRecordSplitOffset);
    }

    private function getRecordBoltXOffset(w as Number) as Number {
        return getWidthProfileValue(w, _wpRecordBoltXOffset);
    }

    private function getRecordBoltYOffset(h as Number) as Number {
        return getHeightProfileValue(h, _hpRecordBoltYOffset);
    }

    private function getBoltMinHeight(h as Number) as Number {
        return getHeightProfileValue(h, _hpBoltMinHeight);
    }

    private function getProgressBarHeight(h as Number) as Number {
        return getHeightProfileValue(h, _hpProgressBarHeight);
    }

    private function getMetricUnitGap(h as Number) as Number {
        return getHeightProfileValue(h, _hpMetricUnitGap);
    }

    private function getSideHintGap(w as Number) as Number {
        return getWidthProfileValue(w, _wpSideHintGap);
    }

    private function getDecisionButtonGap(w as Number) as Number {
        return getWidthProfileValue(w, _wpDecisionButtonGap);
    }

    private function getDecisionButtonRadius(w as Number) as Number {
        return getWidthProfileValue(w, _wpDecisionButtonRadius);
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
        if (isInstinct2Layout(w, h)) {
            drawEndViewInstinct2(dc, w, h, view);
            return;
        }

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

    private function drawEndViewInstinct2(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        view as EGYMView
    ) as Void {
        var centerX = getInstinctMainCenterX(w);
        var contentWidth = getInstinctMainWidth(w);
        var titleFont = getProminentTextFont();
        var labelFont = getMetaTextFont();
        dc.setColor(Graphics.COLOR_WHITE, -1);
        dc.drawText(
            centerX, h * 0.2, titleFont,
            fitTextToWidth(dc, view._sRoundComplete, titleFont, contentWidth),
            Graphics.TEXT_JUSTIFY_CENTER
        );
        dc.drawText(
            centerX, h * 0.36, labelFont,
            fitTextToWidth(dc, view._sAnotherRound, labelFont, contentWidth),
            Graphics.TEXT_JUSTIFY_CENTER
        );

        if (view._cachedBtnW != w || view._noBtnRect == null) {
            view._cachedBtnW = w;
            var btnW = (w * 0.32).toNumber();
            var btnH = 28;
            var gap = 14;
            var startY = (h * 0.62).toNumber();
            var leftX = (w / 2 - btnW - gap / 2).toNumber();
            var rightX = (w / 2 + gap / 2).toNumber();
            view._noBtnRect = [leftX, startY, btnW, btnH] as Array<Number>;
            view._yesBtnRect = [rightX, startY, btnW, btnH] as Array<Number>;
        }

        var nr = view._noBtnRect as Array<Number>;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawRectangle(nr[0], nr[1], nr[2], nr[3]);
        drawVerticalPattern(dc, nr[0] + 1, nr[1] + 1, nr[2] - 2, nr[3] - 2, 5);
        dc.drawText(
            nr[0] + nr[2] / 2, nr[1] + nr[3] / 2,
            labelFont, view._sNo,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        var yr = view._yesBtnRect as Array<Number>;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        dc.fillRectangle(yr[0], yr[1], yr[2], yr[3]);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        drawVerticalPattern(dc, yr[0] + 1, yr[1] + 1, yr[2] - 2, yr[3] - 2, 2);
        dc.drawText(
            yr[0] + yr[2] / 2, yr[1] + yr[3] / 2,
            labelFont, view._sYes,
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




