using UnityEngine;
using KittenWarrior.Combat;

namespace KittenWarrior.AI.Enemies
{
    /// <summary>
    /// Goblin Spearman archetype: mid-range thrusting combatant with tactical spear attacks.
    /// Owned by: Grimm (Enemy AI Architect)
    /// </summary>
    public class GoblinSpearman : EnemyBase
    {
        [Header("Spear Weaponry")]
        [SerializeField] private Hitbox spearHitbox;

        private EnemyBrain brain;

        protected override void Awake()
        {
            base.Awake();
            brain = GetComponent<EnemyBrain>();
            if (spearHitbox != null) spearHitbox.Initialize(gameObject);
        }

        private void OnEnable()
        {
            if (brain != null) brain.OnPerformAttack += PerformSpearThrust;
        }

        private void OnDisable()
        {
            if (brain != null) brain.OnPerformAttack -= PerformSpearThrust;
        }

        private void PerformSpearThrust()
        {
            if (isDead || isStaggered) return;

            if (spearHitbox != null && enemyData != null)
            {
                DamageInfo payload = new DamageInfo(enemyData.BaseDamage, enemyData.PoiseDamage, gameObject, type: DamageType.Piercing);
                spearHitbox.OpenHitbox(payload);
                Invoke(nameof(RetractSpear), 0.45f);
            }
        }

        private void RetractSpear()
        {
            if (spearHitbox != null) spearHitbox.CloseHitbox();
        }
    }
}
