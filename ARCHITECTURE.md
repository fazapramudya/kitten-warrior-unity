# Kitten Warrior — Architecture & Engineering Specification

## 1. Team & Specialist Workers (Hermes 3D)

Proyek ini diorkestrasi oleh **Hermes (Technical Director & Orchestrator)** dengan 4 AI Specialist Workers yang terhubung langsung di Hermes 3D:

| Specialist Worker | Handle ID | Domain & Tanggung Jawab | File & Modul Utama |
|---|---|---|---|
| **Felix** | `felix-gameplay` | Character Locomotion, Stamina Dynamics, Camera System | `Assets/Scripts/Gameplay/` (`PlayerController.cs`, `StaminaSystem.cs`, `ThirdPersonCamera.cs`) |
| **Leo** | `leo-combat` | Tactical Combat, Hitbox/Hurtbox, Combos, Parry Timing | `Assets/Scripts/Combat/` (`CombatController.cs`, `Hitbox.cs`, `Hurtbox.cs`, `WeaponData.cs`, `DamageInfo.cs`) |
| **Grimm** | `grimm-ai` | Enemy AI FSM, Navigation, Archetypes & Boss Encounters | `Assets/Scripts/AI/` (`EnemyBrain.cs`, `EnemyBase.cs`, `EnemyData.cs`, `Enemies/*.cs`) |
| **Luna** | `luna-systems` | Architecture Backbone, URP Atmosphere, Audio & Events | `Assets/Scripts/Core/` (`GameManager.cs`, `GameEvents.cs`, `AtmosphericLightingController.cs`, `AudioManager.cs`) |

---

## 2. Diagram Alur & Interaksi Modul

```
[ User Input ]
      │
      ▼
[ PlayerController ] ◄────────► [ StaminaSystem ] (Valheim Pool & Recovery)
      │                                │
      ▼                                ▼
[ CombatController ] ──────────► [ TryConsumeStamina ]
      │
      ├─► [ Hitbox (Weapon) ] ───► [ Hurtbox / IDamageable ] ──► [ EnemyBase ]
      │                                                               ▲
      └─► [ Parry Window (0.22s) ] ◄── Incoming Enemy Strike          │
                                                                 [ EnemyBrain ] (FSM)
                                                                      │
                                                           [ NavMeshAgent Navigation ]
```

---

## 3. Spesifikasi Mekanik Kunci (Valheim-Style)

### A. Stamina Dynamics (`StaminaSystem.cs`)
- **Maksimum**: 100 Stamina
- **Regenerasi**: 22 Stamina / detik
- **Regen Delay**: 1.25 detik jeda setelah konsumsi terakhir
- **Exhaustion State**: Jika stamina mencapai 0, karakter masuk kondisi lelah dan tidak bisa melakukan aksi berat hingga pulih minimal 25%.
- **Action Costs**:
  - Sprint: 14 / detik
  - Jump: 15
  - Dodge-Roll: 25
  - Light Attack: 16
  - Heavy Attack: 32
  - Block: 12

### B. Combat & Parry Timing (`CombatController.cs` & `WeaponData.cs`)
- **Light Combo**: 3-step chain dengan damage multiplier (1.0x -> 1.25x -> 1.75x).
- **Parry Window**: 0.22 detik sesaat setelah mengangkat guard. Parry sukses membatalkan 100% damage dan memberikan 100 poise damage (instant stagger) ke musuh penyerang.
- **Block**: Mengurangi 75% damage masuk dengan mengonsumsi stamina. Jika stamina habis saat menangkis, player mengalami guard-break stagger (1.2 detik).

### C. Enemy Archetypes (`Assets/Scripts/AI/Enemies/`)
1. **Forest Slime** (`ForestSlime.cs`): Lincah, serangan lompat (leap attack), damage ringan.
2. **Goblin Spearman** (`GoblinSpearman.cs`): Jarak menengah, tusukan tombak piercing, menjaga jarak taktis.
3. **Forest Troll Boss** (`ForestTrollBoss.cs`): Musuh raksasa dengan serangan Ground Slam AoE (radius 4.5m), shockwave partikel, dan poise tinggi.

---

## 4. Standar Kode & Performa
- **Zero-Allocation**: Menggunakan `HashSet<IDamageable>` reuse, struct `DamageInfo`, dan C# static events tanpa alokasi garbage collection di runtime combat loop.
- **ScriptableObject-Driven**: Data persenjataan (`WeaponData`) dan konfigurasi musuh (`EnemyData`) terpisah murni dari logic sehingga mudah di-tune oleh designer di Unity Inspector.
- **URP Lighting Ready**: Kontrol terpusat untuk pencahayaan golden hour, soft shadow, dan kabut atmosferik (`AtmosphericLightingController.cs`).
