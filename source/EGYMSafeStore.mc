import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Lang;
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
    static function getPropertyValue(key as String) {
        try {
            return Application.Properties.getValue(key);
        } catch (e) {
            _propertyReadErrors += 1;
        }
        return null;
    }

    static function setPropertyValue(key as String, value) as Boolean {
        try {
            Application.Properties.setValue(key, value);
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

    static function setStorageValue(key as String, value) as Boolean {
        try {
            Storage.setValue(key, value);
            return true;
        } catch (e) {
            _storageWriteErrors += 1;
        }
        return false;
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

    // Typed convenience helpers with caller-provided fallbacks.
    static function getPropertyBool(key as String, fallback as Boolean) as Boolean {
        return toBool(getPropertyValue(key), fallback);
    }

    static function getStorageBool(key as String, fallback as Boolean) as Boolean {
        return toBool(getStorageValue(key), fallback);
    }

    static function getPropertyNumber(key as String, fallback as Number) as Number {
        return toNumber(getPropertyValue(key), fallback);
    }

    static function getStorageNumber(key as String, fallback as Number) as Number {
        return toNumber(getStorageValue(key), fallback);
    }

    static function getPropertyString(key as String, fallback as String) as String {
        return toStringValue(getPropertyValue(key), fallback);
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
        return value.toString();
    }
}
