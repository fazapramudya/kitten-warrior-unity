using System;
using System.Collections;
using UnityEngine;
using KittenWarrior.Player;
using KittenWarrior.Data;
using KittenWarrior.Core;

namespace KittenWarrior.Combat
{
    public enum CombatState
    {
        Neutral,
        Attacking,
        Blocking,
        Parrying,
        Staggered
    }

    /// <summary>
    /// Tactical player combat controller.
    /// Manages light combo chain, block/parry windows, durability degradation, and knockback reactions.
    /// Owned by: Worker-2-CombatAI
    /// </summary>
    [DisallowMultipleComponent]
    public class CombatController : MonoBehaviour, IDamageable
    {
        [Header("Equipped Weapon Data")]
        [SerializeField] private WeaponData currentWeapon;
        [SerializeField] private Hitbox weaponHitbox;

        [Header("Health & Defense")]
        [SerializeField] private float maxHealth = 120f;
        [SerializeField] private float defense = 10f;
        [SerializeField] private float maxPoise = 50f;
        [SerializeField] private float poiseRecoveryRate = 15f;

        [Header("References")]
        [SerializeField] private StaminaSystem staminaSystem;
        [SerializeField] private PlayerController playerController;

        private float currentHealth;
        private float currentPoise;
        private float currentDurability;
        private CombatState combatState = CombatState.Neutral;
        private int currentComboIndex = 0;
        private float comboResetTimer = 0f;
        private float parryTimer = 0f;
        private bool isDead = false;

        public CombatState CurrentState => combatState;
        public float CurrentHealth => currentHealth;
        public float MaxHealth => maxHealth;
        public float CurrentDurability => currentDurability;
        public bool IsDead => isDead;

        public event Action<CombatState> OnCombatStateChanged;
        public event Action<int> OnAttackExecuted;
        public event Action<bool> OnBlockStateChanged;
        public event Action OnParrySuccess;
        public event Action<float, float> OnHealthChanged;
        public event Action OnDeath;

        private void Awake()
        {
            currentHealth = maxHealth;
            currentPoise = maxPoise;

            if (currentWeapon != null) currentDurability = currentWeapon.MaxDurability;
            if (staminaSystem == null) staminaSystem = GetComponent<StaminaSystem>();
            if (playerController == null) playerController = GetComponent<PlayerController>();
            if (weaponHitbox != null) weaponHitbox.Initialize(gameObject);
        }

        private void Update()
        {
            if (isDead) return;

            UpdatePoiseRecovery();
            UpdateTimers();
            HandleCombatInputs();
        }

        private void UpdatePoiseRecovery()
        {
            if (currentPoise < maxPoise && combatState != CombatState.Staggered)
            {
                currentPoise = Mathf.Min(maxPoise, currentPoise + (poiseRecoveryRate * Time.deltaTime));
            }
        }

        private void UpdateTimers()
        {
            if (comboResetTimer > 0f)
            {
                comboResetTimer -= Time.deltaTime;
                if (comboResetTimer <= 0f)
                {
                    currentComboIndex = 0;
                }
            }

            if (parryTimer > 0f)
            {
                parryTimer -= Time.deltaTime;
                if (parryTimer <= 0f && combatState == CombatState.Parrying)
                {
                    SetState(CombatState.Blocking);
                }
            }
        }

        private void HandleCombatInputs()
        {
            if (currentWeapon == null || combatState == CombatState.Staggered) return;

            // Light Attack (Left Click)
            if (Input.GetMouseButtonDown(0) && combatState != CombatState.Attacking)
            {
                TryExecuteLightAttack();
            }

            // Block / Parry (Right Click Hold)
            if (Input.GetMouseButtonDown(1) && combatState == CombatState.Neutral)
            {
                StartBlocking();
            }
            else if (Input.GetMouseButtonUp(1) && (combatState == CombatState.Blocking || combatState == CombatState.Parrying))
            {
                StopBlocking();
            }
        }

