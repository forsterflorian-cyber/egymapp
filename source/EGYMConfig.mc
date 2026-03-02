import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Application;
import Toybox.StringUtil;

// ============================================================
// EGYMConfig - Static configuration for exercises, programs,
// and training circles. All exercise lists and program data
// are lazy-cached for memory efficiency.
// ============================================================

class EGYMConfig {

    // Lazy caches (populated on first access)
    private static var _allProgramsCache as Array<Dictionary>? = null;
    private static var _basicProgramsCache as Array<Dictionary>? = null;
    private static var _zirkelKraftCache as Array<String>? = null;
    private static var _zirkelBeineCache as Array<String>? = null;
    private static var _additionalExercisesCache as Array<String>? = null;
    private static var _allExercisesCache as Array<String>? = null;
    private static var _cleanedExercisesCache as Array<String>? = null;
    private static const PROGRAM_PREFIX_FALLBACK = "??";
    private static const PROGRAM_GOAL_FALLBACK = "GoalUnknown";
    private static const PROGRAM_METHOD_FALLBACK = "REGULAR";
    private static const PROGRAM_REPS_FALLBACK = "0";
    private static const PROGRAM_INTENSITY_FALLBACK = 0.0;

    // ========================================================
    // PROGRAM FIELD ACCESSORS
    // ========================================================

    private static function getProgramStringField(program as Dictionary, key as Symbol, fallback as String) as String {
        var raw = program[key];
        if (raw != null && raw instanceof Lang.String) {
            return raw as String;
        }
        return fallback;
    }

    static function getProgramPrefix(program as Dictionary) as String {
        return getProgramStringField(program, :p, PROGRAM_PREFIX_FALLBACK);
    }

    static function getProgramGoalKey(program as Dictionary) as String {
        return getProgramStringField(program, :g, PROGRAM_GOAL_FALLBACK);
    }

    static function getProgramMethodKey(program as Dictionary) as String {
        return getProgramStringField(program, :m, PROGRAM_METHOD_FALLBACK);
    }

    static function getProgramRepsSpec(program as Dictionary) as String {
        return getProgramStringField(program, :w, PROGRAM_REPS_FALLBACK);
    }

    static function getProgramIntensityFactor(program as Dictionary) as Numeric {
        var raw = program[:i];
        if (raw instanceof Lang.Number) {
            return (raw as Number).toFloat();
        }
        if (raw != null && raw has :toFloat) {
            try {
                return raw.toFloat();
            } catch (e) {
                System.println("[EGYM config] Invalid program intensity; using fallback.");
            }
        }
        if (raw instanceof Lang.String) {
            var parsed = (raw as String).toNumber();
            if (parsed != null) {
                return parsed.toFloat();
            }
        }
        return PROGRAM_INTENSITY_FALLBACK;
    }

    static function isExplosiveProgram(program as Dictionary) as Boolean {
        return getProgramMethodKey(program).equals("EXPLOSIVE");
    }

    private static function cloneProgramList(src as Array<Dictionary>?) as Array<Dictionary> {
        if (src == null) {
            return [] as Array<Dictionary>;
        }
        var list = src as Array<Dictionary>;
        var copy = [] as Array<Dictionary>;
        for (var i = 0; i < list.size(); i++) {
            copy.add(list[i]);
        }
        return copy;
    }

    private static function cloneStringList(src as Array<String>?) as Array<String> {
        if (src == null) {
            return [] as Array<String>;
        }
        var list = src as Array<String>;
        var copy = [] as Array<String>;
        for (var i = 0; i < list.size(); i++) {
            copy.add(list[i]);
        }
        return copy;
    }

    // ========================================================
    // PROGRAM SELECTION
    // ========================================================

    static function getActivePrograms() as Array<Dictionary> {
        var isPlus = EGYMSafeStore.getPropertyBool(EGYMKeys.IS_EGYM_PLUS, true);

        if (isPlus) {
            return getAllPrograms();
        } else {
            return getBasicPrograms();
        }
    }

    static function getCurrentProgram() as Dictionary {
        var index = EGYMSafeStore.getPropertyNumber(EGYMKeys.ACTIVE_PROGRAM, 0);

        var programs = getActivePrograms();
        if (index < 0 || index >= programs.size()) {
            index = 0;
            EGYMSafeStore.setPropertyValue(EGYMKeys.ACTIVE_PROGRAM, 0);
        }

        return programs[index];
    }

    // ========================================================
    // PROGRAM DATA 
    // ========================================================

    static function getBasicPrograms() as Array<Dictionary> {
        if (_basicProgramsCache == null) {
            var programs = [] as Array<Dictionary>;
            programs.add({ :p => "B",  :g => "GoalEndurance",   :m => "REGULAR",  :w => "20",  :i => 0.45 });
            programs.add({ :p => "B",  :g => "GoalMuscleBuild", :m => "REGULAR",  :w => "12",  :i => 0.65 });
            programs.add({ :p => "B",  :g => "GoalToning",      :m => "REGULAR",  :w => "25",  :i => 0.4 });
            programs.add({ :p => "B",  :g => "GoalStrength",    :m => "NEGATIVE", :w => "15",  :i => 0.6 });
            _basicProgramsCache = programs;
        }
        return cloneProgramList(_basicProgramsCache);
    }

