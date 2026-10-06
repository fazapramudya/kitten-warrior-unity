# Kitten Warrior — Unity Editor Integration & Setup Guide
*Diproduksi oleh: Worker-4-QA-Reviewer (Code Reviewer & Integration Specialist)*

Panduan ini menjelaskan langkah demi langkah cara memasang skrip fondasi yang telah diproduksi oleh **Worker 1, 2, dan 3** ke dalam GameObject di Unity Editor.

---

## 1. Persiapan Layer & Tag (Project Settings)
Sebelum merangkai GameObject, pastikan Layer berikut sudah terdaftar di **Edit > Project Settings > Tags and Layers**:
- Layer 6: `Player`
- Layer 7: `Enemy`
- Layer 8: `Hitbox`
- Layer 9: `Hurtbox`
- Layer 10: `Environment` (untuk dinding, tanah, dan pepohonan)

Buka **Physics Manager** (**Edit > Project Settings > Physics**):
- Nonaktifkan tabrakan antara `Hitbox` dengan `Hitbox`.
- Pastikan `Hitbox` hanya menembus / mendeteksi `Hurtbox`.

---

## 2. Membuat Data ScriptableObject (Worker 3: Data)
Di jendela **Project**, buat folder `Assets/Settings/GameData/`:

1. **Weapon Data**:
   - Klik kanan di Project Window -> **Create > Kitten Warrior > Data > Weapon Data**.
   - Beri nama misalnya `Weapon_SteelClaws`.
   - Di Inspector, atur:
     - Base Damage: `25`
     - Attack Speed: `1.0`
     - Stamina Cost: `15`
     - Durability: `100`
     - Knockback Force: `6.5`
2. **Drop Table Data**:
   - Klik kanan -> **Create > Kitten Warrior > Data > Drop Table**.
   - Tambahkan item slime gel / goblin coin beserta drop chance (misal `0.8` untuk 80%).
3. **Enemy Data**:
   - Klik kanan -> **Create > Kitten Warrior > Data > Enemy Data**.
   - Buat untuk `Enemy_ForestSlime` (MaxHP: 60, BaseDamage: 14, MoveSpeed: 4.5).
   - Buat untuk `Enemy_ForestGoblin` (MaxHP: 85, BaseDamage: 18, MoveSpeed: 5.0).

---

## 3. Merangkai Player GameObject (Worker 1 & Worker 2)

1. Buat GameObject kosong di hierarchy, beri nama **`Player_KittenWarrior`**.
2. Set Tag & Layer ke **`Player`**.
3. Tambahkan komponen berikut di Inspector:
   - **`CharacterController`**:
     - Slope Limit: `45`
     - Step Offset: `0.3`
     - Skin Width: `0.08`
     - Min Move Distance: `0.001`
     - Center: `(0, 0.5, 0)`, Height: `1.0`, Radius: `0.35` (proporsi anak kucing).
   - **`StaminaSystem`** (`Assets/Scripts/Player/StaminaSystem.cs`):
     - Max Stamina: `100`
     - Base Regen Rate: `22`
     - Regen Delay: `1.25`
   - **`PlayerController`** (`Assets/Scripts/Player/PlayerController.cs`):
     - Walk Speed: `4.2`, Sprint Speed: `7.5`
     - Jump Height: `1.35`, Gravity: `-20`
     - Dodge Speed: `10.0`, Dodge Stamina Cost: `25`
     - Tarik **Main Camera** ke kolom `Camera Transform`.
   - **`CombatController`** (`Assets/Scripts/Combat/CombatController.cs`):
     - Max Health: `120`, Defense: `10`, Max Poise: `50`
     - Tarik asset `Weapon_SteelClaws` ke kolom `Current Weapon`.

