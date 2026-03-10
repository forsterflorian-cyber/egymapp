import Toybox.Lang;

class EGYMBuildProfile {

    (:low_mem)
    public static function isInstinctLowMemoryBuild() as Boolean {
        return true;
    }

    (:high_res)
    public static function isInstinctLowMemoryBuild() as Boolean {
        return false;
    }

    (:low_mem)
    public static function useSystemFontsOnly() as Boolean {
        return true;
    }

    (:high_res)
    public static function useSystemFontsOnly() as Boolean {
        return false;
    }

    (:low_mem)
    public static function getMenuItemOptions() as Dictionary {
        return { :icon => null };
    }

    (:high_res)
    public static function getMenuItemOptions() as Dictionary {
        return {} as Dictionary;
    }

    (:low_mem)
    public static function getMaxStoredExercises() as Number {
        return 10;
    }

    (:high_res)
    public static function getMaxStoredExercises() as Number {
        return 999;
    }

    (:low_mem)
    public static function getMaxSessionRecords() as Number {
        return 10;
    }

    (:high_res)
    public static function getMaxSessionRecords() as Number {
        return 999;
    }

    (:low_mem)
    public static function getMaxRmHistorySlots() as Number {
        return 4;
    }

    (:high_res)
    public static function getMaxRmHistorySlots() as Number {
        return 10;
    }
}
