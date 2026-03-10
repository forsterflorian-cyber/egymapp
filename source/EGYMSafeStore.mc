import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.StringUtil;
import Toybox.System;

// ============================================================
// EGYMSafeStore -- Centralized safe read/write access for
// Application.Properties and Storage.
// ============================================================

class EGYMSafeStore {
    // Runtime telemetry: exception counters for storage/property access.
    private static var _propertyReadErrors as Number = 0;
    private static var _propertyWriteErrors as Number = 0;
    private static var _storageReadErrors as Number = 0;
    private static var _storageWriteErrors as Number = 0;

    // Raw accessors: never throw, always return null/false on failure.
    // Intentionally returns an untyped raw value so corrupt settings payloads
    // cannot force type assumptions at the call site.
    static function getPropertyValue(key) {
        if (key == null) {
            return null;
        }
        var safeKeyStr = key.toString();
        try {
            var app = Application.getApp();
            var rawValue = app.getProperty(safeKeyStr);
            return rawValue;
        } catch (e) {
            _propertyReadErrors += 1;
        }
        return null;
    }

    static function setPropertyValue(key, value) as Boolean {
        if (key == null) {
            return false;
        }
        var safeKeyStr = key.toString();
        try {
            var app = Application.getApp();
            app.setProperty(safeKeyStr, value);
            return true;
        } catch (e) {
            _propertyWriteErrors += 1;
        }
        return false;
    }

    static function getStorageValue(key as String) {
        try {
            return Storage.getValue(key);
        } catch (e) {
            _storageReadErrors += 1;
        }
        return null;
    }

    (:low_mem)
    static function setStorageValue(key as String, value) as Boolean {
        try {
            Storage.setValue(key, value);
            return true;
        } catch (e) {
            _storageWriteErrors += 1;
        }
        return false;
    }

    (:high_res)
    static function setStorageValue(key as String, value) as Boolean {
        try {
            if (Storage.getValue(key) == value) {
                return true;
            }
            Storage.setValue(key, value);
            return true;
        } catch (e) {
            _storageWriteErrors += 1;
        }
        return false;
    }

    // Session checkpoint helpers
    (:low_mem)
    static function saveCheckpoint(data as Dictionary?) as Boolean {
        return true;
    }

    (:high_res)
    static function saveCheckpoint(data as Dictionary?) as Boolean {
        if (data == null) {
            return false;
        }
        var savedCheckpoint = setStorageValue(
            EGYMKeys.SESSION_CHECKPOINT,
            prepareCheckpointForStorage(data)
        );
        if (!savedCheckpoint) {
            return false;
        }
        return setStorageValue(
            EGYMKeys.SESSION_CHECKPOINT_PROFILE,
            getCheckpointProfileName()
        );
    }

    static function loadCheckpoint() as Dictionary? {
        var raw = getStorageValue(EGYMKeys.SESSION_CHECKPOINT);
        if (!(raw instanceof Dictionary)) {
            return null;
        }

        var checkpoint = raw as Dictionary;
        return isValidCheckpoint(checkpoint) ? checkpoint : null;
    }

    (:low_mem)
    static function loadCheckpointForCurrentProfile() as Dictionary? {
        clearCheckpoint();
        return null;
    }

    (:high_res)
    static function loadCheckpointForCurrentProfile() as Dictionary? {
        if (!shouldLoadCheckpointForCurrentProfile()) {
            clearCheckpoint();
            return null;
        }
        return loadCheckpoint();
    }

    static function clearCheckpoint() as Boolean {
        var clearedCheckpoint = deleteStorageValue(EGYMKeys.SESSION_CHECKPOINT);
        var clearedProfile = deleteStorageValue(EGYMKeys.SESSION_CHECKPOINT_PROFILE);
        return clearedCheckpoint && clearedProfile;
    }

    static function hasCheckpoint() as Boolean {
        return loadCheckpoint() != null;
    }

    (:low_mem)
    private static function prepareCheckpointForStorage(data as Dictionary) as Dictionary {
        var payload = {} as Dictionary;
        copyCheckpointField(payload, data, "version");
        copyCheckpointField(payload, data, "timestampMs");
        copyCheckpointField(payload, data, "phase");
        copyCheckpointField(payload, data, "index");
        copyCheckpointField(payload, data, "round");
        copyCheckpointField(payload, data, "activeProg");
        copyCheckpointField(payload, data, "setCount");
        copyCheckpointField(payload, data, "sessionTotalKg");
        copyCheckpointField(payload, data, "zirkel");
        copyCheckpointField(payload, data, "isIndividualMode");
        copyCheckpointField(payload, data, "isTestModeActive");
        copyCheckpointField(payload, data, "currentWeight");
        copyCheckpointField(payload, data, "qualityValue");
        copyCheckpointField(payload, data, "breakElapsedSec");
        return payload;
    }

    (:high_res)
    private static function prepareCheckpointForStorage(data as Dictionary) as Dictionary {
        return data;
    }

