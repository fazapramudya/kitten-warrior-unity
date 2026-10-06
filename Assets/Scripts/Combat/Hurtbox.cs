using UnityEngine;

namespace KittenWarrior.Combat
{
    /// <summary>
    /// Hurtbox proxy component attached to character body parts.
    /// Routes incoming strikes to the parent IDamageable implementation.
    /// Owned by: Leo (Combat Director)
    /// </summary>
    [RequireComponent(typeof(Collider))]
    [DisallowMultipleComponent]
    public class Hurtbox : MonoBehaviour
    {
        [Header("Damage Multiplier")]
        [Tooltip("Multiplier for sensitive zones (e.g. 1.0 for body, 1.5 for head).")]
        [SerializeField] private float damageMultiplier = 1.0f;

        private IDamageable ownerDamageable;

        public IDamageable OwnerDamageable => ownerDamageable;
        public float DamageMultiplier => damageMultiplier;

        private void Awake()
        {
            ownerDamageable = GetComponentInParent<IDamageable>();
            if (ownerDamageable == null)
            {
                Debug.LogWarning($"[Hurtbox] No IDamageable found in parents of {gameObject.name}!");
            }
        }
    }
}
