using System.Collections;
using UnityEngine;
using UnityEngine.AI;
using KittenWarrior.Combat;

namespace KittenWarrior.Enemies
{
    /// <summary>
    /// Forest Goblin AI archetype: tactical spear fighter that maintains distance and thrusts forward.
    /// Owned by: Worker-2-CombatAI
    /// </summary>
    public class ForestGoblin : EnemyBase
    {
        [Header("Goblin Spear Equipment")]
        [SerializeField] private Hitbox spearHitbox;
        [SerializeField] private float tacticalPreferredDistance = 2.4f;
        [SerializeField] private float backstepDistance = 3.0f;

        private EnemyBrain brain;
        private NavMeshAgent agent;

        protected override void Awake()
        {
            base.Awake();
            brain = GetComponent<EnemyBrain>();
            agent = GetComponent<NavMeshAgent>();
            if (spearHitbox != null) spearHitbox.Initialize(gameObject);
        }

        private void OnEnable()
        {
            if (brain != null) brain.OnPerformAttack += ExecuteSpearThrust;
        }

        private void OnDisable()
        {
            if (brain != null) brain.OnPerformAttack -= ExecuteSpearThrust;
        }

        private void ExecuteSpearThrust()
        {
            if (isDead || isStunned) return;

            StartCoroutine(SpearThrustRoutine());
        }

        private IEnumerator SpearThrustRoutine()
        {
            // Activate spear hitbox
            if (spearHitbox != null && enemyData != null)
            {
                DamageInfo payload = new DamageInfo(
                    amount: enemyData.BaseDamage,
                    poiseDamage: enemyData.PoiseDamage,
                    attacker: gameObject,
                    knockbackForce: enemyData.KnockbackForce,
                    type: DamageType.Piercing
                );
                spearHitbox.OpenHitbox(payload);
            }

            yield return new WaitForSeconds(0.35f);

            if (spearHitbox != null)
            {
                spearHitbox.CloseHitbox();
            }

            // Tactical backstep to maintain distance
            if (brain.CurrentTarget != null && agent != null && agent.isOnNavMesh)
            {
                Vector3 retreatDir = (transform.position - brain.CurrentTarget.position).normalized;
                Vector3 retreatPos = transform.position + (retreatDir * backstepDistance);

                if (NavMesh.SamplePosition(retreatPos, out NavMeshHit hit, 2f, NavMesh.AllAreas))
                {
                    agent.SetDestination(hit.position);
                }
            }
        }
    }
}
