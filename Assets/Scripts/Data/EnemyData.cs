using UnityEngine;

namespace KittenWarrior.Data
{
    /// <summary>
    /// ScriptableObject defining monster parameters, stats, rewards, and loot drop references.
    /// Owned by: Worker-3-Systems
    /// </summary>
    [CreateAssetMenu(fileName = "NewEnemyData", menuName = "Kitten Warrior/Data/Enemy Data", order = 2)]
    public class EnemyData : ScriptableObject
    {
        [Header("Identity & Archetype")]
        [SerializeField] private string enemyName = "Forest Slime";

        [Header("Survival & Defense")]
        [Tooltip("Maximum hit points.")]
        [SerializeField] private float maxHp = 60f;

        [Tooltip("Defense value used in damage mitigation formula.")]
        [SerializeField] private float defense = 5f;

        [Tooltip("Maximum poise threshold before entering stunned state.")]
        [SerializeField] private float maxPoise = 25f;

        [Tooltip("Duration of stun/stagger state in seconds.")]
        [SerializeField] private float stunDuration = 1.0f;

        [Header("Offense")]
        [Tooltip("Base damage dealt to the player.")]
        [SerializeField] private float baseDamage = 14f;

        [Tooltip("Poise damage dealt to player guard.")]
        [SerializeField] private float poiseDamage = 12f;

        [Tooltip("Knockback force imparted on the player upon hitting.")]
        [SerializeField] private float knockbackForce = 5f;

        [Header("Locomotion & Sensory Ranges")]
        [Tooltip("Patrol movement speed.")]
        [SerializeField] private float patrolSpeed = 2.0f;

        [Tooltip("Chase movement speed when target is spotted.")]
        [SerializeField] private float moveSpeed = 4.5f;

        [Tooltip("Radius within which enemy detects the player.")]
        [SerializeField] private float detectionRadius = 10f;

        [Tooltip("Melee attack engagement distance.")]
        [SerializeField] private float attackRange = 1.6f;

        [Tooltip("Cooldown delay between consecutive attacks.")]
        [SerializeField] private float attackCooldown = 1.8f;

        [Header("Progression & Loot")]
        [Tooltip("Experience points awarded upon defeat.")]
        [SerializeField] private int expReward = 35;

        [Tooltip("Reference to the drop table ScriptableObject.")]
        [SerializeField] private DropTableData dropTable;

        // Public Accessors
        public string EnemyName => enemyName;
        public float MaxHp => maxHp;
        public float Defense => defense;
        public float MaxPoise => maxPoise;
        public float StunDuration => stunDuration;
        public float BaseDamage => baseDamage;
        public float PoiseDamage => poiseDamage;
        public float KnockbackForce => knockbackForce;
        public float PatrolSpeed => patrolSpeed;
        public float MoveSpeed => moveSpeed;
        public float DetectionRadius => detectionRadius;
        public float AttackRange => attackRange;
        public float AttackCooldown => attackCooldown;
        public int ExpReward => expReward;
        public DropTableData DropTable => dropTable;
    }
}
