import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Application;
import Toybox.System;

(:high_res)
class EGYMStatsView extends WatchUi.View {
    private const FILTER_ALL = 0;
    private const FILTER_RM = 1;
    private const FILTER_WATT = 2;

    // Color palette (mirrors EGYMViewDrawer)
    private const CLR_ACCENT    = 0xffaa00; // orange — title, streak
    private const CLR_POSITIVE  = 0x00ff00; // green  — sessions, history delta
    private const CLR_HIGHLIGHT = 0x00aaff; // blue   — exercise names
    private const CLR_DIM       = 0x555555; // dark grey — filter label, scroll arrows

    var _scrollIndex as Number = 0;
    var _exercises as Array<String>;
    var _cleanNames as Array<String>;
    var _displayNames as Array<String>;
    var _rmValues as Array<Number>;
    var _wattValues as Array<Number>;
    var _historyLines as Array<String>;
    var _catalogExercises as Array<String>;
    var _catalogCleanNames as Array<String>;
    var _catalogDisplayNames as Array<String>;
    var _catalogRmValues as Array<Number>;
    var _catalogWattValues as Array<Number>;
    var _catalogHistoryLines as Array<String>;
    var _visibleCount as Number = 0;
    var _sTitle as String = "";
    var _sSessions as String = "";
    var _sVolume as String = "";
    var _sStreak as String = "";
    var _sNoData as String = "";
    var _sFilter as String = "";
    var _sFilterAll as String = "";
    var _sFilterRm as String = "";
    var _sFilterWatt as String = "";
    var _stringsLoaded as Boolean = false;

    var _itemsPerPage as Number = 3;
    var _pageCalculated as Boolean = false;
    var _pageCalcWidth as Number = -1;
    var _pageCalcHeight as Number = -1;
    var _filterMode as Number = FILTER_ALL;
    var _showHistory as Boolean = true;
    var _isNarrowRect as Boolean = false;
    var _layoutKnown as Boolean = false;
    var _summarySessions as Number = 0;
    var _summaryVolume as Number = 0;
    var _summaryStreak as Number = 0;
    var _catalogReady as Boolean = false;
    var _historyLoaded as Boolean = false;
    var _needsDeferredHistoryLoad as Boolean = false;
    // Polygon caches prevent array allocations on every frame.
    private var _upTriPoints as Array<[Numeric, Numeric]> =
        [
            [0, 0] as [Numeric, Numeric],
            [0, 0] as [Numeric, Numeric],
            [0, 0] as [Numeric, Numeric]
        ] as Array<[Numeric, Numeric]>;

    private var _downTriPoints as Array<[Numeric, Numeric]> =
        [
            [0, 0] as [Numeric, Numeric],
            [0, 0] as [Numeric, Numeric],
            [0, 0] as [Numeric, Numeric]
        ] as Array<[Numeric, Numeric]>;

    function initialize() {
        View.initialize();
        _exercises = [] as Array<String>;
        _cleanNames = [] as Array<String>;
        _displayNames = [] as Array<String>;
        _rmValues = [] as Array<Number>;
        _wattValues = [] as Array<Number>;
        _historyLines = [] as Array<String>;
        _catalogExercises = [] as Array<String>;
        _catalogCleanNames = [] as Array<String>;
        _catalogDisplayNames = [] as Array<String>;
        _catalogRmValues = [] as Array<Number>;
        _catalogWattValues = [] as Array<Number>;
        _catalogHistoryLines = [] as Array<String>;
        _needsDeferredHistoryLoad = false;
    }

