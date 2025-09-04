const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error('❌ Error: SUPABASE_URL and SUPABASE_ANON_KEY must be set in .env file');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function testTableExists(tableName) {
  try {
    const { data, error } = await supabase
      .from(tableName)
      .select('*')
      .limit(1);
    
    if (error) {
      console.log(`❌ Table ${tableName}: ${error.message}`);
      return false;
    }
    console.log(`✅ Table ${tableName}: Accessible`);
    return true;
  } catch (err) {
    console.log(`❌ Table ${tableName}: ${err.message}`);
    return false;
  }
}

async function testColumnExists(tableName, columnName) {
  try {
    const { data, error } = await supabase
      .from(tableName)
      .select(columnName)
      .limit(1);
    
    if (error) {
      console.log(`❌ Column ${tableName}.${columnName}: ${error.message}`);
      return false;
    }
    console.log(`✅ Column ${tableName}.${columnName}: Exists`);
    return true;
  } catch (err) {
    console.log(`❌ Column ${tableName}.${columnName}: ${err.message}`);
    return false;
  }
}

async function testSyncOperations() {
  console.log('🔍 Testing Sync Operations...');
  console.log('================================');
  
  // Test table accessibility
  const tables = ['user_favorites', 'user_watchlist', 'user_watched_movies', 'user_lists', 'user_list_items'];
  
  for (const table of tables) {
    await testTableExists(table);
  }
  
  console.log('\n🔍 Testing Critical Columns...');
  console.log('================================');
  
  // Test critical columns
  await testColumnExists('user_favorites', 'last_modified_at');
  await testColumnExists('user_favorites', 'created_at');
  await testColumnExists('user_favorites', 'is_deleted');
  await testColumnExists('user_favorites', 'deleted_at');
  
  await testColumnExists('user_watchlist', 'last_modified_at');
  await testColumnExists('user_watched_movies', 'last_modified_at');
  await testColumnExists('user_lists', 'last_modified_at');
  await testColumnExists('user_list_items', 'last_modified_at');
  
  console.log('\n🔍 Testing Data Operations...');
  console.log('================================');
  
  // Test basic data operations
  try {
    const { count, error } = await supabase
      .from('user_favorites')
      .select('*', { count: 'exact', head: true });
    
    if (error) {
      console.log(`❌ Count user_favorites: ${error.message}`);
    } else {
      console.log(`✅ Count user_favorites: ${count} records`);
    }
  } catch (err) {
    console.log(`❌ Count user_favorites: ${err.message}`);
  }
  
  console.log('\n✅ Sync Operations Test Complete');
}

// Run tests
testSyncOperations().catch(console.error);