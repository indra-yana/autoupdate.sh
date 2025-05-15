# 🛠️ Script Auto Update 

Shell script ini digunakan untuk mengotomatisasi proses update aplikasi berbasis Laravel dari GitHub. Termasuk update dependensi, menjalankan perintah Laravel, build frontend, dan mengirim notifikasi melalui Telegram (WIP) atau WhatsApp (Using WppConnect Server).

## 🚀 Workflow Penggunaan

1. **Download Repository**  
   Clone atau unduh repository ini ke server Anda.

   ```bash
   git clone https://github.com/indra-yana/autoupdate.sh script-autoupdate
   cd script-autoupdate
   ```

2. **Salin `.env.example` ke `.env`**  
   ```bash
   cp .env.example .env
   ```

3. **Isi dan Konfigurasi File `.env`**  
   Masukkan semua variabel sesuai dengan kebutuhan Anda.

4. **Atur Permission File**  
   Berikan hak akses eksekusi pada script:

   ```bash
   chmod +x autoupdate.v2.sh
   # Optional
   chown youruser:yourgroup autoupdate.v2.sh
   ```

5. **Pasang Script pada Cron**  
   Sebelum pasang di cron, pastikan script nya jalan dulu! lakukan perintah berikut untuk eksekusi file:

   ```bash
   ./autoupdate.v2.sh 
   # atau 
   sudo ./autoupdate.v2.sh
   ```

   Jika aman, masukan script ke cron job:

   ```bash
   crontab -e
   ```

   Tambahkan baris berikut untuk menjalankan script tiap hari jam 3 pagi:

   ```bash
   0 3 * * * cd /home/user/script-autoupdate && ./autoupdate.v2.sh >> /dev/null 2>&1 
   # atau
   0 3 * * * cd /home/user/script-autoupdate && sudo ./autoupdate.v2.sh >> /dev/null 2>&1
   ```

6. **Selesai** 🎉  
   Script akan otomatis:

   - Fetch dan pull update dari GitHub
   - Jalankan perintah Laravel
   - Build frontend asset (NPM)
   - Kirim notifikasi dan log file melalui Telegram (WIP) atau WhatsApp (Using WppConnect Server).
   - Simpan log ke updatelogs.d

## ⚙️ Tambahan Opsional

- Anda bisa menambahkan logging lebih detail ke dalam file log.
- Pastikan dependency seperti `git`, `php`, `composer`, `npm`, dan `curl` sudah tersedia di server kamu.
- Pastikan cron bisa mengakses PATH environment (misal: PHP, Node, Git).
- Jalankan manual dulu untuk melihat output dan pastikan semua dependensi tersedia:
   ```bash
   ./autoupdate.v2.sh 
   # atau 
   sudo ./autoupdate.v2.sh
   ```
- Gunakan VPS/server yang stabil untuk menghindari kegagalan saat fetch/pull.
- Anda bisa menggunakan [autoupdate.sh versi 1](https://github.com/indra-yana/autoupdate.sh/blob/master/autoupdate.sh) untuk workflow yang lebih sederhana
- [Optional] Gunakan sudo untuk eksekusi file

---

## 📬 Kontak

Jika ada pertanyaan, silakan hubungi saya melalui email atau GitHub.

Happy coding! 🎉

Lisensi MIT © Indra Muliana