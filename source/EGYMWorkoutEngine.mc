import Toybox.Lang;
import Toybox.Math;

// ============================================================
// EGYMWorkoutEngine - Training math and workout-state updates.
//
// Design goals:
// - Keep EGYMView focused on UI/input.
// - Keep formulas in one place for plan maintenance.
// - Use in-place Dictionary mutation to avoid object churn.
//
// Plan math (shared by all 32 EGYM+ plans):
// 1) Base target factor:
//    baseFactorBasis = round(intensity * LEARNED_FACTOR_SCALE)
// 2) Target weight:
//    targetKg = round(RM * activeFactorBasis / LEARNED_FACTOR_SCALE)
// 3) Learned-factor adaptation (smoothed):
//    observedBasis = round(currentWeight * LEARNED_FACTOR_SCALE / RM)
//    newBasis = round((storedBasis * 3 + observedBasis) / 4)
// 4) Workload:
//    - EXPLOSIVE: workload = weight * reps
//    - others:    workload = weight * (quality / 100) * reps
// ============================================================
class EGYMWorkoutEngine {
    private const METHOD_EXPLOSIVE = "EXPLOSIVE";
    private const KEY_SEPARATOR = "_";
    private const KEY_GENERATION_SUFFIX = "_g";
    private const TOKEN_PLUS = "+";
    private const TOKEN_MUL = "*";
    private const TOKEN_MUL_ALT_LOWER = "x";
    private const TOKEN_MUL_ALT_UPPER = "X";

    function initialize() {
    }

    function clampLearnedFactor(factorBasis as Number) as Number {
        if (factorBasis < EGYMConfig.MIN_LEARNED_FACTOR) {
            return EGYMConfig.MIN_LEARNED_FACTOR;
        }
        if (factorBasis > EGYMConfig.MAX_LEARNED_FACTOR) {
            return EGYMConfig.MAX_LEARNED_FACTOR;
        }
        return factorBasis;
    }

    function getBaseFactorBasis(prog as Dictionary) as Number {
        var factor = EGYMConfig.getProgramIntensityFactor(prog);
        if (factor <= 0.0) {
            return 0;
        }
        return clampLearnedFactor(
            Math.round(factor * (EGYMConfig.LEARNED_FACTOR_SCALE * 1.0)).toNumber()
        );
    }

    function buildLearnedFactorKey(
        cleanExerciseName as String,
        progPrefix as String,
        methodKey as String,
        baseFactorBasis as Number,
        generation as Number
    ) as String {
        var key = EGYMKeys.LEARNED_FACTOR_PREFIX +
            cleanExerciseName + KEY_SEPARATOR +
            progPrefix + KEY_SEPARATOR +
            methodKey + KEY_SEPARATOR +
            baseFactorBasis.toString();

        if (generation > 0) {
            key += KEY_GENERATION_SUFFIX + generation.toString();
        }
        return key;
    }

    function resolveActiveFactorBasis(baseFactorBasis as Number, learnedFactorBasis as Number) as Number {
        if (learnedFactorBasis > 0) {
            return clampLearnedFactor(learnedFactorBasis);
        }
        if (baseFactorBasis <= 0) {
            return 0;
        }
        return clampLearnedFactor(baseFactorBasis);
    }

    function computeTargetWeight(rm as Number, factorBasis as Number) as Number {
        if (rm <= 0 || factorBasis <= 0) {
            return 0;
        }
        return Math.round((rm * factorBasis) / (EGYMConfig.LEARNED_FACTOR_SCALE * 1.0)).toNumber();
    }

    function computeLearnedFactorUpdate(
        rm as Number,
        currentWeight as Number,
        suggestedWeight as Number,
        storedBasis as Number
    ) as Number? {
        if (rm <= 0 || currentWeight <= 0) {
            return null;
        }
        if (currentWeight == suggestedWeight) {
            return null;
        }

        var observedBasis = Math.round(
            (currentWeight * (EGYMConfig.LEARNED_FACTOR_SCALE * 1.0)) / rm
        ).toNumber();
        observedBasis = clampLearnedFactor(observedBasis);

        if (storedBasis > 0) {
            var clampedStored = clampLearnedFactor(storedBasis);
            return clampLearnedFactor(
                Math.round(((clampedStored * 3) + observedBasis) / 4.0).toNumber()
            );
        }
        return observedBasis;
    }

