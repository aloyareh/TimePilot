# Time Pilot

> Task manager & alarm bertantangan untuk freelancer global. **Waktu = uang.**

Proyek mata kuliah **Pemrograman Aplikasi Mobile** — [Sistem Informasi UPN "Veteran" Yogyakarta].

## Tentang

Freelancer yang melayani klien lintas negara sering kehilangan pendapatan karena telat bangun untuk meeting, salah menghitung jam klien, atau lupa mencatat durasi kerja. TempoGig menyatukan **alarm**, **task manager**, dan **pelacak jam kerja** dalam satu aplikasi dengan prinsip sederhana: setiap menit punya harga.

- Tugas dan meeting dijadwalkan dalam **waktu klien**, lalu ditampilkan otomatis dalam WIB, WITA, WIT, dan London.
- Alarm tidak cukup dimatikan dengan satu ketukan. Pengguna menyelesaikan **tantangan** (goyang, seimbangkan HP, atau mini game). Melewati tantangan berarti *snooze* yang menambah **biaya keterlambatan** (menit terlambat x tarif per jam).
- Setiap sesi kerja yang selesai dicatat sebagai blok pada **log jam kerja berantai** (blockchain sederhana).

## Persona

**Raka**, 24 tahun, freelancer web/UI di Yogyakarta (WIB). Kliennya: studio di London (GBP), toko di Bali (WITA, IDR), dan proyek di Jayapura (WIT, IDR). Persona dapat diatur di halaman Profil: peran, zona waktu rumah, mata uang utama, daftar klien beserta zona waktu dan tarif per jam, jam kerja, serta jenis dan tingkat kesulitan tantangan. Tersedia tiga preset awal: *Freelancer*, *Pekerja Remote*, dan *Mahasiswa Kerja Paruh Waktu*.

## Fitur

**Akun dan keamanan**
- [ ] Registrasi dan login dengan password ter-hash (tanpa Firebase) serta manajemen sesi
- [ ] Login biometrik (sidik jari/wajah), juga sebagai gerbang halaman Pendapatan

**Tugas, alarm, dan sesi kerja**
- [ ] Tugas dan meeting dengan waktu klien dan konversi ke WIB/WITA/WIT/London
- [ ] Alarm dan pengingat (notifikasi lokal)
- [ ] Tantangan: *Shake to Wake* (accelerometer), *Balance Challenge* (gyroscope), mini game memori/matematika
- [ ] Timer sesi kerja dan perhitungan pendapatan per klien
- [ ] Biaya keterlambatan dalam beberapa mata uang
- [ ] Pencarian tugas dan filter (klien, status, mata uang)

**Pintar dan lokasi**
- [ ] AI: estimasi durasi tugas dan jam paling produktif dari riwayat sesi
- [ ] LLM: draf email/invoice untuk klien dan ringkasan mingguan
- [ ] LBS: cari coworking/kafe terdekat dan mode cowork (opsional)

**Blockchain**
- [ ] Log jam kerja berantai (SHA-256 + proof-of-work sederhana) dengan verifikasi rantai

**Navigasi**
- [ ] Bottom navigation: Beranda, Profil (dengan foto), Saran & Kesan, Logout

## Pemetaan ketentuan tugas

| Ketentuan | Implementasi |
|---|---|
| Login terenkripsi + session | Auth sendiri; hash password di server; token di `flutter_secure_storage` |
| Login biometrik | `local_auth` |
| Database lokal + online | Hive (lokal), Supabase/Postgres (online) |
| Web service/API + LBS | API kurs, API LLM, REST Supabase; peta OpenStreetMap |
| Bottom navigation | Beranda, Profil, Saran & Kesan, Logout |
| Konversi mata uang (min. 3) | IDR, USD, GBP, EUR |
| Konversi waktu | WIB, WITA, WIT, London |
| Minimal 2 sensor | Accelerometer, gyroscope |
| AI dan LLM | Estimasi durasi tugas (AI), draf email dan ringkasan (LLM) |
| Mini game | Memori dan matematika |
| Pencarian dan pemilihan | Cari/filter tugas, pilih klien dan tantangan |
| Notifikasi | Alarm meeting, deadline, pengingat sesi |
| Blockchain sederhana | Log jam kerja berantai |

## Teknologi

| Bagian | Pilihan |
|---|---|
| Framework | Flutter (Dart) |
| Penyimpanan lokal | Hive |
| Backend online | Supabase (Postgres + REST) |
| Biometrik | `local_auth` |
| Penyimpanan aman | `flutter_secure_storage` |
| Sensor | `sensors_plus` |
| Lokasi dan peta | `geolocator`, `flutter_map` (OpenStreetMap) |
| Notifikasi | `flutter_local_notifications` |
| Zona waktu | `timezone` |
| Hash | `crypto` |
| LLM | API LLM eksternal (mis. Gemini/Groq) |

> Daftar paket dapat berubah selama pengembangan; cek `pubspec.yaml` untuk versi terkini.

## Arsitektur singkat

- **Local-first:** tugas, alarm, dan sesi disimpan di Hive sehingga alarm tetap berjalan tanpa internet. Data disinkronkan ke Supabase saat online.
- **Autentikasi:** registrasi dan login memanggil fungsi database (RPC) yang melakukan hash dan verifikasi password di server, bukan di aplikasi.
- **Blockchain:** tiap sesi selesai menjadi blok berisi indeks, klien, durasi, `prev_hash`, `nonce`, dan `hash`. Timestamp diambil dari **server**, bukan jam perangkat.

## Struktur folder (rencana)

```
lib/
├── core/            # tema, konstanta, util waktu & mata uang
├── data/
│   ├── local/       # Hive boxes
│   ├── remote/      # klien Supabase, API kurs, API LLM
│   └── repositories/
├── features/
│   ├── auth/
│   ├── tasks/
│   ├── alarm/
│   ├── challenges/  # shake, balance, mini game
│   ├── sessions/
│   ├── earnings/
│   ├── ai/
│   ├── blockchain/
│   ├── profile/
│   └── feedback/
└── main.dart
```

## Tim

| Nama | Peran |
|---|---|
| Hera Yola Ardini | Full Stack |
| Rosa Vinay Herdante Putri | Full Stack |
