# TEMPLATE LAPORAN PROGRES AGENT

Agent mengisi template ini di akhir setiap stage. Berdasarkan Master Development Roadmap v1 Section 6.5, dengan tambahan untuk M8–M11.

```text
LAPORAN PROGRES — Echoes of Aether

1. Milestone / Stage:        (mis. M8 Stage 1)
2. Status stage:             NOT STARTED / IN PROGRESS / BLOCKED / READY FOR REVIEW
3. Ringkasan satu paragraf:  (apa yang dikerjakan dan hasil utamanya)

4. Hasil audit awal
   - Asumsi TDD Addendum §1 yang TERBUKTI benar:
   - Asumsi yang BERBEDA dari kode nyata (jelaskan):

5. Pekerjaan selesai
   Tiap butir diberi tingkat bukti:
   - [IMPLEMENTED] kode ada
   - [TESTED] test lulus (sebutkan nama test)
   - [VERIFIED] dijalankan di perangkat atau simulasi (sebutkan caranya)

6. Pekerjaan tersisa / ditunda (beserta alasan):

7. File baru:
8. File diubah:
9. Perubahan schema database / konfigurasi (migrasi, breaking change):

10. Test
   - Perintah:        flutter test
   - Hasil:           X lulus / Y gagal / total Z   (baseline 366)
   - Test BARU:       (daftar)
   - Test LAMA yang diubah + alasan tiap perubahan:

11. Analyzer
   - Perintah:        flutter analyze
   - Hasil:           N issue (target 0)

12. Verifikasi perangkat (jika berlaku): perangkat, build (debug/release), skenario yang dicoba, hasil.

13. Angka balancing yang diubah (jika ada): nama, nilai lama -> baru, alasan, bukti simulasi.

14. Konflik desain / pertanyaan yang butuh keputusan:
15. Known issues / technical debt baru:
16. Pembaruan MILESTONE_STATUS_M8_M11.md: (bagian yang diubah)
17. Rekomendasi tugas berikutnya:
```

## Cara saya memeriksa laporan

1. Apakah angka test dan analyze konsisten dengan baseline?
2. Apakah setiap klaim "selesai" punya bukti TESTED atau VERIFIED?
3. Apakah ada perubahan di luar scope stage?
4. Apakah jalur online dan offline sama-sama dicakup?
5. Apakah test lama diubah tanpa alasan yang kuat?