        private void TryExecuteLightAttack()
        {
            if (staminaSystem != null && !staminaSystem.TryConsumeStamina(currentWeapon.StaminaCost))
            {
                return;
            }

            SetState(CombatState.Attacking);
            OnAttackExecuted?.Invoke(currentComboIndex);

            float damage = currentWeapon.GetComboDamage(currentComboIndex);
            DamageInfo payload = new DamageInfo(
                amount: damage,
                poiseDamage: currentWeapon.PoiseDamage,
                attacker: gameObject,
                knockbackForce: currentWeapon.KnockbackForce
            );

            if (weaponHitbox != null)
            {
                weaponHitbox.OpenHitbox(payload);
            }

            // Apply durability wear
            currentDurability = Mathf.Max(0f, currentDurability - currentWeapon.DurabilityLossPerHit);

            // Advance combo
            currentComboIndex = (currentComboIndex + 1) % currentWeapon.MaxComboSteps;
            comboResetTimer = 0.85f;

            StartCoroutine(AttackRecoveryRoutine(0.42f / currentWeapon.AttackSpeed));
        }

        private IEnumerator AttackRecoveryRoutine(float duration)
        {
            yield return new WaitForSeconds(duration);

            if (weaponHitbox != null)
            {
                weaponHitbox.CloseHitbox();
            }

            if (combatState == CombatState.Attacking)
            {
                SetState(CombatState.Neutral);
            }
        }

        private void StartBlocking()
        {
            SetState(CombatState.Parrying);
            parryTimer = 0.22f; // Parry timing window
            OnBlockStateChanged?.Invoke(true);
        }

        private void StopBlocking()
        {
            SetState(CombatState.Neutral);
            parryTimer = 0f;
            OnBlockStateChanged?.Invoke(false);
        }

        public bool TakeDamage(DamageInfo info)
        {
            if (isDead) return false;

            // Check for Parry success
            if (combatState == CombatState.Parrying)
            {
                ExecuteParry(info.Attacker);
                return false;
            }

            // Check for Block
            if (combatState == CombatState.Blocking)
            {
                if (staminaSystem != null && staminaSystem.TryConsumeStamina(currentWeapon != null ? currentWeapon.BlockStaminaCost : 12f))
                {
                    info.Amount *= 0.25f; // Block mitigates 75% damage
                    info.KnockbackForce *= 0.3f;
                }
                else
                {
                    TriggerStagger(1.2f);
                }
            }

            // Apply Balancing defense formula
            float effectiveDamage = BalancingFormulas.CalculateDamage(info.Amount, defense);
            currentHealth = Mathf.Max(0f, currentHealth - effectiveDamage);
            OnHealthChanged?.Invoke(currentHealth, maxHealth);
            GameEvents.TriggerPlayerHealthChanged(currentHealth, maxHealth);

            // Apply Knockback to player
            if (playerController != null && info.KnockbackForce > 0f)
            {
                playerController.ApplyKnockback(info.KnockbackDirection * info.KnockbackForce);
            }

            // Poise calculation
            currentPoise -= info.PoiseDamage;
            if (currentPoise <= 0f)
            {
                TriggerStagger(0.8f);
            }

            if (currentHealth <= 0f)
            {
                Die();
            }

            return true;
        }

        private void ExecuteParry(GameObject attacker)
        {
            OnParrySuccess?.Invoke();
            GameEvents.TriggerPlayerParried();

            if (attacker != null && attacker.TryGetComponent<IDamageable>(out var attackerDamageable))
            {
                DamageInfo counter = new DamageInfo(
                    amount: 0f,
                    poiseDamage: 100f,
                    attacker: gameObject,
                    isParryCounter: true
                );
                attackerDamageable.TakeDamage(counter);
            }

            SetState(CombatState.Neutral);
        }

        private void TriggerStagger(float duration)
        {
            currentPoise = maxPoise;
            SetState(CombatState.Staggered);
            if (weaponHitbox != null) weaponHitbox.CloseHitbox();
            StartCoroutine(StaggerRoutine(duration));
        }

        private IEnumerator StaggerRoutine(float duration)
        {
            yield return new WaitForSeconds(duration);
            if (combatState == CombatState.Staggered)
            {
                SetState(CombatState.Neutral);
            }
        }

        private void Die()
        {
            isDead = true;
            SetState(CombatState.Neutral);
            OnDeath?.Invoke();
            GameEvents.TriggerPlayerDied();
        }

        private void SetState(CombatState newState)
        {
            if (combatState == newState) return;
            combatState = newState;
            OnCombatStateChanged?.Invoke(combatState);
        }

        public Transform GetTransform() => transform;
    }
}
