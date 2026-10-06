using System;
using System.Collections.Generic;
using UnityEngine;

namespace KittenWarrior.Combat
{
    /// <summary>
    /// Active weapon hitbox script. Detects collisions with Hurtbox/IDamageable.
    /// Tracks hit targets per swing to guarantee single-hit registration per target.
    /// Owned by: Leo (Combat Director)
    /// </summary>
    [RequireComponent(typeof(Collider))]
    [DisallowMultipleComponent]
    public class Hitbox : MonoBehaviour
    {
        [Header("Hitbox Setup")]
        [SerializeField] private Collider hitCollider;
        [SerializeField] private LayerMask targetLayers = ~0;

        private GameObject owner;
        private DamageInfo currentDamageInfo;
        private readonly HashSet<IDamageable> hitEntities = new HashSet<IDamageable>();
        private bool isHitboxActive;

        public event Action<IDamageable, DamageInfo> OnHitRegistered;

        private void Awake()
        {
            if (hitCollider == null) hitCollider = GetComponent<Collider>();
            hitCollider.isTrigger = true;
            hitCollider.enabled = false;
        }

        public void Initialize(GameObject attacker)
        {
            owner = attacker;
        }

        /// <summary>
        /// Activates the hitbox for the duration of a swing animation event.
        /// </summary>
        public void OpenHitbox(DamageInfo damagePayload)
        {
            currentDamageInfo = damagePayload;
            currentDamageInfo.Attacker = owner;
            hitEntities.Clear();
            isHitboxActive = true;
            hitCollider.enabled = true;
        }

        /// <summary>
        /// Closes the hitbox at the recovery phase of the attack.
        /// </summary>
        public void CloseHitbox()
        {
            isHitboxActive = false;
            hitCollider.enabled = false;
            hitEntities.Clear();
        }

        private void OnTriggerEnter(Collider other)
        {
            if (!isHitboxActive) return;

            // Check layer mask
            if (((1 << other.gameObject.layer) & targetLayers) == 0) return;

            // Avoid self-damage
            if (owner != null && (other.gameObject == owner || other.transform.IsChildOf(owner.transform)))
            {
                return;
            }

            // Check Hurtbox or IDamageable
            if (other.TryGetComponent<Hurtbox>(out var hurtbox))
            {
                ProcessHit(hurtbox.OwnerDamageable, other.ClosestPoint(transform.position));
            }
            else if (other.TryGetComponent<IDamageable>(out var damageable))
            {
                ProcessHit(damageable, other.ClosestPoint(transform.position));
            }
        }

        private void ProcessHit(IDamageable target, Vector3 contactPoint)
        {
            if (target == null || target.IsDead) return;

            // Ensure one hit per entity per swing
            if (hitEntities.Contains(target)) return;

            hitEntities.Add(target);

            DamageInfo hitData = currentDamageInfo;
            hitData.HitPoint = contactPoint;
            hitData.HitNormal = (transform.position - contactPoint).normalized;

            bool wasDamaged = target.TakeDamage(hitData);
            if (wasDamaged)
            {
                OnHitRegistered?.Invoke(target, hitData);
            }
        }
    }
}
