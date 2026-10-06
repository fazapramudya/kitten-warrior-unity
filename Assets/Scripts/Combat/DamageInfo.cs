using UnityEngine;

namespace KittenWarrior.Combat
{
    public enum DamageType
    {
        Physical,
        Blunt,
        Piercing,
        Fire,
        Elemental
    }

    /// <summary>
    /// Data structure containing comprehensive hit information for combat interactions.
    /// Owned by: Leo (Combat Director)
    /// </summary>
    public struct DamageInfo
    {
        public float Amount;
        public float PoiseDamage;
        public DamageType Type;
        public Vector3 HitPoint;
        public Vector3 HitNormal;
        public GameObject Attacker;
        public bool IsCritical;
        public bool IsParryCounter;

        public DamageInfo(float amount, float poiseDamage, GameObject attacker, Vector3 hitPoint = default, Vector3 hitNormal = default, DamageType type = DamageType.Physical, bool isCritical = false, bool isParryCounter = false)
        {
            Amount = amount;
            PoiseDamage = poiseDamage;
            Attacker = attacker;
            HitPoint = hitPoint;
            HitNormal = hitNormal;
            Type = type;
            IsCritical = isCritical;
            IsParryCounter = isParryCounter;
        }
    }

    /// <summary>
    /// Interface for any entity capable of taking combat damage.
    /// </summary>
    public interface IDamageable
    {
        bool TakeDamage(DamageInfo damageInfo);
        bool IsDead { get; }
        Transform GetTransform();
    }
}