    function clampQualityAfterDelta(
        currentQuality as Number,
        delta as Number,
        isExplosive as Boolean,
        minQuality as Number,
        maxQuality as Number,
        maxWatt as Number
    ) as Number {
        var next = currentQuality + delta;
        var upper = isExplosive ? maxWatt : maxQuality;
        if (next < minQuality) {
            next = minQuality;
        } else if (next > upper) {
            next = upper;
        }
        return next;
    }

    function isExplosiveMethod(methodKey as String) as Boolean {
        return methodKey.equals(METHOD_EXPLOSIVE);
    }

    function parseReps(repsSpec as String?) as Number {
        if (repsSpec == null || repsSpec.length() == 0) {
            return 0;
        }
        var total = 0;
        var remaining = repsSpec;
        var plusIdx = remaining.find(TOKEN_PLUS);

        while (plusIdx != null) {
            total += parseTerm(remaining.substring(0, plusIdx));
            remaining = remaining.substring(plusIdx + 1, remaining.length());
            plusIdx = remaining.find(TOKEN_PLUS);
        }
        total += parseTerm(remaining);
        return total;
    }

    function parseTerm(term as String?) as Number {
        var trimmed = EGYMSafeStore.trimWhitespace(term);
        if (trimmed.length() == 0) {
            return 0;
        }

        var mulPos = trimmed.find(TOKEN_MUL);
        if (mulPos == null) { mulPos = trimmed.find(TOKEN_MUL_ALT_LOWER); }
        if (mulPos == null) { mulPos = trimmed.find(TOKEN_MUL_ALT_UPPER); }
        if (mulPos != null) {
            var leftStr = EGYMSafeStore.trimWhitespace(trimmed.substring(0, mulPos));
            var rightStr = EGYMSafeStore.trimWhitespace(trimmed.substring(mulPos + 1, trimmed.length()));
            var left = leftStr.toNumber();
            var right = rightStr.toNumber();
            if (left != null && right != null) {
                return left * right;
            }
        }

        var val = trimmed.toNumber();
        return val != null ? val : 0;
    }

    // Mutates state in place to avoid allocations.
    // Required keys in `state`: :setCount, :qualityTotal, :qualityCount,
    // :wattTotal, :wattCount, :sessionTotalKg.
    // Writes outputs into: :lastReps, :lastWorkload.
    function applySetOutcome(
        state as Dictionary,
        methodKey as String,
        qualityValue as Number,
        currentWeight as Number,
        repsSpec as String
    ) as Void {
        var setCount = coerceNumber(state[:setCount], 0) + 1;
        state[:setCount] = setCount;

        var isExplosive = isExplosiveMethod(methodKey);
        if (isExplosive) {
            state[:wattTotal] = coerceNumber(state[:wattTotal], 0) + qualityValue;
            state[:wattCount] = coerceNumber(state[:wattCount], 0) + 1;
        } else {
            state[:qualityTotal] = coerceNumber(state[:qualityTotal], 0) + qualityValue;
            state[:qualityCount] = coerceNumber(state[:qualityCount], 0) + 1;
        }

        var totalReps = parseReps(repsSpec);
        var factor = isExplosive ? 1.0 : qualityValue / 100.0;
        var workload = (currentWeight * factor * totalReps).toNumber();
        state[:sessionTotalKg] = coerceNumber(state[:sessionTotalKg], 0) + workload;
        state[:lastReps] = totalReps;
        state[:lastWorkload] = workload;
    }

    private function coerceNumber(raw, fallback as Number) as Number {
        if (raw == null) {
            return fallback;
        }
        if (raw instanceof Lang.Number) {
            return raw as Number;
        }
        if (raw has :toNumber) {
            try {
                var n = raw.toNumber();
                if (n != null && n instanceof Lang.Number) {
                    return n as Number;
                }
            } catch (ignored) {
            }
        }
        return fallback;
    }
}
