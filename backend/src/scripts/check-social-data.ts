import pool from '../config/database.js';

async function checkSocialData() {
  try {
    console.log('Checking social data...\n');
    
    // Check study groups
    const groups = await pool.query('SELECT * FROM study_groups ORDER BY created_at DESC');
    console.log(`📚 Study Groups: ${groups.rows.length}`);
    if (groups.rows.length > 0) {
      groups.rows.forEach(g => {
        console.log(`  - ID: ${g.id}`);
        console.log(`    Name: ${g.name} (${g.icon})`);
        console.log(`    Owner: ${g.owner_id}`);
      });
    }
    
    // Check friendships
    const friendships = await pool.query('SELECT * FROM friendships ORDER BY created_at DESC');
    console.log(`\n👥 Friendships: ${friendships.rows.length}`);
    if (friendships.rows.length > 0) {
      friendships.rows.forEach(f => {
        console.log(`  - ${f.user_id} <-> ${f.friend_id} (${f.status})`);
      });
    }
    
    // Check group members with details
    const members = await pool.query(`
      SELECT m.*, g.name as group_name, u.display_name as user_name
      FROM study_group_members m
      JOIN study_groups g ON g.id = m.group_id
      JOIN users u ON u.id = m.user_id
    `);
    console.log(`\n👤 Group Members: ${members.rows.length}`);
    if (members.rows.length > 0) {
      members.rows.forEach(m => {
        console.log(`  - ${m.user_name} in "${m.group_name}" as ${m.role}`);
        console.log(`    User ID: ${m.user_id}`);
        console.log(`    Group ID: ${m.group_id}`);
      });
    }
    
    // Check activities
    const activities = await pool.query('SELECT * FROM activities ORDER BY created_at DESC LIMIT 10');
    console.log(`\n📝 Recent Activities: ${activities.rows.length}`);
    
    // Check group invitations
    const invitations = await pool.query('SELECT * FROM group_invitations');
    console.log(`\n📨 Group Invitations: ${invitations.rows.length}`);
    
    // Check current user
    const users = await pool.query('SELECT id, display_name, email FROM users LIMIT 5');
    console.log(`\n👤 Users (first 5):`);
    users.rows.forEach(u => {
      console.log(`  - ${u.display_name} (${u.email})`);
      console.log(`    ID: ${u.id}`);
    });
    
    console.log('\n✅ Check complete!');
  } catch (error) {
    console.error('Error:', error);
  } finally {
    await pool.end();
  }
}

checkSocialData();
