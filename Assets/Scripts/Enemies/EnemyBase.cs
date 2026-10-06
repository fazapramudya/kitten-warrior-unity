using System;
using UnityEngine;
using KittenWarrior.Combat;
using KittenWarrior.Data;
using KittenWarrior.Core;

namespace KittenWarrior.Enemies
{
    /// <summary>
    /// Base class for monsters and hostile NPCs.
    /// Handles damage mitigation, knockback absorption, poise stun, and loot drop triggers.
    /// Owned by: Worker-2-CombatAI
    /// </summary>
    [DisallowMultipleComponent]
    public abstract class EnemyBase : MonoBehaviour, IDamageable
    {
        [Header("Configuration")]
        [SerializeField] protected EnemyData enemyData;

        protected float currentHealth;
        protected float currentPoise;
        protected bool isDead;
        protected bool isStunned;

        private Rigidbody rb;

        public EnemyData Data => enemyData;
        public float CurrentHealth => currentHealth;
        public float MaxHealth => enemyData != null ? enemyData.MaxHp : 100f;
        public bool IsDead => isDead;
        public bool IsStunned => isStunned;

        public event Action<float, float> OnHealthChanged;
        public event Action<DamageInfo> OnDamaged;
        public event Action OnStunStarted;
        public event Action OnStunEnded;
        public event Action OnDeath;

        protected virtual void Awake()
        {
            rb = GetComponent<Rigidbody>();
            if (enemyData != null)
            {
                currentHealth = enemyData.MaxHp;
                currentPoise = enemyData.MaxPoise;
            }
        }

        public virtual bool TakeDamage(DamageInfo info)
        {
            if (isDead) return false;

            // Apply Balancing defense formula
            float defense = enemyData != null ? enemyData.Defense : 0f;
            float effectiveDamage = BalancingFormulas.CalculateDamage(info.Amount, defense);

            currentHealth = Mathf.Max(0f, currentHealth - effectiveDamage);
            OnHealthChanged?.Invoke(currentHealth, MaxHealth);
            OnDamaged?.Invoke(info);

            // Apply Knockback impulse to enemy
            if (info.KnockbackForce > 0f)
            {
                ApplyKnockbackImpulse(info.KnockbackDirection * info.KnockbackForce);
            }

            // Poise and stun check
            currentPoise -= info.PoiseDamage;
            if (currentPoise <= 0f || info.IsParryCounter)
            {
                TriggerStun();
            }

            if (currentHealth <= 0f)
            {
                Die();
            }

            return true;
        }

        protected virtual void ApplyKnockbackImpulse(Vector3 impulse)
        {
            if (rb != null && !rb.isKinematic)
            {
                rb.AddForce(impulse, ForceMode.Impulse);
            }
            else
            {
                transform.position += impulse * 0.05f;
            }
        }

        protected virtual void TriggerStun()
        {
            if (isDead || isStunned) return;
            isStunned = true;
            if (enemyData != null) currentPoise = enemyData.MaxPoise;
            OnStunStarted?.Invoke();

            float duration = enemyData != null ? enemyData.StunDuration : 1.0f;
            Invoke(nameof(RecoverFromStun), duration);
        }

        protected virtual void RecoverFromStun()
        {
            if (isDead) return;
            isStunned = false;
            OnStunEnded?.Invoke();
        }

        protected virtual void Die()
        {
            if (isDead) return;
            isDead = true;
            OnDeath?.Invoke();

            SpawnDropLoot();
            Destroy(gameObject, 3.0f);
        }

        private void SpawnDropLoot()
        {
            if (enemyData == null || enemyData.DropTable == null) return;

            DropItem[] items = enemyData.DropTable.DropItems;
            if (items == null) return;

            for (int i = 0; i < items.Length; i++)
            {
                float roll = UnityEngine.Random.value;
                if (roll <= items[i].DropChance && items[i].ItemPrefab != null)
                {
                    int qty = UnityEngine.Random.Range(items[i].MinQuantity, items[i].MaxQuantity + 1);
                    for (int q = 0; q < qty; q++)
                    {
                        Vector3 spawnOffset = UnityEngine.Random.insideUnitSphere * 0.5f;
                        spawnOffset.y = 0.5f;
                        Instantiate(items[i].ItemPrefab, transform.position + spawnOffset, Quaternion.identity);
                    }
                }
            }
        }

        public Transform GetTransform() => transform;
    }
}