    function release() as Void {
        _exercises = [] as Array<String>;
        _cleanNames = [] as Array<String>;
        _displayNames = [] as Array<String>;
        _rmValues = [] as Array<Number>;
        _wattValues = [] as Array<Number>;
        _historyLines = [] as Array<String>;
        _catalogExercises = [] as Array<String>;
        _catalogCleanNames = [] as Array<String>;
        _catalogDisplayNames = [] as Array<String>;
        _catalogRmValues = [] as Array<Number>;
        _catalogWattValues = [] as Array<Number>;
        _catalogHistoryLines = [] as Array<String>;
        _visibleCount = 0;
        _summarySessions = 0;
        _summaryVolume = 0;
        _summaryStreak = 0;
        _catalogReady = false;
        _historyLoaded = false;
        _needsDeferredHistoryLoad = false;
        _sTitle = "";
        _sSessions = "";
        _sVolume = "";
        _sStreak = "";
        _sNoData = "";
        _sFilter = "";
        _sFilterAll = "";
        _sFilterRm = "";
        _sFilterWatt = "";
    }

    function calculateItemsPerPage(dc as Graphics.Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();

        updateLayoutState(width, height);
        recalculateItemsPerPage(width, height);

        if (_needsDeferredHistoryLoad && _showHistory && !_historyLoaded && _filterMode != FILTER_WATT) {
            ensureHistoryLoaded();
            applyFilterFromCatalog();
            _needsDeferredHistoryLoad = false;
        }
    }

    private function initializeLayoutFromDevice() as Void {
        try {
            var settings = System.getDeviceSettings();
            updateLayoutState(settings.screenWidth, settings.screenHeight);
            recalculateItemsPerPage(settings.screenWidth, settings.screenHeight);
            _needsDeferredHistoryLoad = false;
        } catch (e) {
            _layoutKnown = false;
            _showHistory = false;
            _isNarrowRect = false;
            _needsDeferredHistoryLoad = true;
        }
    }

    private function updateLayoutState(width as Number, height as Number) as Void {
        _isNarrowRect = isNarrowRectStatsLayout(width, height);
        _showHistory = !isCompactStatsLayout(width, height);
        _layoutKnown = true;
    }

    private function recalculateItemsPerPage(width as Number, height as Number) as Void {
        if (_pageCalculated && _pageCalcWidth == width && _pageCalcHeight == height) {
            return;
        }
        _pageCalculated = true;
        _pageCalcWidth = width;
        _pageCalcHeight = height;

        var h = height;
        var isNarrowRect = _isNarrowRect;
        var contentTop = _showHistory ? getStatsContentTopY(h) : getStatsCompactContentTopY(h);
        var available = getStatsContentBottomY(h) - contentTop;
        var rowH = getStatsLineHeight(h);
        var summaryPenalty = getStatsSummaryHeight(h) - rowH;
        if (summaryPenalty < 0) {
            summaryPenalty = 0;
        }

        _itemsPerPage = ((available - summaryPenalty) / rowH).toNumber();
        if (_itemsPerPage < 2) {
            _itemsPerPage = 2;
        }
        var maxItems = getStatsMaxItems(width, height, isNarrowRect);
        if (_itemsPerPage > maxItems) {
            _itemsPerPage = maxItems;
        }
    }

    function onShow() as Void {
        loadStrings();
        ensureCatalog();
        _layoutKnown = false;
        _showHistory = false;
        _isNarrowRect = false;
        _pageCalculated = false;
        _pageCalcWidth = -1;
        _pageCalcHeight = -1;
        _needsDeferredHistoryLoad = false;
        initializeLayoutFromDevice();
        reloadStats();
    }

    function cycleFilter() as Boolean {
        if (!_layoutKnown || !_showHistory) {
            return false;
        }

        _filterMode += 1;
        if (_filterMode > FILTER_WATT) {
            _filterMode = FILTER_ALL;
        }
        ensureHistoryLoaded();
        applyFilterFromCatalog();
        WatchUi.requestUpdate();
        return true;
    }

    function scrollUp() as Void {
        if (_scrollIndex > 0) {
            _scrollIndex -= 1;
            WatchUi.requestUpdate();
        }
    }

