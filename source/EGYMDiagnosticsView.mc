import Toybox.Application;
import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.StringUtil;

class EGYMDiagnosticsView extends WatchUi.View {
    private var _stringsLoaded as Boolean = false;

    private var _sTitle as String = "";
    private var _sSchema as String = "";
    private var _sProgram as String = "";
    private var _sCircle as String = "";
    private var _sPropIo as String = "";
    private var _sStorageIo as String = "";
    private var _sResetHint as String = "";

    private var _schemaLine as String = "";
    private var _programLine as String = "";
    private var _circleLine as String = "";
    private var _propLine as String = "";
    private var _storageLine as String = "";

    function initialize() {
        View.initialize();
    }

    function onShow() as Void {
        loadStrings();
        refreshData();
    }

    function resetCounters() as Void {
        EGYMSafeStore.resetErrorCounters();
        refreshData();
        WatchUi.requestUpdate();
    }

    function refreshData() as Void {
        var app = Application.getApp() as EGYMApp;
        app.refreshRuntimeSnapshots();
        var schema = app.getCachedStorageSchema();
        var counters = EGYMSafeStore.getErrorCounters();
        var propReads = counters["propertyReadErrors"] as Number;
        var propWrites = counters["propertyWriteErrors"] as Number;
        var storageReads = counters["storageReadErrors"] as Number;
        var storageWrites = counters["storageWriteErrors"] as Number;

        _schemaLine = _sSchema + ": " + schema.toString();
        _programLine = _sProgram + ": " + app.getCachedMenuProgramSub();
        _circleLine = _sCircle + ": " + app.getCachedMenuCircleSub();
        _propLine = _sPropIo + ": " + propReads.toString() + "/" + propWrites.toString();
        _storageLine = _sStorageIo + ": " + storageReads.toString() + "/" + storageWrites.toString();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var inset = getContentInset(w);
        var fontH = dc.getFontHeight(Graphics.FONT_XTINY);
        var titleY = getDiagnosticTitleY(h);
        var y = titleY + getDiagnosticSectionGap(h, fontH);
        var lineGap = getDiagnosticLineGap(h, fontH);

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(0xffaa00, -1);
        dc.drawText(
            w / 2,
            titleY,
            Graphics.FONT_XTINY,
            fitTextToWidth(dc, _sTitle, Graphics.FONT_XTINY, w - (inset * 2)),
            Graphics.TEXT_JUSTIFY_CENTER
        );

        drawLine(dc, w, y, _schemaLine, 0x00ff00);

        y += lineGap;
        drawLine(dc, w, y, _programLine, Graphics.COLOR_WHITE);

        y += lineGap;
        drawLine(dc, w, y, _circleLine, Graphics.COLOR_WHITE);

        y += lineGap;
        drawLine(dc, w, y, _propLine, 0x00aaff);

        y += lineGap;
        drawLine(dc, w, y, _storageLine, 0x00aaff);

        var footerY = y + lineGap;
        var minFooterY = y + fontH + getDiagnosticFooterGap(h);
        if (footerY < minFooterY) {
            footerY = minFooterY;
        }
        var maxFooterY = getDiagnosticFooterY(h);
        if (footerY > maxFooterY) {
            footerY = maxFooterY;
        }

        dc.setColor(0x555555, -1);
        dc.drawText(
            w / 2,
            footerY,
            Graphics.FONT_XTINY,
            fitTextToWidth(dc, _sResetHint, Graphics.FONT_XTINY, w - (inset * 2)),
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    private function loadStrings() as Void {
        if (_stringsLoaded) {
            return;
        }

        _stringsLoaded = true;
        _sTitle = WatchUi.loadResource(Rez.Strings.UIDiagnosticsTitle) as String;
        _sSchema = WatchUi.loadResource(Rez.Strings.UIDiagnosticsSchema) as String;
        _sProgram = WatchUi.loadResource(Rez.Strings.UIDiagnosticsProgram) as String;
        _sCircle = WatchUi.loadResource(Rez.Strings.UIDiagnosticsCircle) as String;
        _sPropIo = WatchUi.loadResource(Rez.Strings.UIDiagnosticsPropIo) as String;
        _sStorageIo = WatchUi.loadResource(Rez.Strings.UIDiagnosticsStorageIo) as String;
        _sResetHint = WatchUi.loadResource(Rez.Strings.UIDiagnosticsResetHint) as String;
    }

    private function drawLine(
        dc as Graphics.Dc,
        w as Number,
        y as Number,
        text as String,
        fg as Number
    ) as Void {
        var flatText = normalizeLineText(text);
        var lineWidth = getDiagnosticLineWidth(w);
        dc.setColor(fg, -1);
        dc.drawText(
            w / 2,
            y,
            Graphics.FONT_XTINY,
            fitTextToWidth(dc, flatText, Graphics.FONT_XTINY, lineWidth),
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    private function normalizeLineText(text as String) as String {
        if (text.length() == 0) {
            return text;
        }

        var chars = text.toCharArray();
        var out = [] as Array<Char>;
        var lastWasBreak = false;

        for (var i = 0; i < chars.size(); i++) {
            var ch = chars[i];
            if (ch == 0x0A || ch == 0x0D) {
                if (!lastWasBreak && out.size() > 0) {
                    out.add(' ');
                }
                lastWasBreak = true;
                continue;
            }
            out.add(ch);
            lastWasBreak = false;
        }

        return out.size() > 0 ? StringUtil.charArrayToString(out) : "";
    }

    private function fitTextToWidth(
        dc as Graphics.Dc,
        text as String,
        font as Graphics.FontType,
        maxWidth as Number
    ) as String {
        if (dc.getTextWidthInPixels(text, font) <= maxWidth) {
            return text;
        }

        var ellipsis = "...";
        var limit = maxWidth - dc.getTextWidthInPixels(ellipsis, font);
        if (limit <= 0) {
            return "";
        }

        var out = "";
        for (var i = 0; i < text.length(); i++) {
            var next = out + text.substring(i, i + 1);
            if (dc.getTextWidthInPixels(next, font) > limit) {
                break;
            }
            out = next;
        }
        return out + ellipsis;
    }

    private function getContentInset(w as Number) as Number {
        return getWidthProfileValue(w, [
            10, 10, 10, 12, 12, 14, 14,
            16, 16, 18, 20, 22, 24, 24
        ]);
    }

    private function getDiagnosticLineWidth(w as Number) as Number {
        var inset = getWidthProfileValue(w, [
            20, 20, 20, 24, 26, 30, 32,
            36, 42, 48, 54, 60, 66, 72
        ]);
        var width = w - (inset * 2);
        return width > 0 ? width : w;
    }

    private function getDiagnosticTitleY(h as Number) as Number {
        return (h * getHeightProfileValue(h, [
            0.10, 0.102, 0.105, 0.108, 0.11, 0.112, 0.115,
            0.118, 0.122, 0.126, 0.13, 0.133, 0.136
        ])).toNumber();
    }

    private function getDiagnosticSectionGap(h as Number, fontH as Number) as Number {
        return fontH + getHeightProfileValue(h, [
            2, 2, 2, 3, 3, 4, 4,
            5, 6, 7, 8, 9, 10
        ]);
    }

    private function getDiagnosticLineGap(h as Number, fontH as Number) as Number {
        return fontH + getHeightProfileValue(h, [
            1, 1, 2, 2, 3, 3, 4,
            5, 6, 7, 8, 9, 10
        ]);
    }

    private function getDiagnosticFooterGap(h as Number) as Number {
        return getHeightProfileValue(h, [
            6, 6, 7, 8, 9, 10, 11,
            12, 14, 16, 18, 20, 22
        ]);
    }

    private function getDiagnosticFooterY(h as Number) as Number {
        return (h * getHeightProfileValue(h, [
            0.81, 0.815, 0.82, 0.825, 0.83, 0.835, 0.84,
            0.845, 0.85, 0.855, 0.86, 0.865, 0.87
        ])).toNumber();
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

