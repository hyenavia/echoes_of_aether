\# ECHOES OF AETHER

\## GAME DESIGN DOCUMENT (GDD)



\*\*Document Version:\*\* 1.0  

\*\*Project:\*\* Echoes of Aether  

\*\*Genre:\*\* Idle Dungeon RPG / Fantasy Adventure  

\*\*Platform:\*\* Android (Primary), iOS (Future Consideration)  

\*\*Game Mode:\*\* Single-player, Offline-first  

\*\*Visual Style:\*\* 2D Top-down Pixel Art  

\*\*Combat Style:\*\* Real-time Automatic Combat  

\*\*Document Status:\*\* Initial Design Baseline



\---



\# 1. GAME OVERVIEW



\## 1.1 Game Concept



Echoes of Aether adalah game Idle Dungeon RPG dengan tema fantasy adventure, menggunakan visual 2D top-down pixel art.



Pemain mengendalikan satu karakter utama yang menjelajahi dungeon secara otomatis, menghadapi berbagai monster, mengumpulkan equipment, meningkatkan kemampuan, dan mengembangkan karakter melalui sistem class specialization.



Game berfokus pada progression, equipment optimization, skill synergy, dungeon exploration, dan pengembangan karakter secara bertahap.



Pemain tidak perlu mengendalikan pergerakan maupun serangan secara manual. Karakter akan mengambil keputusan berdasarkan sistem AI dan konfigurasi gameplay.



\## 1.2 Core Pillars



1\. \*\*Automatic Adventure\*\* — Karakter bergerak dan bertarung secara otomatis.

2\. \*\*Meaningful Progression\*\* — Setiap dungeon memberikan kesempatan untuk meningkatkan karakter.

3\. \*\*Class Identity\*\* — Specialization memberikan identitas dan gaya bermain berbeda.

4\. \*\*Equipment Optimization\*\* — Pemilihan equipment dan kombinasi atribut memengaruhi efektivitas karakter.

5\. \*\*Dungeon Exploration\*\* — Setiap dungeon memiliki ruangan, monster, elite, dan boss.

6\. \*\*Offline-friendly Experience\*\* — Progression tetap dapat diperoleh ketika pemain tidak membuka game, dengan batas simulasi tertentu.



\## 1.3 Target Experience



Pemain diharapkan merasakan:



\- Kepuasan melihat karakter semakin kuat.

\- Keseruan menemukan equipment yang lebih baik.

\- Perbedaan gaya bermain berdasarkan specialization.

\- Progres dungeon yang konsisten.

\- Pengalaman bermain santai tanpa kontrol manual yang kompleks.



\---



\# 2. CORE GAMEPLAY LOOP



\## 2.1 Primary Gameplay Loop



1\. Pemain masuk ke dungeon.

2\. Karakter otomatis memasuki room.

3\. Karakter mendeteksi monster.

4\. Karakter bergerak menuju target.

5\. Karakter melakukan auto attack dan auto skill.

6\. Monster dikalahkan.

7\. Pemain memperoleh EXP, gold, dan kemungkinan loot.

8\. Karakter melanjutkan ke room berikutnya.

9\. Pemain menghadapi elite atau boss.

10\. Pemain memperoleh reward dan melanjutkan progression.



\## 2.2 Meta Gameplay Loop



1\. Mengumpulkan reward dungeon.

2\. Meningkatkan level karakter.

3\. Mengembangkan skill.

4\. Memilih atau mengembangkan specialization.

5\. Mengganti dan meningkatkan equipment.

6\. Menghadapi dungeon dengan tingkat kesulitan lebih tinggi.



\---



\# 3. PLAYER CHARACTER



\## 3.1 Character Structure



Game menggunakan satu karakter utama.



Karakter tersebut dapat dikembangkan melalui sistem class specialization. Specialization bukan karakter terpisah, melainkan jalur pengembangan kemampuan dari karakter yang sama.



\## 3.2 Character Attributes



Atribut karakter:



| Attribute | Description |

|---|---|

| HP | Jumlah health karakter |

| ATK | Kekuatan serangan |

| DEF | Pengurangan damage yang diterima |

