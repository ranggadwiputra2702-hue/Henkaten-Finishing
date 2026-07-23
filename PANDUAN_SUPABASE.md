# Panduan Supabase — Form Henkaten

## 1. Buat proyek

1. Masuk ke [Supabase](https://supabase.com/dashboard) lalu pilih **New project**.
2. Pilih organisasi, isi nama proyek, database password, dan region terdekat (Singapore biasanya cocok untuk Indonesia).
3. Tunggu hingga status proyek aktif.

## 2. Buat tabel database

1. Pada dashboard proyek, buka **SQL Editor** > **New query**.
2. Buka file `supabase_schema.sql` di proyek ini, salin seluruh isinya, lalu tempelkan.
3. Tekan **Run**.
4. Buka **Table Editor**. Tabel `henkaten_pengajuan` dan `henkaten_lampiran` harus sudah muncul.

Skrip membuat nomor otomatis dengan format `YYYY.MM.DD.001`, misalnya `2026.07.23.001`. Urutan dimulai dari `001` untuk setiap tanggal dan dibuat oleh database sehingga aman saat banyak pengguna mengirim bersamaan. Kolom nomor pada form hanya menampilkan preview; nomor final ditetapkan oleh database.

## 3. Aktifkan login

Skema ini sengaja hanya mengizinkan pengguna yang sudah masuk untuk melihat dan mengubah pengajuannya sendiri. Buka **Authentication** > **Providers**, aktifkan provider yang dibutuhkan (misalnya Email), kemudian buat pengguna uji melalui **Authentication** > **Users**.

Jangan pernah menyimpan `service_role` key pada HTML/JavaScript browser. Gunakan hanya `Publishable key` atau `anon key` dari **Project Settings** > **API**.

## 4. Buat bucket lampiran (opsional)

Jika input Lampiran pada form akan dipakai:

1. Buka **Storage** > **New bucket**.
2. Isi nama bucket: `henkaten-lampiran`.
3. Biarkan bucket **Private**.
4. Atur batas ukuran dan tipe file sesuai kebijakan perusahaan. Untuk form sekarang: PDF, DOC/DOCX, XLS/XLSX, JPG/JPEG, PNG.

Setelah bucket dibuat, tambahkan policies berikut pada **Storage** > **Policies** > `storage.objects` melalui SQL Editor. File disimpan dengan pola: `<user-id>/<pengajuan-id>/<nama-file>`.

```sql
create policy "Pengguna membaca lampiran sendiri"
on storage.objects for select to authenticated
using (
  bucket_id = 'henkaten-lampiran'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

create policy "Pengguna mengunggah lampiran sendiri"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'henkaten-lampiran'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

create policy "Pengguna menghapus lampiran sendiri"
on storage.objects for delete to authenticated
using (
  bucket_id = 'henkaten-lampiran'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);
```

## 5. Cek data

Gunakan query berikut pada SQL Editor setelah membuat pengajuan:

```sql
select nomor_henkaten, nama_pemohon, judul_perubahan, created_at
from public.henkaten_pengajuan
order by created_at desc;
```

Contoh hasil nomor: `2026.07.23.001`, `2026.07.23.002`, lalu saat tanggal berganti menjadi `2026.07.24.001`.

## Catatan integrasi web

Halaman saat ini masih menyimpan data ke `localStorage`. Agar data masuk Supabase, form perlu dihubungkan memakai `@supabase/supabase-js`, pengguna perlu login, lalu data di-insert ke `henkaten_pengajuan`. Nama kolom database yang dipakai adalah `tanggal_pengajuan`, `nama_pemohon`, `perubahan_diusulkan`, dan seterusnya—lihat `supabase_schema.sql` sebagai kontrak datanya.

RLS harus tetap aktif karena tabel yang dibuat lewat SQL Editor tidak otomatis aman. Lihat dokumentasi resmi Supabase tentang [Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security) dan [akses Storage](https://supabase.com/docs/guides/storage/security/access-control).
