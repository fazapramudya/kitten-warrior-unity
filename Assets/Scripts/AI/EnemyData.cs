using UnityEngine;

namespace KittenWarrior.AI
{
    public enum EnemyTier
    {
        Common,
        Elite,
        Boss
    }

    /// <summary>
    /// ScriptableObject defining baseline stats, sensory parameters, and attack profiles for enemies.
    /// Owned by: Grimm (Enemy AI Architect)
    /// </summary>
    [CreateAssetMenu(fileName = "NewEnemyData", menuName = "Kitten Warrior/AI/Enemy Data", order = 2)]
    public class EnemyData : ScriptableObject
    {
        [Header("Identity")]
        [SerializeField] private string enemyName = "Forest Goblin";
        [SerializeField] private EnemyTier tier = EnemyTier.Common;

        [Header("Attributes")]
        [SerializeField] private float maxHealth = 75f;
        [SerializeField] private float maxPoise = 30f;
        [SerializeField] private float baseDamage = 18f;
        [SerializeField] private float poiseDamage = 15f;

        [Header("Locomotion & NavMesh")]
        [SerializeField] private float patrolSpeed = 2.2f;
        [SerializeField] private float chaseSpeed = 5.2f;
        [SerializeField] private float patrolRadius = 8f;

        [Header("Senses & Combat Range")]
        [SerializeField] private float detectionRadius = 12f;
        [SerializeField] private float fieldOfViewAngle = 120f;
        [SerializeField] private float attackRange = 1.8f;
        [SerializeField] private float attackCooldown = 1.6f;
        [SerializeField] private float staggerDuration = 0.9f;

        // Public Accessors
        public string EnemyName => enemyName;
        public EnemyTier Tier => tier;
        public float MaxHealth => maxHealth;
        public float MaxPoise => maxPoise;
        public float BaseDamage => baseDamage;
        public float PoiseDamage => poiseDamage;
        public float PatrolSpeed => patrolSpeed;
        public float ChaseSpeed => chaseSpeed;
        public float PatrolRadius => patrolRadius;
        public float DetectionRadius => detectionRadius;
        public float FieldOfViewAngle => fieldOfViewAngle;
        public float AttackRange => attackRange;
        public float AttackCooldown => attackCooldown;
        public float StaggerDuration => staggerDuration;
    }
}