| ASPD | Attack speed |

| CRIT Rate | Peluang critical hit |

| CRIT Damage | Pengali damage critical |

| Move Speed | Kecepatan pergerakan |

| Attack Range | Jangkauan serangan |

| Skill Haste | Pengurangan cooldown skill |



\## 3.3 Level Progression



Karakter memperoleh EXP dari:



\- Normal monster.

\- Elite monster.

\- Boss.

\- Dungeon completion.

\- Quest (future feature).



Ketika EXP mencapai kebutuhan level berikutnya, karakter naik level dan memperoleh peningkatan atribut sesuai sistem progression.



Rumus EXP dan pertumbuhan atribut perlu ditentukan melalui balancing.



\---



\# 4. CLASS SPECIALIZATION



\## 4.1 Overview



Karakter memiliki tiga jalur specialization awal:



\- Vanguard

\- Arcanist

\- Ranger



Setiap specialization memberikan modifier atribut dan identitas gameplay yang berbeda.



\## 4.2 Vanguard



\*\*Role:\*\* Melee / Physical / Durability



Karakter berfokus pada pertahanan, kekuatan serangan fisik, dan kemampuan bertahan.



Karakteristik:

\- Physical damage.

\- HP dan DEF lebih tinggi.

\- Cocok untuk menghadapi musuh dalam jarak dekat.

\- Memiliki kemampuan bertahan lebih baik.



\## 4.3 Arcanist



\*\*Role:\*\* Magic / AoE / Aether



Karakter berfokus pada kemampuan sihir dan serangan area.



Karakteristik:

\- Magic damage.

\- Efektivitas skill lebih tinggi.

\- Cocok menghadapi banyak musuh.

\- Mengandalkan kemampuan Aether.



\## 4.4 Ranger



\*\*Role:\*\* Ranged / Attack Speed / Precision



Karakter berfokus pada serangan jarak jauh dan kecepatan serangan.



Karakteristik:

\- Ranged damage.

\- Attack speed lebih tinggi.

\- Critical-oriented gameplay.

\- Efektif dalam menyerang target secara konsisten.



\## 4.5 Specialization Rules



\- Hanya ada satu karakter utama.

\- Specialization mengubah modifier dan kompatibilitas kemampuan.

\- Perubahan specialization tidak boleh menyebabkan modifier terakumulasi berulang.

\- Aturan pergantian specialization harus konsisten dengan progression system.

\- Sistem dirancang data-driven agar specialization tambahan dapat ditambahkan kemudian.



\---



\# 5. SKILL SYSTEM



\## 5.1 Skill Categories



Skill dibagi menjadi:



\- Active Skill

\- Passive Skill



Active skill dapat dijalankan otomatis berdasarkan cooldown dan kondisi tertentu.



Passive skill memberikan modifier atau efek permanen selama persyaratan skill terpenuhi.



\## 5.2 Initial Skills



\### Power Strike

\- Type: Active

\- Role: Physical Damage

\- Effect: Memberikan serangan fisik tambahan kepada target.



\### Aether Burst

\- Type: Active

\- Role: Magic AoE

\- Effect: Memberikan magic damage kepada beberapa musuh dalam area tertentu.



\### Healing Pulse

\- Type: Active

\- Role: Healing

\- Effect: Memulihkan HP karakter.



\### Vitality

\- Type: Passive

\- Role: Defense

\- Effect: Meningkatkan kapasitas HP atau ketahanan karakter.



\### Focus

\- Type: Passive

\- Role: Offense

\- Effect: Meningkatkan efektivitas ofensif atau kemampuan skill.



\## 5.3 Automatic Skill Execution



Sistem auto skill menggunakan prioritas dan kondisi.



Prioritas baseline:



1\. Healing Pulse ketika HP berada di bawah threshold.

2\. Aether Burst ketika terdapat beberapa musuh.

3\. Power Strike ketika target valid tersedia.

4\. Basic attack sebagai fallback.



Aturan:

\- Skill harus memenuhi cooldown.

\- Skill harus memenuhi kondisi penggunaan.

\- Skill tidak dijalankan jika karakter berada dalam state yang melarang combat.

