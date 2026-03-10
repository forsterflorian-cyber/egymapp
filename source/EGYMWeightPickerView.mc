import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;

class EGYMWeightPickerView extends WatchUi.View {
    
    private var _displayName as String;
    private var _weight as Number;

    private const MAX_WEIGHT = 999;
    private const WEIGHT_STEP = 1;

    private var _sTitle as String = "";
    private var _sChange as String = "";
    private var _sConfirm as String = "";

    // Cached layout values
    private var _screenW as Number = 0;
    private var _screenH as Number = 0;
    private var _titleY as Number = 0;
    private var _nameY as Number = 0;
    private var _weightY as Number = 0;
    private var _hintY1 as Number = 0;
    private var _hintY2 as Number = 0;
    private var _layoutDirty as Boolean = true;

    // Rendering performance caches
    private var _kgWidth as Number = 0;
    private var _lastWeightWidth as Number = 0;
    private var _lastWeightStr as String = "";

    function initialize(
        displayName as String,
        currentRM as Number
    ) {
        View.initialize();
        _displayName = displayName;
        _weight = currentRM;
    }

    (:low_mem)
    function onShow() as Void {
        _sTitle = EGYMInstinctText.getWeightPickerTitle();
        _sChange = EGYMInstinctText.getWeightPickerChange();
        _sConfirm = EGYMInstinctText.getWeightPickerConfirm();
        _layoutDirty = true;
    }

    (:high_res)
    function onShow() as Void {
        _sTitle = WatchUi.loadResource(Rez.Strings.UIStrengthTest) as String;
        _sChange = WatchUi.loadResource(Rez.Strings.UIPickerChange) as String;
        _sConfirm = WatchUi.loadResource(Rez.Strings.UIPickerConfirm) as String;
        _layoutDirty = true;
    }

    function release() as Void {
        _displayName = "";
        _sTitle = "";
        _sChange = "";
        _sConfirm = "";
        _lastWeightStr = "";
        _lastWeightWidth = 0;
        _kgWidth = 0;
        _layoutDirty = true;
    }

    function changeWeight(delta as Number) as Void {
        _weight += delta * WEIGHT_STEP;
        if (_weight < 0) {
            _weight = 0;
        } else if (_weight > MAX_WEIGHT) {
            _weight = MAX_WEIGHT;
        }
        WatchUi.requestUpdate();
    }

    function getWeight() as Number {
        return _weight;
    }

    function onUpdate(dc as Graphics.Dc) as Void  {
        var isInstinct = EGYMBuildProfile.isInstinctLowMemoryBuild();
        var titleFont = isInstinct ? Graphics.FONT_TINY : Graphics.FONT_XTINY;
        var nameFont = isInstinct ? Graphics.FONT_TINY : Graphics.FONT_SMALL;
        var weightFont = isInstinct ? Graphics.FONT_MEDIUM : Graphics.FONT_NUMBER_MEDIUM;
        var unitFont = isInstinct ? Graphics.FONT_TINY : Graphics.FONT_SMALL;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();

        // Recalculate layout and static widths only when necessary
        if (_layoutDirty || _screenW != w || _screenH != h) {
            _screenW = w;
            _screenH = h;
            _titleY = (h * 0.22).toNumber();
            _nameY = (h * 0.32).toNumber();
            _weightY = (h * 0.53).toNumber();
            _hintY1 = (h * 0.72).toNumber();
            _hintY2 = (h * 0.80).toNumber();
            
            _kgWidth = dc.getTextWidthInPixels(" kg", unitFont);
            _layoutDirty = false;
        }

        // --- 1. Title ---
        dc.setColor(Graphics.COLOR_WHITE, -1);
        dc.drawText(w / 2, _titleY, titleFont, _sTitle, Graphics.TEXT_JUSTIFY_CENTER);

        // --- 2. Exercise name ---
        dc.setColor(Graphics.COLOR_WHITE, -1);
        dc.drawText(w / 2, _nameY, nameFont, _displayName, Graphics.TEXT_JUSTIFY_CENTER);

        // --- 3. Weight Number + Suffix ---
        var weightStr = _weight.toString();
        
        // Only measure width if the string changed
        if (!weightStr.equals(_lastWeightStr)) {
            _lastWeightStr = weightStr;
            _lastWeightWidth = dc.getTextWidthInPixels(weightStr, weightFont);
        }
        
        var gap = 4;
        var startX = (w - (_lastWeightWidth + gap + _kgWidth)) / 2;

        dc.setColor(Graphics.COLOR_WHITE, -1);
        dc.drawText(startX, _weightY, weightFont, weightStr,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        
        dc.setColor(Graphics.COLOR_WHITE, -1);
        dc.drawText(startX + _lastWeightWidth + gap, _weightY, unitFont, " kg",
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // --- 4. Interaction Hints ---
        dc.setColor(Graphics.COLOR_WHITE, -1);
        dc.drawText(w / 2, _hintY1, titleFont, _sChange, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w / 2, _hintY2, titleFont, _sConfirm, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
