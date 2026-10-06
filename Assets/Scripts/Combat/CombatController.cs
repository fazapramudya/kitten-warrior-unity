using System;
using System.Collections;
using UnityEngine;
using KittenWarrior.Gameplay;

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
    /// Manages 3-hit combo chains, block/parry windows, hit-stop, and stamina integration.
    /// Owned by: Leo (Combat Director)
    /// </summary>
    [DisallowMultipleComponent]
    public class CombatController : MonoBehaviour, IDamageable
    {
        [Header("Equipped Weapon")]
        [SerializeField] private WeaponData currentWeapon;
        [SerializeField] private Hitbox weaponHitbox;

        [Header("Health & Poise")]
        [SerializeField] private float maxHealth = 120f;
        [SerializeField] private float maxPoise = 50f;
        [SerializeField] private float poiseRecoveryRate = 15f;

        [Header("References")]
        [SerializeField] private StaminaSystem staminaSystem;

        private float currentHealth;
        private float currentPoise;
        private CombatState combatState = CombatState.Neutral;
        private int currentComboIndex = 0;
        private float comboResetTimer = 0f;
        private float parryTimer = 0f;
        private bool isDead = false;

        public CombatState CurrentState => combatState;
        public float CurrentHealth => currentHealth;
        public float MaxHealth => maxHealth;
        public bool IsDead => isDead;

        public event Action<CombatState> OnCombatStateChanged;
        public event Action<int> OnAttackExecuted; // combo index
        public event Action<bool> OnBlockStateChanged; // isBlocking
        public event Action OnParrySuccess;
        public event Action<float, float> OnHealthChanged; // (current, max)
        public event Action OnDeath;

        private void Awake()
        {
            currentHealth = maxHealth;
            currentPoise = maxPoise;

            if (staminaSystem == null) staminaSystem = GetComponent<StaminaSystem>();
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
            // Combo decay timer
            if (comboResetTimer > 0f)
            {
                comboResetTimer -= Time.deltaTime;
                if (comboResetTimer <= 0f)
                {
                    currentComboIndex = 0;
                }
            }

            // Parry active window
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
            if (staminaSystem != null && !staminaSystem.TryConsumeStamina(currentWeapon.LightAttackStaminaCost))
            {
                return; // Valheim: out of stamina!
            }

            SetState(CombatState.Attacking);
            OnAttackExecuted?.Invoke(currentComboIndex);

            // Open hitbox with current combo damage
            float damage = currentWeapon.GetComboDamage(currentComboIndex);
            DamageInfo payload = new DamageInfo(damage, currentWeapon.PoiseDamage, gameObject);

            if (weaponHitbox != null)
            {
                weaponHitbox.OpenHitbox(payload);
            }

            // Cycle combo chain
            currentComboIndex = (currentComboIndex + 1) % currentWeapon.MaxComboSteps;
            comboResetTimer = currentWeapon.ComboWindow;

            // Attack cooldown / recovery simulated (in real production driven by Animation Events)
            StartCoroutine(AttackRecoveryRoutine(0.45f));
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
            parryTimer = currentWeapon.ParryWindow;
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
                return false; // Negates damage completely on parry
            }

            // Check for Block
            if (combatState == CombatState.Blocking)
            {
                if (staminaSystem != null && staminaSystem.TryConsumeStamina(currentWeapon.BlockStaminaCost))
                {
                    // Block reduces 75% damage
                    info.Amount *= 0.25f;
                }
                else
                {
                    // Guard broken!
                    TriggerStagger(1.2f);
                }
            }

            // Apply damage
            currentHealth = Mathf.Max(0f, currentHealth - info.Amount);
            OnHealthChanged?.Invoke(currentHealth, maxHealth);

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

            // Stagger attacker if possible
            if (attacker != null && attacker.TryGetComponent<IDamageable>(out var attackerDamageable))
            {
                // Counter attack trigger
                DamageInfo counterStagger = new DamageInfo(0f, 100f, gameObject, isParryCounter: true);
                attackerDamageable.TakeDamage(counterStagger);
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
