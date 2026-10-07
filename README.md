# Kitten Warrior

> **3D Stylized Action RPG with Nordic Atmosphere, Stamina Combat & Tactical Arsenal**

[![Latest Release](https://img.shields.io/badge/Release-v0.4.0--vertical--slice-success?style=for-the-badge&logo=github)](https://github.com/fazapramudya/kitten-warrior-unity/releases/tag/v0.4.0-vertical-slice)
[![Godot 4.3](https://img.shields.io/badge/Engine-Godot%204.3-blue?style=for-the-badge&logo=godotengine)](https://godotengine.org)

---

### 🎮 Unduh & Mainkan (Download & Play)

| Platform | Format | Ukuran | Tautan Unduhan Langsung |
| :--- | :--- | :--- | :--- |
| **Windows x64 (Rekomendasi)** | `.ZIP` (Godot 4 Standalone `.exe` + `.pck`) | **71.4 MB** | [⬇️ Unduh KittenWarrior-Godot4-Windows-x64.zip](https://github.com/fazapramudya/kitten-warrior-unity/releases/download/v0.4.0-vertical-slice/KittenWarrior-Godot4-Windows-x64.zip) |
| **Web Browser Prototype** | HTML5 / Three.js (Playable Online) | — | [🌐 Buka Prototipe Web (Port 8080)](http://100.75.205.65:8080/) |
| **Desktop Web Wrapper** | `.ZIP` (Electron Standalone) | 114.8 MB | [⬇️ Unduh KittenWarrior-WebDesktop-Windows-x64.zip](https://github.com/fazapramudya/kitten-warrior-unity/releases/download/v0.4.0-vertical-slice/KittenWarrior-WebDesktop-Windows-x64.zip) |

#### Cara Menjalankan:
1. Unduh **`KittenWarrior-Godot4-Windows-x64.zip`** dari tautan di atas.
2. Ekstrak file zip ke folder pilihan Anda.
3. Klik ganda **`KittenWarrior.exe`** untuk langsung bermain!

---

## 🐾 Tentang Kitten Warrior
**Kitten Warrior** adalah game 3D Action RPG fantasi ksatria kucing tangguh dengan gameplay pertarungan berbobot, manajemen stamina taktis, dan atmosfer rimba yang terinspirasi dari filosofi desain *Valheim*.

### ⚔️ Fitur Utama (Vertical Slice):
- **Player Animation & Alive Dynamics**:
  * Napas alami (procedural breathing), gerakan ekor dinamis, dan kedipan telinga kucing.
  * Movement blending halus tanpa efek meluncur (foot sliding).
  * 4-Way Directional Dodge Roll (Maju, Mundur, Kiri, Kanan).
- **Combat Impact Pipeline**:
  * Siklus serangan 3-tahap: *Anticipation windup* → *Active hitbox window* → *Recovery*.
  * *Hit-stop crunchy micro-freeze*, getaran kamera terarah (*camera trauma shake*), dan percikan bunga api (*impact sparks*).
  * Sistem *timed parry* dan *posture stagger* (2x critical damage window).
- **Arsenal Tempur Lengkap**:
  * `[1]` Sword & Shield (Slashing)
  * `[2]` Flint Spear (Piercing)
  * `[3]` War Club (Blunt)
  * `[4]` Finewood Bow (Piercing Ranged dengan fisika balistik panah)
- **Living Enemy AI**:
  * Skeleton & Goblin berpatroli secara natural di sekitar habitatnya.
  * Deteksi waspada (`❗ ALERT`) dan telegraph serangan terbaca (`⚔️`).
  * Reaksi benturan fisik (*flinch squash & stretch*) dan animasi tumbang saat tewas.
- **Cinematic Environment & Lighting**:
  * Kontur bukit bergelombang, komposisi foreground-midground-background.
  * Pencahayaan matahari keemasan Nordik, ACES tone mapping, dan kabut volumetrik berkilau.
- **Diegetic Minimal HUD**:
  * Bar darah crimson dengan *ghost damage lag bar*, indikator buff makanan, dan retikel minimalis.

---

## 🛠️ Tech Stack & Engine
- **Engine**: Godot Engine 4.3 (GL-compatibility / Forward+)
- **Bahasa**: GDScript 2.0
- **Aset 3D**: KayKit Medieval Fantasy GLB Modular Assets (Licensed CC0)
- **CI / CD**: GitHub Actions Auto-Packaging Standalone Windows x64 Binary (`KittenWarrior.exe` + `KittenWarrior.pck`)

---

## Kontrol Permainan
- `W` `A` `S` `D`: Bergerak
- `Shift`: Sprint
- `Spasi`: Lompat
- `Q`: Dodge Roll (Gulingan terarah)
- `Klik Kiri (LMB)`: Serang / Tembak Panah
- `Tahan LMB`: Charged Heavy Attack / Tarik Busur
- `Klik Kanan (RMB)`: Block / Timed Parry
- `1` `2` `3` `4`: Ganti Senjata (Pedang / Tombak / Gada / Busur)
- `E`: Berinteraksi (Altar Persembahan Boss)
