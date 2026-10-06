using System.Collections;
using UnityEngine;
using KittenWarrior.Combat;

namespace KittenWarrior.Enemies
{
    /// <summary>
    /// Forest Slime AI archetype: bounces and hops towards the kitten, performing lunge bumps and impact bursts.
    /// Owned by: Worker-2-CombatAI
    /// </summary>
    public class ForestSlime : EnemyBase
    {
        [Header("Slime Mechanics")]
        [SerializeField] private Hitbox bodyHitbox;
        [SerializeField] private float leapHopForce = 6.5f;
        [SerializeField] private ParticleSystem impactBurstParticles;

        private EnemyBrain brain;
        private Rigidbody rb;

        protected override void Awake()
        {
            base.Awake();
            brain = GetComponent<EnemyBrain>();
            rb = GetComponent<Rigidbody>();
            if (bodyHitbox != null) bodyHitbox.Initialize(gameObject);
        }

        private void OnEnable()
        {
            if (brain != null) brain.OnPerformAttack += ExecuteLungeImpact;
        }

        private void OnDisable()
        {
            if (brain != null) brain.OnPerformAttack -= ExecuteLungeImpact;
        }

        private void ExecuteLungeImpact()
        {
            if (isDead || isStunned) return;

            StartCoroutine(LungeRoutine());
        }

        private IEnumerator LungeRoutine()
        {
            // Slime squashes and hops forward towards target
            if (brain.CurrentTarget != null)
            {
                Vector3 leapDir = (brain.CurrentTarget.position - transform.position).normalized;
                leapDir.y = 0.4f;

                if (rb != null && !rb.isKinematic)
                {
                    rb.AddForce(leapDir.normalized * leapHopForce, ForceMode.Impulse);
                }
            }

            // Open body contact hitbox
            if (bodyHitbox != null && enemyData != null)
            {
                DamageInfo payload = new DamageInfo(
                    amount: enemyData.BaseDamage,
                    poiseDamage: enemyData.PoiseDamage,
                    attacker: gameObject,
                    knockbackForce: enemyData.KnockbackForce
                );
                bodyHitbox.OpenHitbox(payload);
            }

            yield return new WaitForSeconds(0.45f);

            if (impactBurstParticles != null)
            {
                impactBurstParticles.Play();
            }

            if (bodyHitbox != null)
            {
                bodyHitbox.CloseHitbox();
            }
        }
    }
}
