using UnityEngine;

namespace KittenWarrior.Core
{
    /// <summary>
    /// Mathematical balancing library containing formulas for stamina curves, regeneration, and damage reduction.
    /// Owned by: Worker-3-Systems
    /// </summary>
    public static class BalancingFormulas
    {
        private const float DefenseConstant = 50f;

        /// <summary>
        /// Calculates effective damage dealt after considering target's defense rating.
        /// Formula: EffectiveDamage = RawDamage * (DefenseConstant / (DefenseConstant + Defense))
        /// Prevents negative damage and provides diminishing returns for defense stacking.
        /// </summary>
        public static float CalculateDamage(float rawDamage, float defense)
        {
            if (rawDamage <= 0f) return 0f;
            float clampedDefense = Mathf.Max(0f, defense);
            float reductionMultiplier = DefenseConstant / (DefenseConstant + clampedDefense);
            return Mathf.Max(1f, rawDamage * reductionMultiplier);
        }

        /// <summary>
        /// Calculates sprint stamina drain based on current encumbrance or agility modifier.
        /// </summary>
        public static float CalculateSprintDrain(float baseDrainRate, float encumbranceWeight, float deltaTime)
        {
            float weightPenalty = 1f + (Mathf.Max(0f, encumbranceWeight) * 0.05f);
            return baseDrainRate * weightPenalty * deltaTime;
        }

        /// <summary>
        /// Calculates passive stamina regeneration rate with bonus for resting/shelter (Valheim mechanic).
        /// </summary>
        public static float CalculateStaminaRegen(float baseRegenRate, bool isResting, bool isExhausted, float deltaTime)
        {
            float multiplier = 1f;
            if (isResting) multiplier *= 1.5f;
            if (isExhausted) multiplier *= 0.6f; // Slower recovery when completely drained

            return baseRegenRate * multiplier * deltaTime;
        }

        /// <summary>
        /// Evaluates exponential experience required for leveling up.
        /// Formula: ExpReq = BaseExp * (Level ^ 1.6)
        /// </summary>
        public static int CalculateRequiredExp(int currentLevel, int baseExp = 100)
        {
            int level = Mathf.Max(1, currentLevel);
            return Mathf.RoundToInt(baseExp * Mathf.Pow(level, 1.6f));
        }
    }
}
