using UnityEngine;
using KittenWarrior.Combat;

namespace KittenWarrior.AI.Enemies
{
    /// <summary>
    /// Forest Slime archetype: light bouncy melee attacker with leap strikes.
    /// Owned by: Grimm (Enemy AI Architect)
    /// </summary>
    public class ForestSlime : EnemyBase
    {
        [Header("Slime Specifics")]
        [SerializeField] private Hitbox bodyHitbox;
        [SerializeField] private float leapForce = 7f;

        private EnemyBrain brain;

        protected override void Awake()
        {
            base.Awake();
            brain = GetComponent<EnemyBrain>();
            if (bodyHitbox != null) bodyHitbox.Initialize(gameObject);
        }

        private void OnEnable()
        {
            if (brain != null) brain.OnPerformAttack += PerformLeapAttack;
        }

        private void OnDisable()
        {
            if (brain != null) brain.OnPerformAttack -= PerformLeapAttack;
        }

        private void PerformLeapAttack()
        {
            if (isDead || isStaggered) return;

            if (bodyHitbox != null && enemyData != null)
            {
                DamageInfo payload = new DamageInfo(enemyData.BaseDamage, enemyData.PoiseDamage, gameObject);
                bodyHitbox.OpenHitbox(payload);
                Invoke(nameof(CloseSlimeHitbox), 0.6f);
            }
        }

        private void CloseSlimeHitbox()
        {
            if (bodyHitbox != null) bodyHitbox.CloseHitbox();
        }
    }
}
