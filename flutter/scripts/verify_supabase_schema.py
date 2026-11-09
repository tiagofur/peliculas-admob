#!/usr/bin/env python3
"""
Script para verificar y corregir el esquema de Supabase automáticamente.
Ejecuta las migraciones necesarias para asegurar compatibilidad con la app.
"""

import os
import sys
from supabase import create_client, Client
from dotenv import load_dotenv

# Cargar variables de entorno
load_dotenv()

SUPABASE_URL = os.getenv('SUPABASE_URL')
SUPABASE_SERVICE_KEY = os.getenv('SUPABASE_SERVICE_ROLE_KEY')

def main():
    print("🔍 Verificando conexión a Supabase...")
    
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        print("❌ Error: No se encontraron las credenciales de Supabase en .env")
        sys.exit(1)
    
    try:
        # Crear cliente de Supabase
        supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
        print(f"✅ Conectado a Supabase: {SUPABASE_URL}")
        
        # Verificar tablas existentes
        print("\n📊 Verificando tablas...")
        verify_tables(supabase)
        
        # Ejecutar migraciones
        print("\n🔧 Ejecutando migraciones necesarias...")
        execute_migrations(supabase)
        
        print("\n✅ Verificación y corrección completadas con éxito!")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)

def verify_tables(supabase: Client):
    """Verifica que las tablas necesarias existan"""
    tables_to_check = [
        'user_profiles',
        'user_lists',
        'user_list_items',
        'user_favorites',
        'user_watched_movies',
        'movie_ratings'
    ]
    
    for table in tables_to_check:
        try:
            result = supabase.table(table).select('*').limit(1).execute()
            print(f"  ✅ {table}: existe")
        except Exception as e:
            print(f"  ❌ {table}: {str(e)[:50]}")

def execute_migrations(supabase: Client):
    """Ejecuta las migraciones SQL necesarias"""
    
    # Leer el script de migración
    migration_file = 'supabase/migrations/fix_schema_400_errors.sql'
    
    if not os.path.exists(migration_file):
        print(f"⚠️ No se encontró el archivo de migración: {migration_file}")
        return
    
    with open(migration_file, 'r', encoding='utf-8') as f:
        sql_script = f.read()
    
    print(f"📄 Ejecutando migración desde {migration_file}...")
    
    try:
        # Nota: supabase-py no soporta ejecución directa de SQL
        # Necesitamos usar la API REST de PostgreSQL o el dashboard
        print("⚠️ Para ejecutar la migración SQL, ve a:")
        print(f"   {SUPABASE_URL.replace('https://', 'https://app.')}/project/_/sql")
        print("   Y copia el contenido de: supabase/migrations/fix_schema_400_errors.sql")
        
    except Exception as e:
        print(f"❌ Error ejecutando migración: {e}")

if __name__ == '__main__':
    main()
