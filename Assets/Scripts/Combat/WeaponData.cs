using UnityEngine;

namespace KittenWarrior.Combat
{
    /// <summary>
    /// ScriptableObject defining weapon statistics, combo parameters, and stamina costs.
    /// Owned by: Leo (Combat Director)
    /// </summary>
    [CreateAssetMenu(fileName = "NewWeaponData", menuName = "Kitten Warrior/Combat/Weapon Data", order = 1)]
    public class WeaponData : ScriptableObject
    {
        [Header("Weapon Identity")]
        [SerializeField] private string weaponName = "Rusty Iron Shortsword";
        [SerializeField] private DamageType damageType = DamageType.Physical;
        [SerializeField] private Sprite icon;
        [SerializeField] private GameObject weaponPrefab;

        [Header("Offensive Statistics")]
        [Tooltip("Base damage dealt on light attack 1.")]
        [SerializeField] private float baseDamage = 25f;

        [Tooltip("Damage multiplier per consecutive combo hit.")]
        [SerializeField] private float[] comboMultipliers = new float[] { 1.0f, 1.25f, 1.75f };

        [Tooltip("Poise damage inflicted on enemies to trigger stagger.")]
        [SerializeField] private float poiseDamage = 18f;

        [Tooltip("Critical strike multiplier on parry counter-attacks.")]
        [SerializeField] private float parryCounterMultiplier = 2.5f;

        [Header("Stamina Consumption (Valheim Mechanics)")]
        [SerializeField] private float lightAttackStaminaCost = 16f;
        [SerializeField] private float heavyAttackStaminaCost = 32f;
        [SerializeField] private float blockStaminaCost = 12f;

        [Header("Timing Windows")]
        [Tooltip("Max window in seconds to chain the next combo strike.")]
        [SerializeField] private float comboWindow = 0.85f;

        [Tooltip("Parry window duration in seconds right after raising block.")]
        [SerializeField] private float parryWindow = 0.22f;

        [Tooltip("Hit-stop freeze duration on connecting hit.")]
        [SerializeField] private float hitStopDuration = 0.06f;

        // Public Accessors
        public string WeaponName => weaponName;
        public DamageType DamageType => damageType;
        public Sprite Icon => icon;
        public GameObject WeaponPrefab => weaponPrefab;
        public float BaseDamage => baseDamage;
        public float[] ComboMultipliers => comboMultipliers;
        public int MaxComboSteps => comboMultipliers.Length;
        public float PoiseDamage => poiseDamage;
        public float ParryCounterMultiplier => parryCounterMultiplier;
        public float LightAttackStaminaCost => lightAttackStaminaCost;
        public float HeavyAttackStaminaCost => heavyAttackStaminaCost;
        public float BlockStaminaCost => blockStaminaCost;
        public float ComboWindow => comboWindow;
        public float ParryWindow => parryWindow;
        public float HitStopDuration => hitStopDuration;

        public float GetComboDamage(int comboIndex)
        {
            if (comboMultipliers == null || comboMultipliers.Length == 0) return baseDamage;
            int clamped = Mathf.Clamp(comboIndex, 0, comboMultipliers.Length - 1);
            return baseDamage * comboMultipliers[clamped];
        }
    }
}