\- Skill harus memperhitungkan resource cost jika sistem resource diterapkan.

\- Skill execution tidak boleh bergantung pada animasi visual.



\## 5.4 Skill Progression



Skill dapat memiliki:

\- Unlock requirement.

\- Skill level.

\- Upgrade cost.

\- Cooldown.

\- Effect scaling.

\- Specialization compatibility.



Detail angka dan formula skill ditentukan melalui balancing.



\---



\# 6. COMBAT SYSTEM



\## 6.1 Combat Overview



Combat berjalan secara real-time dan otomatis.



Pemain tidak perlu menekan tombol attack maupun skill untuk melakukan pertarungan normal.



\## 6.2 Target Selection



Karakter memilih target berdasarkan prioritas.



Baseline priority:



1\. Musuh yang sedang menyerang pemain.

2\. Musuh terdekat.

3\. Elite monster.

4\. Musuh dengan HP terendah.



Urutan tersebut dapat dikembangkan menjadi konfigurasi target priority.



\## 6.3 Player Combat Behavior



1\. Mendeteksi musuh.

2\. Memilih target.

3\. Memeriksa jarak target.

4\. Bergerak menuju posisi serang jika diperlukan.

5\. Melakukan basic attack.

6\. Mengevaluasi kondisi auto skill.

7\. Menggunakan skill jika memenuhi persyaratan.

8\. Memilih target baru ketika target sebelumnya tidak valid.



\## 6.4 Monster AI



Monster memiliki state:



\- Idle

\- Detect

\- Chase

\- Attack

\- Return

\- Dead



Monster dapat mendeteksi pemain, mengejar, menyerang, kembali ke posisi awal, dan masuk ke state mati.



\## 6.5 Damage Calculation



Baseline formula:



`Base Damage = max(1, ATK - DEF)`



Critical hit menggunakan:



`Final Damage = Base Damage × CRIT Multiplier`



Formula akhir dapat dikembangkan untuk mendukung:

\- Physical damage.

\- Magic damage.

\- Damage modifier.

\- Resistance.

\- Critical damage.

\- Skill multiplier.



Nilai dan urutan perhitungan harus konsisten di seluruh sistem combat.



\## 6.6 Attack Speed



Attack interval:



`Attack Interval = 1 / ASPD`



ASPD harus memiliki batas minimum dan maksimum yang ditentukan melalui balancing.



\---



\# 7. MOVEMENT SYSTEM



\## 7.1 Movement Overview



Pergerakan karakter berjalan sepenuhnya otomatis.



Tidak ada joystick atau kontrol manual movement pada MVP.



\## 7.2 Movement Behavior



Karakter bergerak berdasarkan:

\- Target yang dipilih.

\- Jarak serang.

\- Navigation grid.

\- Kondisi obstacle.

\- Room transition.



\## 7.3 Pathfinding



Sistem menggunakan A\* pathfinding pada navigation grid.



Navigation grid harus terpisah dari visual tilemap.



Karakter harus dapat:

\- Menentukan jalur menuju target.

\- Menghindari obstacle.

\- Memilih posisi serang yang valid.

\- Menyesuaikan jalur ketika target bergerak.



\---



\# 8. DUNGEON SYSTEM



\## 8.1 Dungeon Structure



Dungeon menggunakan struktur room-based.



MVP menggunakan progression linear, tetapi struktur data dirancang agar dapat mendukung percabangan pada masa depan.



\## 8.2 First Biome: Forgotten Forest



Forgotten Forest merupakan dungeon pertama dengan tema hutan kuno yang terkontaminasi energi Aether.



Atmosfer:

\- Ancient forest.

\- Ruins.

\- Corrupted nature.

\- Mysterious Aether energy.



\## 8.3 Room Structure



Urutan room:



1\. Forest Entrance

2\. Ancient Path

3\. Ruined Shrine

4\. Hidden Chamber

5\. Ancient Heart



Setiap room memiliki:

\- Room ID.

\- Map configuration.

\- Entry position.

\- Exit position.

\- Spawn configuration.

\- Completion condition.

\- Reward configuration.



