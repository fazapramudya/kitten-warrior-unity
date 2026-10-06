# Kitten Warrior

> **3D Action RPG with Valheim-style stamina & atmospheric combat**

## Vision
**Kitten Warrior** adalah game 3D Action RPG yang menggabungkan estetika petualang kucing yang tangguh dengan gameplay pertarungan berbasis stamina yang taktis dan atmosferik ala *Valheim*. Pemain menjelajahi dunia luas yang penuh misteri, menghadapi musuh-musuh menantang, serta mengelola stamina dengan cermat saat menyerang, menangkis, dan menghindar.

## Core Features
- **Valheim-Style Stamina System**: Setiap tindakan (serangan ringan, serangan berat, menghindar, lari, dan bertahan) menguras stamina. Manajemen ritme stamina menjadi kunci kelangsungan hidup.
- **Atmospheric Combat**: Pertarungan berbobot dengan sistem hit-stop, stagger, dan responsivitas tinggi di lingkungan dinamis.
- **Feline Agility & Combat Arts**: Karakter utama kucing dengan kelincahan khas, kemampuan manuver, serta persenjataan miniatur yang mematikan.
- **Atmospheric World**: Pencahayaan dinamis, efek cuaca, dan ambience suara imersif yang membangun nuansa petualangan liar.

## Tech Stack
- **Engine**: Unity 2022+ / Unity 6
- **Language**: C#
- **Render Pipeline**: Universal Render Pipeline (URP)

## Project Structure
```
kitten-warrior-unity/
├── Assets/
│   ├── Scripts/       # Core game scripts & logic
│   ├── Prefabs/       # Player, enemy, & environment prefabs
│   ├── Scenes/        # Game & prototype scenes
│   ├── Art/           # 3D models, textures, animations, & materials
│   └── Audio/         # SFX & ambient music
├── ProjectSettings/   # Unity project configuration
└── Packages/          # Package dependencies
```

## Setup & Development
1. Clone repositori ini:
   ```bash
   git clone <repo-url>
   cd kitten-warrior-unity
   ```
2. Buka folder proyek menggunakan **Unity Hub** dengan versi Unity yang sesuai.
3. Buka scene awal di `Assets/Scenes/Main.unity`.
