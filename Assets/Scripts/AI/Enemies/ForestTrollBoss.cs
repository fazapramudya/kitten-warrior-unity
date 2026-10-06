using System;
using UnityEngine;
using KittenWarrior.Combat;

namespace KittenWarrior.AI.Enemies
{
    /// <summary>
    /// Forest Troll Boss archetype: massive heavy-hitting boss with AoE club slam and high poise.
    /// Owned by: Grimm (Enemy AI Architect)
    /// </summary>
    public class ForestTrollBoss : EnemyBase
    {
        [Header("Boss AoE Slam")]
        [SerializeField] private Transform groundSlamPoint;
        [SerializeField] private float slamRadius = 4.5f;
        [SerializeField] private LayerMask playerLayer;
        [SerializeField] private ParticleSystem slamShockwaveParticles;

        private EnemyBrain brain;

        public event Action OnBossRoar;
        public event Action OnBossGroundSlam;

        protected override void Awake()
        {
            base.Awake();
            brain = GetComponent<EnemyBrain>();
        }

        private void OnEnable()
        {
            if (brain != null) brain.OnPerformAttack += PerformSlamAttack;
        }

        private void OnDisable()
        {
            if (brain != null) brain.OnPerformAttack -= PerformSlamAttack;
        }

        private void PerformSlamAttack()
        {
            if (isDead || isStaggered) return;

            OnBossGroundSlam?.Invoke();

            if (slamShockwaveParticles != null)
            {
                slamShockwaveParticles.Play();
            }

            Vector3 center = groundSlamPoint != null ? groundSlamPoint.position : transform.position + transform.forward * 2f;
            Collider[] hits = Physics.OverlapSphere(center, slamRadius, playerLayer);

            for (int i = 0; i < hits.Length; i++)
            {
                if (hits[i].TryGetComponent<IDamageable>(out var target))
                {
                    DamageInfo payload = new DamageInfo(
                        enemyData != null ? enemyData.BaseDamage : 45f,
                        enemyData != null ? enemyData.PoiseDamage : 40f,
                        gameObject,
                        hitPoint: hits[i].ClosestPoint(center),
                        type: DamageType.Blunt
                    );
                    target.TakeDamage(payload);
                }
            }
        }

        private void OnDrawGizmosSelected()
        {
            Gizmos.color = Color.red;
            Vector3 center = groundSlamPoint != null ? groundSlamPoint.position : transform.position + transform.forward * 2f;
            Gizmos.DrawWireSphere(center, slamRadius);
        }
    }
}