4. **Setup Hitbox & Hurtbox Player**:
   - Buat child GameObject bernama **`Hurtbox`**:
     - Tambahkan `CapsuleCollider` (centang **Is Trigger**).
     - Tambahkan komponen `Hurtbox.cs` (`Assets/Scripts/Combat/Hurtbox.cs`).
     - Set Layer ke `Hurtbox`.
   - Di tangan/cakar model 3D kucing, buat child GameObject bernama **`WeaponHitbox`**:
     - Tambahkan `BoxCollider` atau `SphereCollider` (centang **Is Trigger**).
     - Tambahkan komponen `Hitbox.cs` (`Assets/Scripts/Combat/Hitbox.cs`).
     - Set Target Layers ke `Enemy` dan `Hurtbox`.
     - Tarik GameObject ini ke kolom `Weapon Hitbox` pada `CombatController`.

---

## 4. Setup Kamera Third-Person (Worker 1: Camera)

1. Pilih **Main Camera** di Hierarchy.
2. Tambahkan komponen **`ThirdPersonCamera`** (`Assets/Scripts/Camera/ThirdPersonCamera.cs`).
3. Konfigurasi Inspector:
   - **Target**: Tarik GameObject `Player_KittenWarrior`.
   - **Target Offset**: `(0, 0.9, 0)` (sejajar pandangan kucing).
   - **Default Distance**: `3.5` (min: `0.8`, max: `5.0`).
   - **Collision Layers**: Centang `Default`, `Environment`, `Terrain` (jangan centang Player).
   - **Collision Radius**: `0.2`.

---

## 5. Merangkai Musuh AI (Worker 2: Enemies)

### A. Forest Slime Prefab
1. Buat GameObject bernama **`Enemy_ForestSlime`**, pasang model 3D / sphere slime.
2. Tambahkan komponen:
   - **`NavMeshAgent`**: Base Offset: `0`, Speed: `4.5`, Stopping Distance: `1.2`.
   - **`Rigidbody`**: Use Gravity: `true`, Is Kinematic: `false`, Freeze Rotation XYZ.
   - **`EnemyBrain`** (`Assets/Scripts/Enemies/EnemyBrain.cs`): Target Layer: `Player`.
   - **`ForestSlime`** (`Assets/Scripts/Enemies/ForestSlime.cs`): Tarik asset `Enemy_ForestSlime` ke kolom `Enemy Data`.
   - Tambahkan child GameObject **`BodyHitbox`** dengan collider trigger dan script `Hitbox.cs`.

### B. Forest Goblin Prefab
1. Buat GameObject bernama **`Enemy_ForestGoblin`**.
2. Tambahkan komponen:
   - **`NavMeshAgent`**: Speed: `5.0`, Stopping Distance: `2.0`.
   - **`EnemyBrain`**: Target Layer: `Player`.
   - **`ForestGoblin`** (`Assets/Scripts/Enemies/ForestGoblin.cs`): Tarik asset `Enemy_ForestGoblin`.
   - Pasang child GameObject pada ujung tombak dengan collider trigger dan script `Hitbox.cs`.

---

## 6. Setup NavMesh & Environment (Valheim Atmosphere)

1. **NavMesh Baking**:
   - Pastikan lantai / terrain bertanda **Static (Navigation Static)**.
   - Buka **Window > AI > Navigation**, klik tab **Bake** -> klik tombol **Bake**.
2. **Pencahayaan Atmosferik**:
   - Pilih **Directional Light** utama (Matahari).
   - Pasang komponen **`AtmosphericLightingController`** (`Assets/Scripts/Core/AtmosphericLightingController.cs`).
   - Warna matahari akan otomatis di-tune ke nuansa *Golden Hour* hangat dengan kabut atmosferik ala Valheim.
3. **Core Managers**:
   - Buat GameObject kosong bernama **`_Managers`**.
   - Pasang komponen **`GameManager`** dan **`AudioManager`**.

---

## 7. Kontrol Default Game
- **W, A, S, D**: Bergerak (relatif terhadap arah kamera)
- **Mouse**: Mengarahkan kamera
- **Left Shift (Tahan)**: Sprint (menguras stamina)
- **Spasi**: Melompat
- **Left Ctrl / C**: Dodge Roll (menguras stamina)
- **Klik Kiri**: Serangan Kombo 3-Hit
- **Klik Kanan (Tahan)**: Menangkis (Block) / Parry (jika ditekan 0.22s sebelum serangan musuh mengenai tubuh)
- **Escape**: Pause / Resume game
