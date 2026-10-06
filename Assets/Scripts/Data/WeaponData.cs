using UnityEngine;

namespace KittenWarrior.Data
{
    /// <summary>
    /// ScriptableObject defining weapon attributes, stamina consumption, attack speed, and durability.
    /// Owned by: Worker-3-Systems
    /// </summary>
    [CreateAssetMenu(fileName = "NewWeaponData", menuName = "Kitten Warrior/Data/Weapon Data", order = 1)]
    public class WeaponData : ScriptableObject
    {
        [Header("General Identity")]
        [SerializeField] private string weaponName = "Feline Steel Claws";
        [SerializeField] private Sprite weaponIcon;
        [SerializeField] private GameObject weaponPrefab;

        [Header("Offensive Attributes")]
        [Tooltip("Base damage dealt per hit.")]
        [SerializeField] private float baseDamage = 25f;

        [Tooltip("Attack speed multiplier affecting swing animation speed.")]
        [Range(0.5f, 3.0f)]
        [SerializeField] private float attackSpeed = 1.0f;

        [Tooltip("Multipliers for consecutive combo swings.")]
        [SerializeField] private float[] comboMultipliers = new float[] { 1.0f, 1.25f, 1.75f };

        [Tooltip("Knockback force imparted on hit targets.")]
        [SerializeField] private float knockbackForce = 6.5f;

        [Tooltip("Poise damage dealt to enemies to trigger stun/stagger.")]
        [SerializeField] private float poiseDamage = 20f;

        [Header("Stamina Economy")]
        [Tooltip("Stamina consumed per light attack swing.")]
        [SerializeField] private float staminaCost = 15f;

        [Tooltip("Stamina consumed per heavy attack swing.")]
        [SerializeField] private float heavyStaminaCost = 30f;

        [Tooltip("Stamina consumed when absorbing a blow via block.")]
        [SerializeField] private float blockStaminaCost = 12f;

        [Header("Durability")]
        [Tooltip("Maximum weapon durability before breaking or dulling.")]
        [SerializeField] private float maxDurability = 100f;

        [Tooltip("Durability lost per connecting strike.")]
        [SerializeField] private float durabilityLossPerHit = 0.5f;

        // Public Accessors
        public string WeaponName => weaponName;
        public Sprite WeaponIcon => weaponIcon;
        public GameObject WeaponPrefab => weaponPrefab;
        public float BaseDamage => baseDamage;
        public float AttackSpeed => attackSpeed;
        public float[] ComboMultipliers => comboMultipliers;
        public int MaxComboSteps => comboMultipliers != null ? comboMultipliers.Length : 1;
        public float KnockbackForce => knockbackForce;
        public float PoiseDamage => poiseDamage;
        public float StaminaCost => staminaCost;
        public float HeavyStaminaCost => heavyStaminaCost;
        public float BlockStaminaCost => blockStaminaCost;
        public float MaxDurability => maxDurability;
        public float DurabilityLossPerHit => durabilityLossPerHit;

        public float GetComboDamage(int comboIndex)
        {
            if (comboMultipliers == null || comboMultipliers.Length == 0) return baseDamage;
            int clamped = Mathf.Clamp(comboIndex, 0, comboMultipliers.Length - 1);
            return baseDamage * comboMultipliers[clamped];
        }
    }
}
