# Kitten Warrior — Architecture & Engineering Specification

## 1. Tim & Worker Spesialis (Hermes 3D Virtual Office)

Proyek ini diorkestrasi oleh **Hermes (Technical Director & Orchestrator)** dengan 4 worker spesialis yang aktif di kantor virtual Hermes 3D:

| Worker Tag | Domain & Peran | Direktori Standar | Tanggung Jawab Utama |
|---|---|---|---|
| **`Worker-1-Gameplay`** | Lead Gameplay & Character Engineer | `Assets/Scripts/Player/`<br>`Assets/Scripts/Camera/` | Kontrol karakter feline third-person, Walk, Sprint (stamina drain), Jump, Dodge-Roll, dan orbit kamera anti-clip. |
| **`Worker-2-CombatAI`** | Combat & Monster AI Specialist | `Assets/Scripts/Combat/`<br>`Assets/Scripts/Enemies/` | FSM musuh (Idle, Patrol, Chase, Attack, Stunned, Dead), AI Slime & Goblin, Hitbox/Hurtbox, parry window, dan efek knockback. |
| **`Worker-3-Systems`** | Systems, Stats & Balance Architect | `Assets/Scripts/Core/`<br>`Assets/Scripts/Data/` | ScriptableObject arsitektur (`WeaponData`, `EnemyData`, `DropTableData`), formula matematika balancing (stamina, regenerasi, kalkulasi damage Attack vs Defense). |
| **`Worker-4-QA-Reviewer`** | QA, Code Reviewer & Git Orchestrator | Root Repository | QA & standardisasi kode C#, verifikasi .gitignore, orkestrasi Git commits, serta pembuatan panduan integrasi Editor (`SETUP_GUIDE.md`). |

---

## 2. Struktur Direktori Kode Unity
```
kitten-warrior-unity/
├── Assets/
│   ├── Scripts/
│   │   ├── Player/        # Worker 1: PlayerController.cs, StaminaSystem.cs
│   │   ├── Camera/        # Worker 1: ThirdPersonCamera.cs
│   │   ├── Combat/        # Worker 2: CombatController.cs, Hitbox.cs, Hurtbox.cs, DamageInfo.cs
│   │   ├── Enemies/       # Worker 2: EnemyBase.cs, EnemyBrain.cs, ForestSlime.cs, ForestGoblin.cs
│   │   ├── Core/          # Worker 3: GameManager.cs, GameEvents.cs, BalancingFormulas.cs, AtmosphericLightingController.cs, AudioManager.cs
│   │   └── Data/          # Worker 3: WeaponData.cs, EnemyData.cs, DropTableData.cs (ScriptableObjects)
│   └── Settings/          # Project Settings & URP Presets
├── ARCHITECTURE.md        # Spesifikasi teknis arsitektur
├── SETUP_GUIDE.md         # Panduan pemasangan GameObject di Unity Editor
└── README.md              # Visi game & ringkasan proyek
```

---

## 3. Formula Matematika Balancing (Worker 3)

### A. Kalkulasi Kerusakan (Attack vs Defense)
Formula menggunakan konstanta resistensi untuk mencegah nilai negatif dan memberikan *diminishing returns*:
$$\text{EffectiveDamage} = \text{RawDamage} \times \frac{50}{50 + \text{Defense}}$$

### B. Regenerasi Stamina & Efek Kelelahan (Valheim Style)
- Kondisi normal: 22 stamina/detik setelah jeda 1.25 detik.
- Bonus Shelter / Resting: $1.5\times$ kecepatan regenerasi.
- Exhaustion penalty: Jika stamina habis ($0$), regenerasi melambat menjadi $0.6\times$ dan aksi tempur dikunci hingga stamina kembali ke $25\%$.

---

## 4. Checklist Kualitas & Review Kode (Worker 4)
- **Garbage Collection Friendly**: Menggunakan struct `DamageInfo`, reuse `HashSet<IDamageable>` pada hitbox, dan static event channels tanpa alokasi memori berulang di loop `Update()`.
- **Konvensi Penamaan**: `PascalCase` untuk kelas, antarmuka, dan method publik; `camelCase` untuk field privat dan parameter fungsi.
- **Integritas Git**: File cache Unity (`Library/`, `Temp/`, `.vs/`) diabaikan secara ketat oleh `.gitignore`.