\## 8.4 Initial Monsters



\### Aether Slime

Monster normal dengan karakteristik energi Aether.



\### Forest Wolf

Monster normal dengan perilaku agresif dan mobilitas tinggi.



\### Corrupted Treant

Monster normal dengan karakteristik pertahanan tinggi.



\### Corrupted Guardian

Elite monster dengan kekuatan lebih tinggi dibanding monster normal.



\### Ancient Heart Guardian

Boss utama Forgotten Forest.



\## 8.5 Room Completion



Room dianggap selesai ketika seluruh kondisi penyelesaian terpenuhi.



Contoh:

\- Seluruh monster wajib dikalahkan.

\- Elite atau boss telah dikalahkan.

\- Tidak ada encounter wajib yang tersisa.



Setelah selesai, sistem memberikan reward dan memproses transisi room.



\## 8.6 Future Biomes



Biome yang dapat dikembangkan:

\- Crystal Cavern.

\- Ancient Crypt.

\- Ashen Wasteland.

\- Aether Sanctum.



\---



\# 9. DEATH AND REVIVE SYSTEM



\## 9.1 Downed State



Ketika HP mencapai nol:

\- Karakter memasuki Downed State.

\- Combat dihentikan.

\- Pergerakan dan skill execution dihentikan.

\- Sistem memeriksa ketersediaan revive.



\## 9.2 Auto Revive



Baseline configuration:



| Property | Value |

|---|---|

| Revive Delay | 3 seconds |

| Restored HP | 30% Max HP |

| Invulnerability | 2 seconds |

| Revive Cooldown | 90 seconds |



Nilai tersebut merupakan baseline balancing.



\## 9.3 Revive Failure



Jika karakter mati ketika revive cooldown masih aktif:

\- Dungeon run berakhir.

\- Karakter kembali ke town.

\- Equipment tetap dimiliki.

\- Loot yang sudah dikonfirmasi tetap dimiliki.

\- Penyelesaian room yang belum selesai tidak dihitung.



Aturan kehilangan reward tambahan harus ditentukan secara eksplisit sebelum diterapkan.



\---



\# 10. EQUIPMENT AND INVENTORY



\## 10.1 Equipment Slots



Slot equipment MVP:



1\. Weapon

2\. Head

3\. Body

4\. Accessory



\## 10.2 Equipment Rarity



Rarity:



\- Common

\- Uncommon

\- Rare

\- Epic

\- Legendary



Rarity dapat memengaruhi rentang atribut, jumlah modifier, dan nilai equipment.



\## 10.3 Inventory



Inventory menyimpan item yang diperoleh pemain.



Fitur MVP:

\- Item listing.

\- Item details.

\- Equipment management.

\- Item rarity.

\- Item quantity.

\- Item sorting/filtering dasar.



\## 10.4 Derived Attributes



Atribut akhir dihitung dari:



`Final Stats = Base Stats + Equipment Modifiers + Specialization Modifiers + Passive Skill Bonuses`



Modifier harus dihitung ulang secara konsisten ketika equipment, specialization, atau passive skill berubah.



\---



\# 11. LOOT AND REWARDS



\## 11.1 Reward Sources



Reward diperoleh dari:

\- Normal monster.

\- Elite monster.

\- Boss.

\- Dungeon completion.



\## 11.2 Reward Types



\- EXP.

\- Gold.

\- Equipment.

\- Consumables (future expansion).



\## 11.3 Loot Table



Loot menggunakan konfigurasi data-driven.



Loot table dapat menentukan:

\- Item ID.

\- Drop chance.

\- Quantity range.

\- Minimum/maximum reward.

\- Monster atau encounter yang menjadi sumber reward.



Total probabilitas drop harus divalidasi.



Reward diselesaikan secara idempoten per `eventId` melalui `RewardProcessor` agar normal monster, elite, boss, dan `dungeon_completion` (dikonfigurasi pada `game_config.json`) tidak pernah memberikan EXP, gold, maupun loot lebih dari satu kali untuk event yang sama.



\---



\# 12. OFFLINE PROGRESSION



\## 12.1 Overview — Hybrid Offline Progression

