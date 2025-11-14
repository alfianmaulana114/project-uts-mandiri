-- QUICK FIX: Script untuk memperbaiki RLS policy dengan cepat
-- Jalankan script ini di Supabase SQL Editor jika masih error

-- 1. Pastikan kolom user_id ada (nullable untuk data lama)
-- Hapus foreign key constraint jika ada (karena mungkin tidak diperlukan)
ALTER TABLE todos DROP CONSTRAINT IF EXISTS todos_user_id_fkey;
ALTER TABLE notes DROP CONSTRAINT IF EXISTS notes_user_id_fkey;
ALTER TABLE archives DROP CONSTRAINT IF EXISTS archives_user_id_fkey;

-- Tambahkan kolom user_id
ALTER TABLE todos ADD COLUMN IF NOT EXISTS user_id UUID;
ALTER TABLE notes ADD COLUMN IF NOT EXISTS user_id UUID;
ALTER TABLE archives ADD COLUMN IF NOT EXISTS user_id UUID;

-- 2. Enable RLS
ALTER TABLE todos ENABLE ROW LEVEL SECURITY;
ALTER TABLE notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE archives ENABLE ROW LEVEL SECURITY;

-- 3. Hapus SEMUA policy lama
DROP POLICY IF EXISTS "Allow all operations for todos" ON todos;
DROP POLICY IF EXISTS "Allow all operations for notes" ON notes;
DROP POLICY IF EXISTS "Allow all operations for archives" ON archives;
DROP POLICY IF EXISTS "Users can only access their own todos" ON todos;
DROP POLICY IF EXISTS "Users can only access their own notes" ON notes;
DROP POLICY IF EXISTS "Users can only access their own archives" ON archives;

-- 4. Buat policy baru yang lebih permisif (mengizinkan INSERT dengan user_id yang sesuai)
-- Policy untuk INSERT
CREATE POLICY "Allow insert own todos"
ON todos
FOR INSERT
WITH CHECK (auth.uid()::text = user_id::text);

CREATE POLICY "Allow insert own notes"
ON notes
FOR INSERT
WITH CHECK (auth.uid()::text = user_id::text);

CREATE POLICY "Allow insert own archives"
ON archives
FOR INSERT
WITH CHECK (auth.uid()::text = user_id::text);

-- Policy untuk SELECT
CREATE POLICY "Allow select own todos"
ON todos
FOR SELECT
USING (auth.uid()::text = user_id::text);

CREATE POLICY "Allow select own notes"
ON notes
FOR SELECT
USING (auth.uid()::text = user_id::text);

CREATE POLICY "Allow select own archives"
ON archives
FOR SELECT
USING (auth.uid()::text = user_id::text);

-- Policy untuk UPDATE
CREATE POLICY "Allow update own todos"
ON todos
FOR UPDATE
USING (auth.uid()::text = user_id::text)
WITH CHECK (auth.uid()::text = user_id::text);

CREATE POLICY "Allow update own notes"
ON notes
FOR UPDATE
USING (auth.uid()::text = user_id::text)
WITH CHECK (auth.uid()::text = user_id::text);

CREATE POLICY "Allow update own archives"
ON archives
FOR UPDATE
USING (auth.uid()::text = user_id::text)
WITH CHECK (auth.uid()::text = user_id::text);

-- Policy untuk DELETE
CREATE POLICY "Allow delete own todos"
ON todos
FOR DELETE
USING (auth.uid()::text = user_id::text);

CREATE POLICY "Allow delete own notes"
ON notes
FOR DELETE
USING (auth.uid()::text = user_id::text);

CREATE POLICY "Allow delete own archives"
ON archives
FOR DELETE
USING (auth.uid()::text = user_id::text);

-- Selesai! Setelah ini, coba test aplikasi lagi.
-- Pastikan logout dan login kembali di aplikasi.