    static function getAllPrograms() as Array<Dictionary> {
        if (_allProgramsCache == null) {
            var programs = [] as Array<Dictionary>;

            // AF (General Fitness)
            programs.add({ :p => "AF", :g => "GoalEndurance",    :m => "REGULAR",   :w => "22",  :i => 0.44 });
            programs.add({ :p => "AF", :g => "GoalMuscleBuild",  :m => "ADAPTIVE",  :w => "18",  :i => 0.59 });
            programs.add({ :p => "AF", :g => "GoalRobustness",   :m => "NEGATIVE",  :w => "14",  :i => 0.65 });
            programs.add({ :p => "AF", :g => "GoalMaxStrength",  :m => "EXPLOSIVE", :w => "2x6", :i => 0.55 });

            // MA (Muscle Build)
            programs.add({ :p => "MA", :g => "GoalRobustness",   :m => "NEGATIVE",  :w => "12",  :i => 0.65 });
            programs.add({ :p => "MA", :g => "GoalMuscleBuild",  :m => "ADAPTIVE",  :w => "10",  :i => 0.68 });
            programs.add({ :p => "MA", :g => "GoalMaxStrength",  :m => "ISOKINETIC", :w => "2x8", :i => 1.05 });
            programs.add({ :p => "MA", :g => "GoalMuscleBuild",  :m => "ADAPTIVE",  :w => "10",  :i => 0.68 });

            // FT (Body Toning)
            programs.add({ :p => "FT", :g => "GoalToning",       :m => "NEGATIVE",  :w => "30",  :i => 0.5 });
            programs.add({ :p => "FT", :g => "GoalFatBurn",      :m => "ISOKINETIC", :w => "23",  :i => 0.65 });
            programs.add({ :p => "FT", :g => "GoalMuscleBuild",  :m => "ADAPTIVE",  :w => "12",  :i => 0.67 });
            programs.add({ :p => "FT", :g => "GoalFatBurn",      :m => "ISOKINETIC", :w => "23",  :i => 0.65 });

            // AN (Weight Loss)
            programs.add({ :p => "AN", :g => "GoalEndurance",    :m => "REGULAR",   :w => "30",  :i => 0.35 });
            programs.add({ :p => "AN", :g => "GoalFatBurn",      :m => "ISOKINETIC", :w => "21",  :i => 0.6 });
            programs.add({ :p => "AN", :g => "GoalMuscleBuild",  :m => "ADAPTIVE",  :w => "15",  :i => 0.61 });
            programs.add({ :p => "AN", :g => "GoalFatBurn",      :m => "ISOKINETIC", :w => "21",  :i => 0.6 });

            // AT (Athletic)
            programs.add({ :p => "AT", :g => "GoalRobustness",   :m => "NEGATIVE",  :w => "12",  :i => 0.7 });
            programs.add({ :p => "AT", :g => "GoalSpeedStrength", :m => "EXPLOSIVE", :w => "2x6", :i => 0.55 });
            programs.add({ :p => "AT", :g => "GoalMuscleBuild",  :m => "ISOKINETIC", :w => "3x5", :i => 1.08 });
            programs.add({ :p => "AT", :g => "GoalSpeedStrength", :m => "EXPLOSIVE", :w => "2x6", :i => 0.55 });

            // MF (Metabolic Fit)
            programs.add({ :p => "MF", :g => "GoalActivation",   :m => "NEGATIVE",  :w => "20",   :i => 0.5 });
            programs.add({ :p => "MF", :g => "GoalMetabolism",   :m => "REGULAR",   :w => "22",   :i => 0.43 });
            programs.add({ :p => "MF", :g => "GoalFatBurn",      :m => "NEGATIVE",  :w => "25",   :i => 0.54 });
            programs.add({ :p => "MF", :g => "GoalMuscleBuild",  :m => "REGULAR",   :w => "2x10", :i => 0.5 });

            // RF (Rehab Fit)
            programs.add({ :p => "RF", :g => "GoalMobilization", :m => "ISOKINETIC", :w => "15",  :i => 0.4 });
            programs.add({ :p => "RF", :g => "GoalActivation",   :m => "ISOKINETIC", :w => "15",  :i => 0.4 });
            programs.add({ :p => "RF", :g => "GoalStrength",     :m => "NEGATIVE",  :w => "20",  :i => 0.49 });
            programs.add({ :p => "RF", :g => "GoalFunction",     :m => "REGULAR",   :w => "20",  :i => 0.44 });

            // IB (Immunity Boost)
            programs.add({ :p => "IB", :g => "GoalGettingStarted", :m => "REGULAR",  :w => "3x5", :i => 0.42 });
            programs.add({ :p => "IB", :g => "GoalProgress",     :m => "REGULAR",   :w => "3x5", :i => 0.42 });
            programs.add({ :p => "IB", :g => "GoalIntensify",    :m => "NEGATIVE",  :w => "2x8", :i => 0.55 });
            programs.add({ :p => "IB", :g => "GoalMaximize",     :m => "NEGATIVE",  :w => "2x9", :i => 0.55 });

            _allProgramsCache = programs;
        }
        return cloneProgramList(_allProgramsCache);
    }