Game mendukung **Hybrid Offline Progression** yang sepenuhnya offline-first tanpa menjalankan Flame simulation maupun UI rendering ketika aplikasi berada di background atau tertutup. Ketika pemain kembali aktif, sistem menghitung progres yang sah berdasarkan aktivitas offline yang dipilih pemain sebelum keluar.

Tiga opsi mode aktivitas offline (keputusan desain resmi M6 Stage 1):

1. **Mode A — Continue Dungeon**
   - Melanjutkan dungeon run aktif (`runId` tetap dipertahankan) dari checkpoint room terakhir saat pemain offline.
   - Hanya tersedia apabila pemain memiliki dungeon run yang sedang aktif (`inProgress` atau `roomCompleted`).
   - Wajib mengikuti konfigurasi dungeon, urutan room (`next_room_ids`), encounter (normal, elite, boss), syarat room completion, aturan combat, serta aturan death & auto-revive M5 tanpa melewati room atau encounter.
   - Jika dungeon selesai saat offline, reward penyelesaian diproses sekali lalu aktivitas dihentikan (tidak otomatis memulai dungeon baru).
   - Jika run gagal akibat mati saat revive sedang cooldown, aktivitas dihentikan dan hasil disimpan hingga pemain kembali.

2. **Mode B — Auto Farming**
   - Menjalankan dungeon farming secara berulang dari **Town** selama jendela waktu offline masih tersedia.
   - Untuk MVP, hanya dungeon yang **sudah terbuka dan pernah diselesaikan sebelumnya (`clearsCount > 0`)** yang dapat dipilih sebagai target Auto Farming.
   - Setiap attempt dungeon memiliki `runId` unik, memulai dari Room 1, memakai aturan normal untuk HP, skill/cooldown, encounter, loot, dan auto-revive, serta melakukan settlement & anti-duplicate protection per `runId`.
   - Auto Farming tidak dapat membuka dungeon baru maupun memberikan reward untuk encounter/room yang belum diselesaikan.
   - **Kebijakan Kegagalan (`stopOnDefeat`):** apabila satu attempt Auto Farming berakhir kalah (*defeated* saat revive cooldown aktif), aktivitas Auto Farming berhenti pada titik tersebut; reward dari kill dan room/run sebelumnya yang sah tetap dipertahankan, sedangkan room/dungeon gagal tidak mendapat clear reward.

3. **Auto-Arming & Fallback (`Pause Progression`)**
   - Setelah minimal satu dungeon normal pernah diselesaikan pada siklus saat ini (`resolveFarmDungeonId != null`), **Mode B (Auto Farming) aktif otomatis** pada lokasi farming pilihan pemain (default ke dungeon normal terselesaikan terakhir/tertinggi) tanpa perlu mengaktifkan tombol secara terpisah, dan otomatis terpasang ulang setelah klaim ringkasan offline maupun keluar/selesai dari dungeon.
   - Tombol pada panel Town Hub berfungsi untuk **memilih tempat/lokasi farming** (tidak ada tombol Pause terpisah pada Town Hub).
   - `Pause Progression` tetap menjadi fallback internal ketika belum ada dungeon normal yang selesai pada siklus saat ini (awal permainan / tepat setelah Ascension ke rank baru) atau saat run Ascension/Boss sedang berjalan manual.



\## 12.2 Offline Cap



Maksimum waktu simulasi offline:



\*\*8 jam.\*\*

Durasi yang melebihi 8 jam dibatasi (*capped*) menjadi tepat 8 jam; durasi negatif (perubahan jam mundur) ditolak tanpa reward, dan waktu yang sudah diproses tidak pernah dihitung ulang.



\## 12.3 Offline Reward



Reward dapat mencakup:

\- EXP.

\- Gold.

\- Loot & Equipment sesuai loot table monster, room, dan dungeon completion yang sama dengan gameplay online.

Offline progression tidak menggunakan multiplier reward tersembunyi khusus offline dan tidak boleh memberikan keuntungan yang tidak mungkin dicapai lewat gameplay normal.



\## 12.4 Offline Simulation Rules



