# Cara rilis versi baru aplikasi mobile

Setiap ada perubahan di `umgap_mobile/`, ikuti langkah ini supaya semua
user lama otomatis dapat popup update di dalam app (tidak perlu kirim
link Drive/WA manual lagi).

## 1. Naikkan nomor versi

Edit `umgap_mobile/pubspec.yaml`, baris `version:`:

```yaml
version: 1.2.6+10   # format: <versi>+<build number>, keduanya naik tiap rilis
```

## 2. Build APK release

```bash
cd umgap_mobile
flutter build apk --release
```

Hasilnya ada di:
`umgap_mobile/build/app/outputs/flutter-apk/app-release.apk`

## 3. Upload ke VPS (timpa file yang sama, URL selalu tetap)

```bash
scp "/Users/rafaelandre/Downloads/UMGAP-AI-main/umgap_mobile/build/app/outputs/flutter-apk/app-release.apk" \
    root@185.227.134.212:/root/umgap/static/downloads/umgap-latest.apk
```

## 4. Update info versi di backend

Edit `app.py`, fungsi `app_version()` (cari `/api/mobile/version`):

```python
"latest_version": "1.2.6",   # ← SAMAKAN dgn "version:" di pubspec.yaml (TANPA +buildNumber)
"force_update":   False,     # True kalau update ini WAJIB (mis. ada bug fatal)
"message":        "Versi baru v1.2.6 tersedia!\n• ...\n• ...",
```

## 5. Commit & push (auto-deploy via webhook)

```bash
git add app.py
git commit -m "Rilis mobile v1.2.6"
git push origin main
```

Kalau webhook auto-deploy tidak jalan (cek dgn curl di bawah), jalankan manual di VPS:
```bash
bash /root/deploy.sh
```

## 6. Verifikasi sudah live

```bash
curl -s https://umgap-ai.my.id/api/mobile/version
curl -sI https://umgap-ai.my.id/static/downloads/umgap-latest.apk
```
Pastikan `latest_version` sudah sesuai & APK bisa diunduh (HTTP 200,
`content-length` sesuai ukuran file baru).

## Selesai

User yang sudah pernah install app akan otomatis lihat popup "Update
Tersedia" (atau "Update Diperlukan" kalau `force_update: true`) saat
buka app, dan tombol "Update Sekarang" langsung download + buka
installer APK di dalam app.