    // ========================================================
    // EXERCISE LISTS
    // ========================================================

    static function getAdditionalExercises() as Array<String> {
        if (_additionalExercisesCache == null) {
            var add = [] as Array<String>;
            add.add("Bizepscurl");
            add.add("Trizepspresse");
            add.add("Glutaeus");
            add.add("Wadentrainer");
            _additionalExercisesCache = add;
        }
        return cloneStringList(_additionalExercisesCache);
    }

    static function getZirkelKraft() as Array<String> {
        if (_zirkelKraftCache == null) {
            var kraft = [] as Array<String>;
            kraft.add("Brustpresse");
            kraft.add("Bauchtrainer");
            kraft.add("Ruderzug");
            kraft.add("Seitlicher Bauch");
            kraft.add("Beinpresse");
            kraft.add("Latzug");
            kraft.add("Butterfly");
            kraft.add("Rueckentrainer");
            kraft.add("Reverse Butterfly");
            kraft.add("Schulterpresse");
            _zirkelKraftCache = kraft;
        }
        return cloneStringList(_zirkelKraftCache);
    }

    static function getZirkelBeine() as Array<String> {
        if (_zirkelBeineCache == null) {
            var beine = [] as Array<String>;
            beine.add("Squat");
            beine.add("Beinstrecker");
            beine.add("Beinbeuger");
            beine.add("Abduktor");
            beine.add("Adduktor");
            beine.add("Hip Thrust");
            _zirkelBeineCache = beine;
        }
        return cloneStringList(_zirkelBeineCache);
    }

    static function getAllExercises() as Array<String> {
        if (_allExercisesCache == null) {
            var kraft = getZirkelKraft();
            var beine = getZirkelBeine();
            var add = getAdditionalExercises();
            
            var totalSize = kraft.size() + beine.size() + add.size();
            var all = new [totalSize] as Array<String>;
            var idx = 0;
            
            for (var i = 0; i < kraft.size(); i++) {
                all[idx] = kraft[i];
                idx++;
            }
            for (var i = 0; i < beine.size(); i++) {
                all[idx] = beine[i];
                idx++;
            }
            for (var i = 0; i < add.size(); i++) {
                all[idx] = add[i];
                idx++;
            }
            _allExercisesCache = all;
        }
        return cloneStringList(_allExercisesCache);
    }

    // ========================================================
    // DISPLAY HELPERS
    // ========================================================

    static function getProgramDisplayString(p as Dictionary) as String {
        var egymApp = Application.getApp() as EGYMApp;

        var prefix = getProgramPrefix(p);
        var goalKey = getProgramGoalKey(p);
        var methodKey = getProgramMethodKey(p);
        var repsVal = getProgramRepsSpec(p);

        var goal = egymApp.getGoalName(goalKey);
        var method = egymApp.getMethodName(methodKey);
        var repsLabel = WatchUi.loadResource(Rez.Strings.UIReps) as String;

        return prefix + ":" + goal + "\n" + method + " " + repsVal + " " + repsLabel;
    }

    static function getCircleName() as String {
        var circleId = EGYMSafeStore.getPropertyNumber(EGYMKeys.ACTIVE_CIRCLE, 0);

        switch (circleId) {
            case 0: return WatchUi.loadResource(Rez.Strings.UIStrength);
            case 1: return WatchUi.loadResource(Rez.Strings.UILegs);
            case 2: return WatchUi.loadResource(Rez.Strings.UICustomCircuit);
            case 3: return WatchUi.loadResource(Rez.Strings.UIIndividual);
            default: return "Standard";
        }
    }

    static function getCleanedExerciseNames() as Array<String> {
        if (_cleanedExercisesCache == null) {
            var all = getAllExercises();
            _cleanedExercisesCache = [] as Array<String>;

            // Mirror EGYMView.cleanExName() so startup sync uses the same keys.
            for (var i = 0; i < all.size(); i++) {
                var str = all[i];
                var chars = str.toCharArray();
                var clean = [] as Array<Char>;

                for (var j = 0; j < chars.size(); j++) {
                    var c = chars[j];
                    if (c == 0x20 || c == 0x09) {
                        continue;
                    }
                    if (c == 0x00FC || c == 0x00DC) {
                        clean.add('u');
                        clean.add('e');
                    } else if (c == 0x00F6 || c == 0x00D6) {
                        clean.add('o');
                        clean.add('e');
                    } else if (c == 0x00E4 || c == 0x00C4) {
                        clean.add('a');
                        clean.add('e');
                    } else if (c == 0x00DF) {
                        clean.add('s');
                        clean.add('s');
                    } else {
                        clean.add(c);
                    }
                }

                var cleanName = clean.size() > 0 ? StringUtil.charArrayToString(clean) : "";
                _cleanedExercisesCache.add(cleanName);
            }
        }
        return cloneStringList(_cleanedExercisesCache);
    }
}