    function scrollDown() as Void {
        var maxScroll = getMaxScrollIndex();
        if (_scrollIndex < maxScroll) {
            _scrollIndex += 1;
            WatchUi.requestUpdate();
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        calculateItemsPerPage(dc);

        var w = dc.getWidth();
        var h = dc.getHeight();
        var titleY = getStatsTitleY(h);
        var filterY = getStatsFilterY(h);
        var y = _showHistory ? getStatsContentTopY(h) : getStatsCompactContentTopY(h);
        var lineH = getStatsLineHeight(h);
        var summaryH = getStatsSummaryHeight(h);
        var contentBottom = getStatsContentBottomY(h);
        var contentWidth = getContentWidth(w);

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(CLR_ACCENT, -1);
        dc.drawText(
            w / 2,
            titleY,
            Graphics.FONT_XTINY,
            fitTextToWidth(dc, _sTitle, Graphics.FONT_XTINY, contentWidth),
            Graphics.TEXT_JUSTIFY_CENTER
        );

        if (_showHistory) {
            dc.setColor(CLR_DIM, -1);
            dc.drawText(
                w / 2,
                filterY,
                Graphics.FONT_XTINY,
                fitTextToWidth(
                    dc,
                    _sFilter + ": " + getFilterLabel(),
                    Graphics.FONT_XTINY,
                    contentWidth
                ),
                Graphics.TEXT_JUSTIFY_CENTER
            );
        }

        if (_visibleCount <= 1 && _summarySessions == 0) {
            dc.setColor(CLR_DIM, -1);
            dc.drawText(
                w / 2,
                getStatsEmptyY(h),
                Graphics.FONT_SMALL,
                fitTextToWidth(dc, _sNoData, Graphics.FONT_SMALL, contentWidth),
                Graphics.TEXT_JUSTIFY_CENTER
            );
            return;
        }

        var visibleSeen = 0;
        var itemIndex = 0;
        var drawn = 0;

        while (visibleSeen < _scrollIndex && itemIndex <= _exercises.size()) {
            visibleSeen += 1;
            itemIndex += 1;
        }

        while (drawn < _itemsPerPage && itemIndex <= _exercises.size()) {
            var itemBottom = itemIndex == 0 ? y + summaryH : y + lineH;
            if (itemBottom > contentBottom) {
                break;
            }

            if (itemIndex == 0) {
                drawSummary(dc, w, h, y);
                y += summaryH;
            } else {
                drawExerciseStat(dc, w, h, y, itemIndex - 1);
                y += lineH;
            }

            drawn += 1;
            itemIndex += 1;
        }

        if (_visibleCount > _itemsPerPage) {
            drawScrollIndicators(dc, w, h);
        }
    }

    function drawSummary(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        y as Number
    ) as Void {
        var sessions = _summarySessions;
        var volume = _summaryVolume;
        var streak = _summaryStreak;
        var rowH = getStatsSummaryRowHeight(h);
        var contentWidth = getContentWidth(w);

        if (_showHistory) {
            dc.setColor(CLR_POSITIVE, -1);
            dc.drawText(
                w / 2,
                y,
                Graphics.FONT_XTINY,
                fitTextToWidth(
                    dc,
                    _sSessions + ": " + sessions.toString(),
                    Graphics.FONT_XTINY,
                    contentWidth
                ),
                Graphics.TEXT_JUSTIFY_CENTER
            );
        }

        var volStr =
            volume > 1000
                ? (volume / 1000).toString() + "t"
                : volume.toString() + "kg";

        if (!_showHistory) {
            var compactLine1 = _sSessions + ": " + sessions.toString();
            var compactLine2 = _sVolume + ": " + volStr;

            if (!isNarrowRectStatsLayout(w, h)) {
                compactLine1 = _sSessions + ": " + sessions.toString() + " | " +
                    _sStreak + ": " + streak.toString();
            }

            dc.setColor(CLR_POSITIVE, -1);
            dc.drawText(
                w / 2,
                y,
                Graphics.FONT_XTINY,
                fitTextToWidth(
                    dc,
                    compactLine1,
                    Graphics.FONT_XTINY,
                    contentWidth
                ),
                Graphics.TEXT_JUSTIFY_CENTER
            );

            dc.setColor(Graphics.COLOR_WHITE, -1);
            dc.drawText(
                w / 2,
                y + rowH,
                Graphics.FONT_XTINY,
                fitTextToWidth(
                    dc,
                    compactLine2,
                    Graphics.FONT_XTINY,
                    contentWidth
                ),
                Graphics.TEXT_JUSTIFY_CENTER
            );
            return;
        }

        dc.setColor(Graphics.COLOR_WHITE, -1);
        dc.drawText(
            w / 2,
            y + rowH,
            Graphics.FONT_XTINY,
            fitTextToWidth(
                dc,
                _sVolume + ": " + volStr,
                Graphics.FONT_XTINY,
                contentWidth
            ),
            Graphics.TEXT_JUSTIFY_CENTER
        );

        dc.setColor(CLR_ACCENT, -1);
        dc.drawText(
            w / 2,
            y + rowH * 2,
            Graphics.FONT_XTINY,
            fitTextToWidth(
                dc,
                _sStreak + ": " + streak.toString(),
                Graphics.FONT_XTINY,
                contentWidth
            ),
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    function drawExerciseStat(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        y as Number,
        exIdx as Number
    ) as Void {
        var displayName = _displayNames[exIdx];
        var dataRowOffset = getStatsDataOffset(h);
        var historyOffset = getStatsHistoryOffset(h);
        var maxWidth = getContentWidth(w);

        var rm = _rmValues[exIdx];
        var watt = _wattValues[exIdx];
        var statLine = buildStatLine(rm, watt);

        dc.setColor(CLR_HIGHLIGHT, -1);
        dc.drawText(
            w / 2,
            y,
            Graphics.FONT_XTINY,
            fitTextToWidth(dc, displayName, Graphics.FONT_XTINY, maxWidth),
            Graphics.TEXT_JUSTIFY_CENTER
        );

        if (statLine.length() > 0) {
            dc.setColor(Graphics.COLOR_WHITE, -1);
            dc.drawText(
                w / 2,
                y + dataRowOffset,
                Graphics.FONT_XTINY,
                fitTextToWidth(dc, statLine, Graphics.FONT_XTINY, maxWidth),
                Graphics.TEXT_JUSTIFY_CENTER
            );
        }

        if (_filterMode == FILTER_WATT || !_showHistory) {
            return;
        }

        var histLine = _historyLines[exIdx];
        if (histLine.length() > 0) {
            dc.setColor(CLR_POSITIVE, -1);
            dc.drawText(
                w / 2,
                y + historyOffset,
                Graphics.FONT_XTINY,
                fitTextToWidth(dc, histLine, Graphics.FONT_XTINY, maxWidth),
                Graphics.TEXT_JUSTIFY_CENTER
            );
        }
    }

    function buildHistoryLine(cleanName as String) as String {
        try {
            var key = EGYMKeys.RM_HISTORY_PREFIX + cleanName;
            var history = EGYMSafeStore.getStorageValue(key);
            if (history == null || !(history instanceof Array)) {
                return "";
            }

            var arr = history as Array;
            if (arr.size() < 4 || arr.size() % 2 != 0) {
                return "";
            }

            var line = "";
            var firstVal = 0;
            var lastVal = 0;

            for (var i = 0; i + 1 < arr.size(); i += 2) {
                var val = EGYMSafeStore.toNumber(arr[i + 1], 0);
                if (i == 0) {
                    firstVal = val;
                }
                lastVal = val;

                if (line.length() > 0) {
                    line += ">";
                }
                line += val.toString();
            }

            var diff = lastVal - firstVal;
            if (diff > 0) {
                line += " +" + diff.toString();
            } else if (diff < 0) {
                line += " " + diff.toString();
            }

            return line;
        } catch (e) {
            logStatsIssue("RM history read failed for " + cleanName);
        }
        return "";
    }

    private function logStatsIssue(message as String) as Void {
        try {
            System.println("[EGYM stats] " + message);
        } catch (ignored) {
            // Logging must never affect stats rendering.
        }
    }

    function drawScrollIndicators(
        dc as Graphics.Dc,
        w as Number,
        h as Number
    ) as Void {
        var cx = w / 2;
        var iy = getStatsScrollIndicatorY(h);
        var triSize = getStatsTriangleSize(h);
        var gap = getStatsTriangleGap(h);

        _upTriPoints[0][0] = cx - triSize;
        _upTriPoints[0][1] = iy;
        _upTriPoints[1][0] = cx + triSize;
        _upTriPoints[1][1] = iy;
        _upTriPoints[2][0] = cx;
        _upTriPoints[2][1] = iy - triSize;

        _downTriPoints[0][0] = cx - triSize;
        _downTriPoints[0][1] = iy + gap;
        _downTriPoints[1][0] = cx + triSize;
        _downTriPoints[1][1] = iy + gap;
        _downTriPoints[2][0] = cx;
        _downTriPoints[2][1] = iy + gap + triSize;

        dc.setColor(CLR_DIM, -1);
        dc.fillPolygon(_upTriPoints);
        dc.fillPolygon(_downTriPoints);
    }

    function loadStat(key as String) as Number {
        var storedNum = EGYMSafeStore.getStorageNumber(key, -1);
        if (storedNum >= 0) {
            return storedNum;
        }
        var propNum = EGYMSafeStore.getPropertyNumber(key, -1);
        if (propNum >= 0) {
            return propNum;
        }
        return 0;
    }

    function compareStrings(str1 as String, str2 as String) as Number {
        return EGYMSafeStore.compareStrings(str1, str2);
    }

    private function loadStrings() as Void {
        if (_stringsLoaded) {
            return;
        }

        _stringsLoaded = true;
        _sTitle = WatchUi.loadResource(Rez.Strings.UIStatsTitle) as String;
        _sSessions = WatchUi.loadResource(Rez.Strings.UIStatsSessions) as String;
        _sVolume = WatchUi.loadResource(Rez.Strings.UIStatsVolume) as String;
        _sStreak = WatchUi.loadResource(Rez.Strings.UIStatsStreak) as String;
        _sNoData = WatchUi.loadResource(Rez.Strings.UIStatsNoData) as String;
        _sFilter = WatchUi.loadResource(Rez.Strings.UIStatsFilter) as String;
        _sFilterAll = WatchUi.loadResource(Rez.Strings.UIStatsFilterAll) as String;
        _sFilterRm = WatchUi.loadResource(Rez.Strings.UIStatsFilterRm) as String;
        _sFilterWatt = WatchUi.loadResource(Rez.Strings.UIStatsFilterWatt) as String;
    }

    private function reloadStats() as Void {
        refreshSummaryStats();
        refreshCatalogStats();
        if (_showHistory && _filterMode != FILTER_WATT) {
            ensureHistoryLoaded();
        }
        applyFilterFromCatalog();
    }

    private function refreshSummaryStats() as Void {
        _summarySessions = loadStat(EGYMKeys.STAT_SESSIONS);
        _summaryVolume = loadStat(EGYMKeys.STAT_TOTAL_VOLUME);
        _summaryStreak = loadStat(EGYMKeys.STAT_STREAK);
    }

    private function refreshCatalogStats() as Void {
        ensureCatalog();

        _catalogRmValues = [] as Array<Number>;
        _catalogWattValues = [] as Array<Number>;
        _catalogHistoryLines = [] as Array<String>;
        _historyLoaded = false;

        for (var i = 0; i < _catalogCleanNames.size(); i++) {
            var clean = _catalogCleanNames[i];
            _catalogRmValues.add(loadStat(EGYMKeys.RM_PREFIX + clean));
            _catalogWattValues.add(loadStat(EGYMKeys.WATT_PREFIX + clean));
            _catalogHistoryLines.add("");
        }
    }

    private function applyFilterFromCatalog() as Void {
        _exercises = [] as Array<String>;
        _cleanNames = [] as Array<String>;
        _displayNames = [] as Array<String>;
        _rmValues = [] as Array<Number>;
        _wattValues = [] as Array<Number>;
        _historyLines = [] as Array<String>;

        for (var i = 0; i < _catalogExercises.size(); i++) {
            var rm = _catalogRmValues[i];
            var watt = _catalogWattValues[i];

            if (!matchesFilter(rm, watt)) {
                continue;
            }

            _exercises.add(_catalogExercises[i]);
            _cleanNames.add(_catalogCleanNames[i]);
            _displayNames.add(_catalogDisplayNames[i]);
            _rmValues.add(rm);
            _wattValues.add(watt);
            _historyLines.add(_catalogHistoryLines[i]);
        }

        _visibleCount = _exercises.size() + 1;
        _scrollIndex = 0;
    }
    private function ensureHistoryLoaded() as Void {
        if (_historyLoaded || !_showHistory || _filterMode == FILTER_WATT) {
            return;
        }

        for (var i = 0; i < _catalogCleanNames.size(); i++) {
            _catalogHistoryLines[i] = buildHistoryLine(_catalogCleanNames[i]);
        }

        _historyLoaded = true;
    }

    private function ensureCatalog() as Void {
        if (_catalogReady) {
            return;
        }

        _catalogExercises = [] as Array<String>;
        _catalogCleanNames = [] as Array<String>;
        _catalogDisplayNames = [] as Array<String>;

        var allEx = EGYMConfig.getAllExercises();
        var cleaned = EGYMConfig.getCleanedExerciseNames();
        var appBase = Application.getApp();
        var app = appBase instanceof EGYMApp ? appBase as EGYMApp : null;

        for (var i = 0; i < allEx.size(); i++) {
            var ex = allEx[i];
            var clean = i < cleaned.size() ? cleaned[i] : ex;
            var display = (app != null) ? app.getExName(ex) : ex;
            insertCatalogEntry(ex, clean, display);
        }

        _catalogReady = true;
    }

    private function insertCatalogEntry(
        ex as String,
        clean as String,
        display as String
    ) as Void {
        var insertAt = _catalogDisplayNames.size();
        var lowered = display.toLower();
        while (insertAt > 0) {
            var prevName = _catalogDisplayNames[insertAt - 1].toLower();
            if (compareStrings(prevName, lowered) <= 0) {
                break;
            }
            insertAt -= 1;
        }

        _catalogExercises.add(ex);
        _catalogCleanNames.add(clean);
        _catalogDisplayNames.add(display);

        for (var i = _catalogDisplayNames.size() - 1; i > insertAt; i--) {
            swapCatalogEntry(i, i - 1);
        }
    }

    private function getMaxScrollIndex() as Number {
        var maxScroll = _visibleCount - _itemsPerPage;
        if (maxScroll < 0) {
            return 0;
        }
        return maxScroll;
    }

    private function matchesFilter(rm as Number, watt as Number) as Boolean {
        if (_filterMode == FILTER_RM) {
            return rm > 0;
        }
        if (_filterMode == FILTER_WATT) {
            return watt > 0;
        }
        return rm > 0 || watt > 0;
    }

    private function getFilterLabel() as String {
        if (_filterMode == FILTER_RM) {
            return _sFilterRm;
        }
        if (_filterMode == FILTER_WATT) {
            return _sFilterWatt;
        }
        return _sFilterAll;
    }

    private function buildStatLine(rm as Number, watt as Number) as String {
        if (_filterMode == FILTER_RM) {
            return rm > 0 ? "RM:" + rm.toString() + "kg" : "";
        }
        if (_filterMode == FILTER_WATT) {
            return watt > 0 ? watt.toString() + "W" : "";
        }
        if (_isNarrowRect) {
            if (rm > 0) {
                return "RM:" + rm.toString() + "kg";
            }
            return watt > 0 ? watt.toString() + "W" : "";
        }

        var statLine = "";
        if (rm > 0) {
            statLine = "RM:" + rm.toString() + "kg";
        }
        if (watt > 0) {
            if (statLine.length() > 0) {
                statLine += " | ";
            }
            statLine += watt.toString() + "W";
        }
        return statLine;
    }

    private function swapCatalogEntry(a as Number, b as Number) as Void {
        var ex = _catalogExercises[a];
        _catalogExercises[a] = _catalogExercises[b];
        _catalogExercises[b] = ex;

        var clean = _catalogCleanNames[a];
        _catalogCleanNames[a] = _catalogCleanNames[b];
        _catalogCleanNames[b] = clean;

        var display = _catalogDisplayNames[a];
        _catalogDisplayNames[a] = _catalogDisplayNames[b];
        _catalogDisplayNames[b] = display;
    }

    private function getStatsMaxItems(w as Number, h as Number, isNarrowRect as Boolean) as Number {
        if (!isNarrowRect) {
            return 5;
        }
        return h >= 390 ? 3 : 2;
    }

    private function getStatsTitleY(h as Number) as Number {
        return (h * getHeightProfileValue(h, [
            0.07, 0.072, 0.074, 0.076, 0.078, 0.08, 0.082,
            0.084, 0.086, 0.088, 0.09, 0.092, 0.094
        ])).toNumber();
    }

    private function getStatsFilterY(h as Number) as Number {
        return (h * getHeightProfileValue(h, [
            0.14, 0.142, 0.144, 0.146, 0.148, 0.15, 0.152,
            0.154, 0.156, 0.158, 0.16, 0.162, 0.164
        ])).toNumber();
    }

    private function getStatsContentTopY(h as Number) as Number {
        return (h * getHeightProfileValue(h, [
            0.215, 0.218, 0.22, 0.222, 0.224, 0.226, 0.228,
            0.23, 0.232, 0.235, 0.238, 0.24, 0.243
        ])).toNumber();
    }

    private function getStatsCompactContentTopY(h as Number) as Number {
        if (_isNarrowRect) {
            return (h * getHeightProfileValue(h, [
                0.21, 0.212, 0.214, 0.216, 0.218, 0.22, 0.222,
                0.226, 0.23, 0.234, 0.238, 0.242, 0.246
            ])).toNumber();
        }
        return (h * getHeightProfileValue(h, [
            0.16, 0.162, 0.164, 0.166, 0.168, 0.17, 0.172,
            0.176, 0.18, 0.184, 0.188, 0.192, 0.196
        ])).toNumber();
    }

    private function getStatsContentBottomY(h as Number) as Number {
        return (h * getHeightProfileValue(h, [
            0.84, 0.845, 0.85, 0.855, 0.858, 0.862, 0.866,
            0.87, 0.874, 0.878, 0.882, 0.886, 0.89
        ])).toNumber();
    }

    private function getStatsEmptyY(h as Number) as Number {
        return (h * getHeightProfileValue(h, [
            0.48, 0.485, 0.49, 0.495, 0.498, 0.5, 0.502,
            0.505, 0.508, 0.51, 0.512, 0.515, 0.518
        ])).toNumber();
    }

    private function getStatsLineHeight(h as Number) as Number {
        if (!_showHistory) {
            if (_isNarrowRect) {
                return getHeightProfileValue(h, [
                    32, 34, 36, 38, 40, 42, 44,
                    48, 54, 58, 62, 66, 70
                ]);
            }
            return getHeightProfileValue(h, [
                18, 20, 22, 24, 26, 28, 30,
                34, 40, 44, 48, 52, 56
            ]);
        }
        return getHeightProfileValue(h, [
            24, 26, 28, 32, 34, 38, 42,
            50, 60, 66, 72, 78, 84
        ]);
    }

    private function getStatsSummaryRowHeight(h as Number) as Number {
        if (!_showHistory) {
            if (_isNarrowRect) {
                return getHeightProfileValue(h, [
                    14, 15, 16, 17, 18, 19, 20,
                    21, 23, 25, 27, 29, 31
                ]);
            }
            return getHeightProfileValue(h, [
                9, 10, 11, 12, 13, 14, 15,
                16, 18, 20, 22, 24, 26
            ]);
        }
        return getHeightProfileValue(h, [
            9, 10, 11, 12, 13, 14, 15,
            18, 20, 22, 24, 26, 28
        ]);
    }

    private function getStatsSummaryHeight(h as Number) as Number {
        if (!_showHistory) {
            var compactGap = getHeightProfileValue(h, [
                4, 4, 4, 5, 5, 6, 6,
                7, 8, 9, 10, 11, 12
            ]);
            if (_isNarrowRect) {
                compactGap = getHeightProfileValue(h, [
                    10, 10, 10, 11, 11, 12, 12,
                    13, 14, 15, 16, 17, 18
                ]);
            }
            return (getStatsSummaryRowHeight(h) * 2) + compactGap;
        }
        return (getStatsSummaryRowHeight(h) * 3) + getHeightProfileValue(h, [
            4, 4, 4, 5, 5, 6, 6,
            7, 8, 9, 10, 11, 12
        ]);
    }

    private function getStatsDataOffset(h as Number) as Number {
        if (!_showHistory) {
            if (_isNarrowRect) {
                return getHeightProfileValue(h, [
                    14, 15, 16, 17, 18, 19, 20,
                    21, 23, 25, 27, 29, 31
                ]);
            }
            return getHeightProfileValue(h, [
                7, 8, 9, 10, 11, 12, 13,
                14, 16, 18, 20, 22, 24
            ]);
        }
        return getHeightProfileValue(h, [
            8, 9, 10, 11, 12, 13, 14,
            16, 18, 21, 24, 27, 30
        ]);
    }

    private function getStatsHistoryOffset(h as Number) as Number {
        if (!_showHistory) {
            return 0;
        }
        return getHeightProfileValue(h, [
            16, 18, 20, 22, 24, 26, 28,
            32, 36, 42, 48, 54, 60
        ]);
    }

    private function getStatsScrollIndicatorY(h as Number) as Number {
        return (h * getHeightProfileValue(h, [
            0.90, 0.905, 0.91, 0.915, 0.918, 0.92, 0.922,
            0.924, 0.926, 0.928, 0.93, 0.932, 0.934
        ])).toNumber();
    }

    private function getStatsTriangleSize(h as Number) as Number {
        return getHeightProfileValue(h, [
            3, 3, 3, 4, 4, 4, 5,
            5, 6, 6, 7, 7, 8
        ]);
    }

    private function getStatsTriangleGap(h as Number) as Number {
        return getHeightProfileValue(h, [
            2, 2, 2, 2, 2, 3, 3,
            3, 4, 4, 4, 4, 5
        ]);
    }

    private function fitTextToWidth(
        dc as Graphics.Dc,
        text as String,
        font as Graphics.FontType,
        maxWidth as Number
    ) as String {
        if (text.length() == 0 || dc.getTextWidthInPixels(text, font) <= maxWidth) {
            return text;
        }

        var ellipsis = "...";
        var ellipsisWidth = dc.getTextWidthInPixels(ellipsis, font);
        if (ellipsisWidth >= maxWidth) {
            return "";
        }

        // Binary search for the longest prefix that fits within maxWidth - ellipsisWidth.
        var budget = maxWidth - ellipsisWidth;
        var lo = 0;
        var hi = text.length();
        while (lo < hi) {
            var mid = (lo + hi + 1) / 2;
            if (dc.getTextWidthInPixels(text.substring(0, mid), font) <= budget) {
                lo = mid;
            } else {
                hi = mid - 1;
            }
        }
        return lo > 0 ? text.substring(0, lo) + ellipsis : ellipsis;
    }

    private function getContentWidth(w as Number) as Number {
        var inset = getWidthProfileValue(w, [
            10, 10, 10, 12, 12, 14, 14,
            16, 14, 16, 18, 20, 22, 24
        ]);
        var width = w - (inset * 2);
        return width > 0 ? width : w;
    }

    private function isNarrowRectStatsLayout(w as Number, h as Number) as Boolean {
        return w <= 320 && h >= 320;
    }

    private function isCompactStatsLayout(w as Number, h as Number) as Boolean {
        return w <= 208 || h <= 208 || (w <= 320 && h >= 320);
    }

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
        return values[idx];
    }
}