    (:low_mem)
    private static function shouldLoadCheckpointForCurrentProfile() as Boolean {
        return getCheckpointProfileMarker().equals(getCheckpointProfileName());
    }

    (:high_res)
    private static function shouldLoadCheckpointForCurrentProfile() as Boolean {
        var marker = getCheckpointProfileMarker();
        return marker.length() == 0 || marker.equals(getCheckpointProfileName());
    }

    (:low_mem)
    private static function getCheckpointProfileName() as String {
        return "instinct_low_mem";
    }

    (:high_res)
    private static function getCheckpointProfileName() as String {
        return "standard";
    }

    private static function copyCheckpointField(
        target as Dictionary,
        source as Dictionary,
        key as String
    ) as Void {
        if (!source.hasKey(key)) {
            return;
        }
        target[key] = source[key];
    }

    static function deleteStorageValue(key as String) as Boolean {
        try {
            Storage.deleteValue(key);
            return true;
        } catch (e) {
            _storageWriteErrors += 1;
        }
        return false;
    }

    static function resetErrorCounters() as Void {
        _propertyReadErrors = 0;
        _propertyWriteErrors = 0;
        _storageReadErrors = 0;
        _storageWriteErrors = 0;
    }

    static function getErrorCounters() as Dictionary<String, Number> {
        return {
            "propertyReadErrors" => _propertyReadErrors,
            "propertyWriteErrors" => _propertyWriteErrors,
            "storageReadErrors" => _storageReadErrors,
            "storageWriteErrors" => _storageWriteErrors
        };
    }

    private static function isValidCheckpoint(checkpoint as Dictionary) as Boolean {
        return checkpoint.hasKey("version") &&
            checkpoint.hasKey("phase") &&
            checkpoint.hasKey("index") &&
            checkpoint.hasKey("round") &&
            checkpoint.hasKey("setCount") &&
            checkpoint.hasKey("sessionTotalKg") &&
            checkpoint.hasKey("zirkel") &&
            checkpoint.hasKey("activeProg") &&
            checkpoint.hasKey("timestampMs");
    }

    // Typed convenience helpers with caller-provided fallbacks.
    static function getPropertyBool(key, fallback as Boolean) as Boolean {
        if (key == null) {
            return fallback;
        }
        var val = getPropertyValue(key);
        if (val == null) {
            return fallback;
        }
        if (val instanceof Lang.Boolean) {
            return val as Boolean;
        }
        if (val instanceof Lang.Number) {
            return (val as Number) != 0;
        }
        if (val instanceof Lang.String) {
            var lower = (val as String).toLower();
            if (lower.equals("true") || lower.equals("1") || lower.equals("yes") || lower.equals("on")) {
                return true;
            }
            if (lower.equals("false") || lower.equals("0") || lower.equals("no") || lower.equals("off")) {
                return false;
            }
        }
        return fallback;
    }

    static function getStorageBool(key as String, fallback as Boolean) as Boolean {
        return toBool(getStorageValue(key), fallback);
    }

    static function getPropertyNumber(key, fallback as Number) as Number {
        if (key == null) {
            return fallback;
        }
        var val = getPropertyValue(key);
        if (val == null) {
            return fallback;
        }
        if (val instanceof Lang.Number) {
            return val as Number;
        }
        if (val instanceof Lang.Boolean) {
            return (val as Boolean) ? 1 : 0;
        }
        if (val instanceof Lang.String) {
            var parsed = (val as String).toNumber();
            if (parsed != null) {
                return parsed;
            }
            return fallback;
        }
        if (val has :toNumber) {
            try {
                var converted = val.toNumber();
                if (converted != null && converted instanceof Lang.Number) {
                    return converted as Number;
                }
            } catch (e) {
                _propertyReadErrors += 1;
            }
        }
        return fallback;
    }

    static function getStorageNumber(key as String, fallback as Number) as Number {
        return toNumber(getStorageValue(key), fallback);
    }

    static function getPropertyString(key, fallback as String) as String {
        if (key == null) {
            return fallback;
        }
        var val = getPropertyValue(key);
        if (val == null) {
            return fallback;
        }
        if (val instanceof Lang.String) {
            return val as String;
        }
        if (val instanceof Lang.Boolean || val instanceof Lang.Number) {
            return val.toString();
        }
        if (val has :toString) {
            try {
                var converted = val.toString();
                if (converted != null && converted instanceof Lang.String) {
                    return converted as String;
                }
            } catch (e) {
                _propertyReadErrors += 1;
            }
        }
        return fallback;
    }

    static function getStorageString(key as String, fallback as String) as String {
        return toStringValue(getStorageValue(key), fallback);
    }

