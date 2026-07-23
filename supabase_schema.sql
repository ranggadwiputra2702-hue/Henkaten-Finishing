-- Database Form Henkaten Finishing untuk Supabase
-- Jalankan seluruh skrip ini sekali di Dashboard Supabase > SQL Editor.

-- Counter disimpan per tanggal agar nomor menjadi YYYY.MM.DD.001.
create table if not exists public.henkaten_counter (
  tanggal date primary key,
  nomor_terakhir integer not null default 0 check (nomor_terakhir >= 0)
);

create table if not exists public.henkaten_pengajuan (
  id uuid primary key default gen_random_uuid(),
  nomor_henkaten text not null unique,
  tanggal_pengajuan date not null default current_date,
  nama_pemohon text not null check (char_length(trim(nama_pemohon)) > 0),
  departemen text not null check (char_length(trim(departemen)) > 0),
  jabatan text not null check (jabatan in ('Operator', 'Team Leader', 'Group Leader')),
  proses text not null,
  kategori_perubahan text not null check (kategori_perubahan in (
    'Proses', 'Produk / Material', 'Mesin / Peralatan',
    'Dokumen / Standar Kerja', 'Personel', 'Lainnya'
  )),
  tanggal_efektif date,
  judul_perubahan text not null check (char_length(trim(judul_perubahan)) > 0),
  kondisi_saat_ini text not null,
  perubahan_diusulkan text not null,
  alasan_perubahan text not null,
  change_points text[] not null default '{}'
    check (change_points <@ array['Man', 'Machine', 'Method', 'Material', 'Environment']::text[]),
  tingkat_dampak text not null check (tingkat_dampak in ('Rendah', 'Sedang', 'Tinggi')),
  perlu_pelatihan boolean not null,
  potensi_risiko text,
  tindakan_pencegahan text,
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.henkaten_lampiran (
  id uuid primary key default gen_random_uuid(),
  pengajuan_id uuid not null references public.henkaten_pengajuan(id) on delete cascade,
  nama_file text not null,
  storage_path text not null unique,
  tipe_file text,
  ukuran_byte bigint check (ukuran_byte is null or ukuran_byte >= 0),
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);

create or replace function public.set_nomor_henkaten()
returns trigger
language plpgsql
as $$
declare
  tanggal_nomor date;
  nomor_berikutnya integer;
begin
  tanggal_nomor := coalesce(new.tanggal_pengajuan, current_date);

  insert into public.henkaten_counter (tanggal, nomor_terakhir)
    values (tanggal_nomor, 1)
  on conflict (tanggal) do update
    set nomor_terakhir = public.henkaten_counter.nomor_terakhir + 1
  returning nomor_terakhir into nomor_berikutnya;

  new.nomor_henkaten := to_char(tanggal_nomor, 'YYYY.MM.DD')
    || '.' || lpad(nomor_berikutnya::text, 3, '0');
  return new;
end;
$$;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists isi_nomor_henkaten on public.henkaten_pengajuan;
create trigger isi_nomor_henkaten
  before insert on public.henkaten_pengajuan
  for each row execute function public.set_nomor_henkaten();

drop trigger if exists perbarui_waktu_henkaten on public.henkaten_pengajuan;
create trigger perbarui_waktu_henkaten
  before update on public.henkaten_pengajuan
  for each row execute function public.set_updated_at();

create index if not exists henkaten_pengajuan_created_by_idx
  on public.henkaten_pengajuan(created_by);
create index if not exists henkaten_pengajuan_tanggal_idx
  on public.henkaten_pengajuan(tanggal_pengajuan desc);
create index if not exists henkaten_pengajuan_search_idx
  on public.henkaten_pengajuan using gin (to_tsvector('simple', coalesce(nomor_henkaten, '') || ' ' || coalesce(nama_pemohon, '') || ' ' || coalesce(judul_perubahan, '')));
create index if not exists henkaten_lampiran_pengajuan_idx
  on public.henkaten_lampiran(pengajuan_id);

alter table public.henkaten_pengajuan enable row level security;
alter table public.henkaten_lampiran enable row level security;

grant usage on schema public to authenticated;
grant select, insert, update, delete on public.henkaten_pengajuan to authenticated;
grant select, insert, update, delete on public.henkaten_lampiran to authenticated;
grant select on public.henkaten_counter to authenticated;

drop policy if exists "Pengguna mengelola pengajuan sendiri" on public.henkaten_pengajuan;
create policy "Pengguna mengelola pengajuan sendiri"
  on public.henkaten_pengajuan for all to authenticated
  using ((select auth.uid()) = created_by)
  with check ((select auth.uid()) = created_by);

drop policy if exists "Pengguna mengelola lampiran pengajuan sendiri" on public.henkaten_lampiran;
create policy "Pengguna mengelola lampiran pengajuan sendiri"
  on public.henkaten_lampiran for all to authenticated
  using (
    created_by = (select auth.uid()) and exists (
      select 1 from public.henkaten_pengajuan p
      where p.id = pengajuan_id and p.created_by = (select auth.uid())
    )
  )
  with check (
    created_by = (select auth.uid()) and exists (
      select 1 from public.henkaten_pengajuan p
      where p.id = pengajuan_id and p.created_by = (select auth.uid())
    )
  );
