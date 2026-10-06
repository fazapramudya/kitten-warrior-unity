using System;
using UnityEngine;

namespace KittenWarrior.Core
{
    /// <summary>
    /// Global zero-allocation event channel bus for decoupled cross-system communication.
    /// Owned by: Luna (Systems & Tech Lead)
    /// </summary>
    public static class GameEvents
    {
        // Player & Gameplay Events
        public static event Action<float, float> PlayerStaminaChanged;
        public static event Action<float, float> PlayerHealthChanged;
        public static event Action PlayerDied;
        public static event Action PlayerParried;

        // Boss & Combat Encounter Events
        public static event Action<string, float, float> BossEncounterStarted; // bossName, currentHp, maxHp
        public static event Action<float, float> BossHealthUpdated;
        public static event Action BossDefeated;

        // Environment & Ambiance Events
        public static event Action<bool> ShelterStateChanged; // inShelter (affects stamina regen like Valheim)

        // Event Trigger Methods
        public static void TriggerPlayerStaminaChanged(float current, float max) => PlayerStaminaChanged?.Invoke(current, max);
        public static void TriggerPlayerHealthChanged(float current, float max) => PlayerHealthChanged?.Invoke(current, max);
        public static void TriggerPlayerDied() => PlayerDied?.Invoke();
        public static void TriggerPlayerParried() => PlayerParried?.Invoke();

        public static void TriggerBossEncounterStarted(string name, float current, float max) => BossEncounterStarted?.Invoke(name, current, max);
        public static void TriggerBossHealthUpdated(float current, float max) => BossHealthUpdated?.Invoke(current, max);
        public static void TriggerBossDefeated() => BossDefeated?.Invoke();

        public static void TriggerShelterStateChanged(bool inShelter) => ShelterStateChanged?.Invoke(inShelter);
    }
}
