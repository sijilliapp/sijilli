#!/usr/bin/env node

/**
 * Cleanup script to permanently delete soft-deleted records older than 30 days.
 * Targets both 'articles' and 'invitations' collections.
 * 
 * Usage:
 *   node scripts/cleanup_trash.js <pocketbase-url> <admin-email> <admin-password>
 * Or set environment variables:
 *   export PB_URL="https://sijilli.pockethost.io"
 *   export PB_ADMIN_EMAIL="admin@sijilli.com"
 *   export PB_ADMIN_PASSWORD="securepassword"
 *   node scripts/cleanup_trash.js
 */

const fs = require('fs');

async function main() {
  const pbUrl = process.argv[2] || process.env.PB_URL || 'https://sijilli.pockethost.io';
  const adminEmail = process.argv[3] || process.env.PB_ADMIN_EMAIL;
  const adminPassword = process.argv[4] || process.env.PB_ADMIN_PASSWORD;

  if (!adminEmail || !adminPassword) {
    console.error('❌ Error: PocketBase admin email and password are required.');
    console.error('Usage: node scripts/cleanup_trash.js <pb-url> <admin-email> <admin-password>');
    console.error('Or set PB_ADMIN_EMAIL and PB_ADMIN_PASSWORD environment variables.');
    process.exit(1);
  }

  const cleanPbUrl = pbUrl.replace(/\/$/, ''); // strip trailing slash
  console.log(`🧹 Starting cleanup for PocketBase: ${cleanPbUrl}`);

  // 1. Authenticate as Admin
  let adminToken;
  try {
    const response = await fetch(`${cleanPbUrl}/api/admins/auth-with-password`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ identity: adminEmail, password: adminPassword }),
    });

    if (!response.ok) {
      const errText = await response.text();
      throw new Error(`Admin authentication failed: ${response.status} - ${errText}`);
    }

    const data = await response.json();
    adminToken = data.token;
    console.log('✅ Admin authenticated successfully.');
  } catch (error) {
    console.error('❌ Authentication failed:', error.message);
    process.exit(1);
  }

  // Calculate 30-day threshold date
  const thresholdDate = new Date();
  thresholdDate.setDate(thresholdDate.getDate() - 30);
  const thresholdIso = thresholdDate.toISOString();
  console.log(`📅 Deleting records soft-deleted before: ${thresholdIso} (older than 30 days)`);

  const headers = {
    'Authorization': adminToken,
    'Content-Type': 'application/json',
  };

  // 2. Cleanup Articles
  await cleanupCollection(cleanPbUrl, 'articles', thresholdIso, headers);

  // 3. Cleanup Invitations
  await cleanupCollection(cleanPbUrl, 'invitations', thresholdIso, headers);

  console.log('🎉 Cleanup process complete.');
}

async function cleanupCollection(pbUrl, collectionName, thresholdIso, headers) {
  console.log(`\n🔍 Scanning collection '${collectionName}'...`);
  
  // Format filter query parameter: post_status = 'trash' && deleted_at <= 'thresholdIso'
  const filter = `post_status = "trash" && deleted_at <= "${thresholdIso}"`;
  const encodedFilter = encodeURIComponent(filter);

  try {
    const listUrl = `${pbUrl}/api/collections/${collectionName}/records?filter=${encodedFilter}&perPage=200`;
    const response = await fetch(listUrl, { headers });

    if (!response.ok) {
      const errText = await response.text();
      console.error(`❌ Failed to fetch records for '${collectionName}':`, errText);
      return;
    }

    const result = await response.json();
    const records = result.items || [];

    if (records.length === 0) {
      console.log(`✨ No old trashed records found in '${collectionName}'.`);
      return;
    }

    console.log(`🗑️ Found ${records.length} records to permanently delete in '${collectionName}'.`);

    let successCount = 0;
    for (const record of records) {
      const deleteUrl = `${pbUrl}/api/collections/${collectionName}/records/${record.id}`;
      try {
        const delResponse = await fetch(deleteUrl, { method: 'DELETE', headers });
        if (delResponse.ok) {
          successCount++;
        } else {
          const errText = await delResponse.text();
          console.error(`⚠️ Failed to delete record ${record.id}:`, errText);
        }
      } catch (err) {
        console.error(`⚠️ Network error deleting record ${record.id}:`, err.message);
      }
    }

    console.log(`✅ Permanently deleted ${successCount}/${records.length} records from '${collectionName}'.`);
  } catch (error) {
    console.error(`❌ Error cleaning collection '${collectionName}':`, error.message);
  }
}

main();