    static function getStorageStringArray(key as String) as Array<String>? {
        var raw = getStorageValue(key);
        if (raw == null || !(raw instanceof Lang.Array)) {
            return null;
        }

        var src = raw as Array;
        var result = [] as Array<String>;
        // Keep only non-empty string entries to guard against corrupt payloads.
        for (var i = 0; i < src.size(); i++) {
            if (src[i] instanceof Lang.String) {
                var str = src[i] as String;
                if (str.length() > 0) {
                    result.add(str);
                }
            }
        }
        return result;
    }

    static function getCheckpointProfileMarker() as String {
        return getStorageString(EGYMKeys.SESSION_CHECKPOINT_PROFILE, "");
    }

    // Coercion helpers used by both property and storage readers.
    static function toNumber(value, fallback as Number) as Number {
        if (value == null) {
            return fallback;
        }
        if (value instanceof Lang.Number) {
            return value as Number;
        }
        if (value instanceof Lang.String) {
            var parsed = (value as String).toNumber();
            if (parsed != null) {
                return parsed;
            }
        }
        // Handle Float/Double/Long-like numerics without hard type dependency.
        if (value has :toNumber) {
            try {
                var converted = value.toNumber();
                if (converted != null && converted instanceof Lang.Number) {
                    return converted as Number;
                }
            } catch (e) {
                System.println("[EGYM store] Numeric coercion failed; using fallback.");
            }
        }
        return fallback;
    }

    static function toBool(value, fallback as Boolean) as Boolean {
        if (value == null) {
            return fallback;
        }
        if (value instanceof Lang.Boolean) {
            return value as Boolean;
        }
        if (value instanceof Lang.Number) {
            return (value as Number) != 0;
        }
        // Accept common string switches from settings payloads.
        if (value instanceof Lang.String) {
            var lower = (value as String).toLower();
            if (lower.equals("true") || lower.equals("1") || lower.equals("yes") || lower.equals("on")) {
                return true;
            }
            if (lower.equals("false") || lower.equals("0") || lower.equals("no") || lower.equals("off")) {
                return false;
            }
        }
        return fallback;
    }

    static function toStringValue(value, fallback as String) as String {
        if (value == null) {
            return fallback;
        }
        if (value instanceof Lang.String) {
            return value as String;
        }
        if (value instanceof Lang.Boolean || value instanceof Lang.Number) {
            return value.toString();
        }
        if (value has :toString) {
            try {
                var converted = value.toString();
                if (converted != null && converted instanceof Lang.String) {
                    return converted as String;
                }
            } catch (e) {
                System.println("[EGYM store] String coercion failed; using fallback.");
            }
        }
        return fallback;
    }

    // ========================================================
    // SHARED STRING UTILITIES
    // ========================================================

    //! Replaces German umlauts with ASCII digraphs (ü→ue, ö→oe, ä→ae, ß→ss).
    //! All other characters are passed through unchanged.
    //! Used by EGYMApp (lookup keys), EGYMSessionManager (FIT strings),
    //! and EGYMConfig (storage key cleaning) to avoid duplicating this logic.
    static function applyUmlautSubstitution(str as String) as String {
        var chars = str.toCharArray();
        var out = [] as Array<Char>;
        for (var i = 0; i < chars.size(); i++) {
            var c = chars[i];
            if      (c == 0x00FC || c == 0x00DC) { out.add('u'); out.add('e'); }
            else if (c == 0x00F6 || c == 0x00D6) { out.add('o'); out.add('e'); }
            else if (c == 0x00E4 || c == 0x00C4) { out.add('a'); out.add('e'); }
            else if (c == 0x00DF)                { out.add('s'); out.add('s'); }
            else                                 { out.add(c); }
        }
        return out.size() > 0 ? StringUtil.charArrayToString(out) : "";
    }

    //! Trims leading and trailing ASCII space (0x20) and tab (0x09) characters.
    //! Accepts nullable input and returns "" for null or empty strings.
    static function trimWhitespace(str as String?) as String {
        if (str == null || str.length() == 0) { return ""; }
        var chars = str.toCharArray();
        var s = 0;
        var e = chars.size() - 1;
        while (s <= e && (chars[s] == 0x20 || chars[s] == 0x09)) { s++; }
        while (e >= s && (chars[e] == 0x20 || chars[e] == 0x09)) { e--; }
        if (s > e) { return ""; }
        return str.substring(s, e + 1);
    }

    //! Lexicographic string comparison without using String.compareTo(),
    //! which is unavailable on some older Garmin devices (e.g. fenix 5).
    //! Returns -1 if str1 < str2, 1 if str1 > str2, 0 if equal.
    static function compareStrings(str1 as String, str2 as String) as Number {
        var c1 = str1.toCharArray();
        var c2 = str2.toCharArray();
        var len = c1.size() < c2.size() ? c1.size() : c2.size();
        for (var i = 0; i < len; i++) {
            if (c1[i] < c2[i]) { return -1; }
            if (c1[i] > c2[i]) { return  1; }
        }
        if (c1.size() < c2.size()) { return -1; }
        if (c1.size() > c2.size()) { return  1; }
        return 0;
    }
}
