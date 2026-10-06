using System;
using UnityEngine;

namespace KittenWarrior.Gameplay
{
    /// <summary>
    /// Valheim-inspired stamina system.
    /// Manages player stamina pool, action consumption, regen delay, and exhaustion state.
    /// Owned by: Felix (Gameplay Lead)
    /// </summary>
    [DisallowMultipleComponent]
    public class StaminaSystem : MonoBehaviour
    {
        [Header("Stamina Pool Settings")]
        [Tooltip("Maximum stamina pool available to the player.")]
        [SerializeField] private float maxStamina = 100f;

        [Tooltip("Rate at which stamina regenerates per second.")]
        [SerializeField] private float regenRate = 22f;

        [Tooltip("Delay in seconds before stamina begins to regenerate after consumption.")]
        [SerializeField] private float regenDelay = 1.25f;

        [Header("Exhaustion State")]
        [Tooltip("Minimum percentage of max stamina required to recover from complete exhaustion.")]
        [Range(0.1f, 0.5f)]
        [SerializeField] private float recoveryThresholdPercent = 0.25f;

        private float currentStamina;
        private float regenTimer;
        private bool isExhausted;

        public float CurrentStamina => currentStamina;
        public float MaxStamina => maxStamina;
        public float NormalizedStamina => Mathf.Clamp01(currentStamina / Mathf.Max(maxStamina, 0.0001f));
        public bool IsExhausted => isExhausted;

        public event Action<float, float> OnStaminaChanged; // (current, max)
        public event Action<bool> OnExhaustionStateChanged; // (isExhausted)

        private void Awake()
        {
            currentStamina = maxStamina;
        }

        private void Start()
        {
            OnStaminaChanged?.Invoke(currentStamina, maxStamina);
        }

        private void Update()
        {
            HandleRegeneration(Time.deltaTime);
        }

        private void HandleRegeneration(float deltaTime)
        {
            if (regenTimer > 0f)
            {
                regenTimer -= deltaTime;
                return;
            }

            if (currentStamina < maxStamina)
            {
                currentStamina = Mathf.Min(maxStamina, currentStamina + (regenRate * deltaTime));
                OnStaminaChanged?.Invoke(currentStamina, maxStamina);

                // Recover from exhaustion once stamina reaches threshold
                if (isExhausted && currentStamina >= (maxStamina * recoveryThresholdPercent))
                {
                    isExhausted = false;
                    OnExhaustionStateChanged?.Invoke(false);
                }
            }
        }

        /// <summary>
        /// Attempts to consume an exact amount of stamina.
        /// </summary>
        public bool TryConsumeStamina(float amount)
        {
            if (amount <= 0f) return true;
            if (isExhausted) return false;

            if (currentStamina >= amount)
            {
                currentStamina = Mathf.Max(0f, currentStamina - amount);
                regenTimer = regenDelay;
                OnStaminaChanged?.Invoke(currentStamina, maxStamina);

                if (Mathf.Approximately(currentStamina, 0f))
                {
                    isExhausted = true;
                    OnExhaustionStateChanged?.Invoke(true);
                }

                return true;
            }

            return false;
        }

        /// <summary>
        /// Consumes stamina over time (e.g. while sprinting).
        /// Returns true if stamina is still available.
        /// </summary>
        public bool TryConsumeStaminaOverTime(float ratePerSecond, float deltaTime)
        {
            if (isExhausted) return false;

            float cost = ratePerSecond * deltaTime;
            if (currentStamina > cost)
            {
                currentStamina = Mathf.Max(0f, currentStamina - cost);
                regenTimer = regenDelay;
                OnStaminaChanged?.Invoke(currentStamina, maxStamina);
                return true;
            }

            // Drained completely
            currentStamina = 0f;
            regenTimer = regenDelay;
            isExhausted = true;
            OnStaminaChanged?.Invoke(currentStamina, maxStamina);
            OnExhaustionStateChanged?.Invoke(true);
            return false;
        }

        /// <summary>
        /// Instantly restores stamina by a set amount.
        /// </summary>
        public void RestoreStamina(float amount)
        {
            if (amount <= 0f) return;
            currentStamina = Mathf.Min(maxStamina, currentStamina + amount);
            OnStaminaChanged?.Invoke(currentStamina, maxStamina);

            if (isExhausted && currentStamina >= (maxStamina * recoveryThresholdPercent))
            {
                isExhausted = false;
                OnExhaustionStateChanged?.Invoke(false);
            }
        }
    }
}
