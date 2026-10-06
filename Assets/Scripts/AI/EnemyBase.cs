using System;
using UnityEngine;
using KittenWarrior.Combat;

namespace KittenWarrior.AI
{
    /// <summary>
    /// Base class for all hostile NPCs. Implements damage reception, poise breakdown, and death events.
    /// Owned by: Grimm (Enemy AI Architect)
    /// </summary>
    [DisallowMultipleComponent]
    public abstract class EnemyBase : MonoBehaviour, IDamageable
    {
        [Header("Data Configuration")]
        [SerializeField] protected EnemyData enemyData;

        protected float currentHealth;
        protected float currentPoise;
        protected bool isDead;
        protected bool isStaggered;

        public EnemyData Data => enemyData;
        public float CurrentHealth => currentHealth;
        public float MaxHealth => enemyData != null ? enemyData.MaxHealth : 100f;
        public bool IsDead => isDead;
        public bool IsStaggered => isStaggered;

        public event Action<float, float> OnHealthChanged; // (current, max)
        public event Action<DamageInfo> OnDamaged;
        public event Action OnStaggerStarted;
        public event Action OnStaggerEnded;
        public event Action OnDeath;

        protected virtual void Awake()
        {
            if (enemyData != null)
            {
                currentHealth = enemyData.MaxHealth;
                currentPoise = enemyData.MaxPoise;
            }
        }

        public virtual bool TakeDamage(DamageInfo info)
        {
            if (isDead) return false;

            currentHealth = Mathf.Max(0f, currentHealth - info.Amount);
            OnHealthChanged?.Invoke(currentHealth, MaxHealth);
            OnDamaged?.Invoke(info);

            // Poise check
            currentPoise -= info.PoiseDamage;
            if (currentPoise <= 0f || info.IsParryCounter)
            {
                TriggerStagger();
            }

            if (currentHealth <= 0f)
            {
                Die();
            }

            return true;
        }

        protected virtual void TriggerStagger()
        {
            if (isDead || isStaggered) return;
            isStaggered = true;
            if (enemyData != null) currentPoise = enemyData.MaxPoise;
            OnStaggerStarted?.Invoke();
            Invoke(nameof(RecoverFromStagger), enemyData != null ? enemyData.StaggerDuration : 0.8f);
        }

        protected virtual void RecoverFromStagger()
        {
            if (isDead) return;
            isStaggered = false;
            OnStaggerEnded?.Invoke();
        }

        protected virtual void Die()
        {
            if (isDead) return;
            isDead = true;
            OnDeath?.Invoke();
            // Disappear or spawn loot after delay
            Destroy(gameObject, 3.5f);
        }

        public Transform GetTransform() => transform;
    }
}
