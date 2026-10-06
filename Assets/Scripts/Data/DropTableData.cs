using System;
using UnityEngine;

namespace KittenWarrior.Data
{
    [Serializable]
    public struct DropItem
    {
        [Tooltip("Name or identifier of the drop item.")]
        public string ItemName;

        [Tooltip("Prefab instantiated when dropped in the world.")]
        public GameObject ItemPrefab;

        [Range(0f, 1f)]
        [Tooltip("Drop probability percentage (0.0 = 0%, 1.0 = 100%).")]
        public float DropChance;

        [Tooltip("Minimum quantity dropped.")]
        public int MinQuantity;

        [Tooltip("Maximum quantity dropped.")]
        public int MaxQuantity;
    }

    /// <summary>
    /// ScriptableObject defining loot drop tables for defeated monsters.
    /// Owned by: Worker-3-Systems
    /// </summary>
    [CreateAssetMenu(fileName = "NewDropTable", menuName = "Kitten Warrior/Data/Drop Table", order = 10)]
    public class DropTableData : ScriptableObject
    {
        [Header("Drop Table Configuration")]
        [SerializeField] private DropItem[] dropItems;

        public DropItem[] DropItems => dropItems;
    }
}