\- Waktu offline tidak boleh negatif.

\- Reward tidak boleh diberikan dua kali (dijaga `ClaimedRewards` & state machine terminal).

\- Simulasi harus memiliki batas komputasi dan mekanisme checkpoint tanpa loop 20 TPS selama 8 jam.

\- Hasil simulasi harus konsisten dengan formula combat, loot, progression, serta death/revive online.

\- Sistem harus menangani kondisi kematian dan revive secara deterministik (`stopOnDefeat` untuk Auto Farming).

\- Simulasi offline tidak menjalankan Flame component atau UI lifecycle.



\---



\# 13. USER INTERFACE



UI utama yang direncanakan:



\- Home / Town.

\- Dungeon View.

\- Character Status.

\- Specialization.

\- Skill Management.

\- Inventory.

\- Equipment.

\- Dungeon Results.

\- Settings.



UI harus menyajikan informasi progression tanpa mengganggu pengalaman auto combat.



UI tidak boleh menjadi sumber kebenaran untuk state gameplay.



\---



\# 14. AUDIO AND VISUAL DIRECTION



\## 14.1 Art Direction



Visual menggunakan 2D top-down pixel art dengan nuansa atmospheric ancient fantasy.



Karakteristik:

\- Fantasy adventure.

\- Ancient ruins.

\- Mysterious forest.

\- Corrupted nature.

\- Aether energy effects.

\- Readable silhouettes.



\## 14.2 Initial Palette



| Color | Hex |

|---|---|

| Forest Green | #355B45 |

| Deep Forest | #243D35 |

| Moss Green | #71865A |

| Earth Brown | #795B43 |

| Ancient Stone | #777B79 |

| Aether Blue | #65BFE8 |

| Arcane Purple | #9879CE |

| Warm Gold | #E6BD68 |

| Health Red | #D95D5D |



\## 14.3 Audio Direction



Audio mencakup:

\- Background music.

\- Basic attack.

\- Skill effects.

\- Monster sounds.

\- Loot pickup.

\- Dungeon transitions.

\- Boss encounter.

\- UI feedback.



\---



\# 15. MVP SCOPE



\## 15.1 Included



\- One playable character.

\- Three class specializations.

\- Automatic movement.

\- Automatic combat.

\- Initial skill system.

\- Basic monster AI.

\- Forgotten Forest biome.

\- Five rooms.

\- Three normal monster types.

\- One elite monster.

\- One boss.

\- EXP and leveling.

\- Gold.

\- Loot and rarity.

\- Inventory and equipment.

\- Auto revive.

\- Offline progression.

\- Local persistence.



\## 15.2 Excluded from MVP



\- Multiplayer.

\- Guild.

\- PvP.

\- Trading.

\- Gacha.

\- Pet system.

\- Procedural dungeon.

\- Complex crafting.

\- Multiple playable characters.

\- Online synchronization.

\- Server-based social features.



\---



\# 16. DESIGN PRINCIPLES



1\. Gameplay state harus deterministik dan tidak bergantung pada rendering.

2\. Sistem progression harus dapat dikembangkan tanpa mengubah seluruh combat architecture.

3\. Skill dan item sebaiknya menggunakan konfigurasi data-driven.

4\. Specialization harus memiliki identitas gameplay yang jelas.

5\. Offline progression tidak boleh menghasilkan reward duplikat.

6\. MVP harus tetap sederhana dan dapat diselesaikan sebelum fitur tambahan dikembangkan.

7\. Setiap perubahan desain harus diperbarui dalam dokumentasi.



\---



\# 17. DOCUMENT MAINTENANCE



Dokumen ini merupakan baseline desain Echoes of Aether.



Jika implementasi aktual berbeda dari dokumen:

1\. Periksa apakah perbedaan tersebut disengaja.

2\. Evaluasi dampaknya terhadap gameplay.

3\. Perbarui GDD setelah keputusan disetujui.

4\. Sinkronkan perubahan dengan TDD dan Master Development Roadmap.



Jangan menganggap fitur yang belum tercantum sebagai fitur yang otomatis harus ditambahkan.



\*\*End of Document\*\*

