-- Este script SQL debería ejecutarse en Supabase SQL Editor para verificar y configurar RLS

-- 1. Verificar si RLS está habilitado en user_favorites
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'user_favorites';

-- 2. Ver las políticas existentes
SELECT * FROM pg_policies WHERE tablename = 'user_favorites';

-- 3. Si no hay políticas, crear políticas básicas para permitir CRUD al propietario
-- (Solo ejecutar si no existen políticas)

-- Política para SELECT: los usuarios solo pueden ver sus propios favoritos
CREATE POLICY "Users can view own favorites" ON user_favorites
    FOR SELECT USING (auth.uid() = user_id);

-- Política para INSERT: los usuarios solo pueden insertar sus propios favoritos
CREATE POLICY "Users can insert own favorites" ON user_favorites
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Política para UPDATE: los usuarios solo pueden actualizar sus propios favoritos
CREATE POLICY "Users can update own favorites" ON user_favorites
    FOR UPDATE USING (auth.uid() = user_id);

-- Política para DELETE: los usuarios solo pueden eliminar sus propios favoritos
CREATE POLICY "Users can delete own favorites" ON user_favorites
    FOR DELETE USING (auth.uid() = user_id);

-- 4. Si RLS no está habilitado, habilitarlo
-- ALTER TABLE user_favorites ENABLE ROW LEVEL SECURITY;
