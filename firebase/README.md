# Firebase Spark Configuration — Echoes of Aether

Folder ini berisi aturan keamanan Firestore (`firestore.rules`), berkas hasil pembangkit batas (`limits.json`, `test_vectors.json`), serta test emulator untuk cloud sync M14 (paket Spark, tanpa Cloud Functions).

> **Catatan:** `firebase/firestore.rules`, `firebase/limits.json`, dan `firebase/test_vectors.json` dihasilkan secara deterministik oleh `tool/export_cloud_limits.dart`. Jangan mengedit `firestore.rules` langsung; edit `firestore.rules.template` lalu jalankan generator.

## Prasyarat

- Node.js LTS (uji coba menggunakan Node v24)
- JDK 21+ di `JAVA_HOME` / `PATH` (dibutuhkan oleh Firestore Emulator; pada mesin Windows yang punya Java 8 default, arahkan `JAVA_HOME` ke JDK 21 terlebih dahulu)
- Firebase CLI (`firebase` / di Windows PowerShell gunakan `firebase.cmd`)

## Instalasi dependensi test (sekali saja)

```bash
cd firebase
npm install
# Di Windows PowerShell jika ExecutionPolicy memblokir *.ps1:
npm.cmd install
```

## Regenerasi rules & verifikasi konsistensi

Dari root repository:

```bash
dart run tool/export_cloud_limits.dart
dart run tool/export_cloud_limits.dart --check
```

## Menjalankan test Firestore Security Rules di Emulator

Dari folder `firebase/`:

```bash
firebase emulators:exec --only firestore "node --test test/*.test.js"
```

Di Windows PowerShell (jika `ExecutionPolicy` memblokir `firebase.ps1` atau `java` default adalah Java 8):

```powershell
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-21.0.12.101-hotspot"
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
cd firebase
firebase.cmd emulators:exec --only firestore "node --test test/*.test.js"
```

## Deploy ke project Firebase (hanya oleh pemilik project)

Agent AI tidak menjalankan deploy. Setelah `firebase login` dan `firebase use <project-id>` (atau dari folder `firebase/` dengan `--project <project-id>`):

```bash
cd firebase
firebase deploy --only firestore:rules,firestore:indexes --project <project-id>
```
