/**
 * ALAMEEN CENTER — DRY-RUN ENTITLEMENTS MIGRATION SCRIPT
 *
 * PURPOSE:
 * Audits existing student profiles that have `enrolledCourseIds` but lack
 * explicit `fullCourseEntitlements` or `levelEntitlements` introduced in P6.
 *
 * SAFETY GUARANTEES:
 * - Strictly READ-ONLY (Dry-Run mode by default: DRY_RUN=true).
 * - NEVER modifies production data without explicit admin flag and confirmation.
 * - Supports targeted execution against Firebase Emulator or Firestore REST.
 * - Generates structured JSON and human-readable migration plan.
 */

const http = require('http');

const IS_DRY_RUN = process.env.DRY_RUN !== 'false';
const EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8088';

function parseHostPort(str) {
  const [host, port] = str.split(':');
  return { host, port: parseInt(port || '8088', 10) };
}

function firestoreRequest({ method, path, data, token }) {
  const { host, port } = parseHostPort(EMULATOR_HOST);
  return new Promise((resolve, reject) => {
    const options = {
      hostname: host,
      port: port,
      path: `/v1/projects/elameen/databases/(default)/documents${path}`,
      method: method,
      headers: { 'Content-Type': 'application/json' },
    };
    if (token) options.headers['Authorization'] = `Bearer ${token}`;

    const req = http.request(options, (res) => {
      let body = '';
      res.on('data', (c) => (body += c));
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, data: JSON.parse(body) });
        } catch (_) {
          resolve({ status: res.statusCode, data: body });
        }
      });
    });
    req.on('error', reject);
    if (data) req.write(JSON.stringify(data));
    req.end();
  });
}

function parseFirestoreDoc(doc) {
  const fields = doc.fields || {};
  const obj = { id: doc.name ? doc.name.split('/').pop() : '' };
  for (const [key, val] of Object.entries(fields)) {
    if (val.stringValue !== undefined) obj[key] = val.stringValue;
    else if (val.integerValue !== undefined) obj[key] = parseInt(val.integerValue, 10);
    else if (val.booleanValue !== undefined) obj[key] = val.booleanValue;
    else if (val.arrayValue !== undefined) {
      obj[key] = (val.arrayValue.values || []).map((v) => v.stringValue || v.integerValue || v);
    }
  }
  return obj;
}

async function runDryRunMigration(token) {
  console.log('======================================================================');
  console.log('ALAMEEN CENTER: P6 ENTITLEMENTS MIGRATION (DRY RUN REPORT)');
  console.log(`Execution Mode: ${IS_DRY_RUN ? 'READ-ONLY DRY RUN' : 'PRODUCTION COMMIT'}`);
  console.log(`Target Host: ${EMULATOR_HOST}`);
  console.log('======================================================================\n');

  // 1. Fetch all users
  const res = await firestoreRequest({
    method: 'GET',
    path: '/users',
    token,
  });

  if (res.status !== 200 || !res.data || !res.data.documents) {
    console.log(`No user documents returned or collection is empty (Status: ${res.status}).`);
    return { candidateCount: 0, migrationPlan: [] };
  }

  const users = res.data.documents.map(parseFirestoreDoc);
  const candidates = [];

  for (const user of users) {
    const enrolled = user.enrolledCourseIds || [];
    const full = user.fullCourseEntitlements || [];
    const level = user.levelEntitlements || [];

    // Candidate if enrolled in courses but has no entitlement records
    if (enrolled.length > 0 && full.length === 0 && level.length === 0) {
      candidates.push({
        uid: user.id,
        displayName: user.displayName || 'بدون اسم',
        email: user.email || '',
        enrolledCourseIds: enrolled,
        proposedFullEntitlements: [...enrolled],
        proposedLevelEntitlements: [],
        reason: 'Legacy full-course subscriber: enrolledCourseIds populated prior to P6 schema',
      });
    }
  }

  console.log(`Total Users Evaluated: ${users.length}`);
  console.log(`Migration Candidates Identified: ${candidates.length}\n`);

  if (candidates.length > 0) {
    console.log('--- Proposed Migration Plan ---');
    candidates.forEach((c, idx) => {
      console.log(`[${idx + 1}] Student: ${c.displayName} (${c.uid})`);
      console.log(`    Enrolled Courses: ${JSON.stringify(c.enrolledCourseIds)}`);
      console.log(`    Action: Grant fullCourseEntitlements = ${JSON.stringify(c.proposedFullEntitlements)}`);
      console.log(`    Reason: ${c.reason}\n`);
    });
  } else {
    console.log('All student records are compliant with P6 schema. No migration needed.');
  }

  console.log('======================================================================');
  console.log(`DRY-RUN STATUS: COMPLETE. Modified Documents: 0 (Safety Guaranteed)`);
  console.log('======================================================================\n');

  return { candidateCount: candidates.length, migrationPlan: candidates };
}

if (require.main === module) {
  runDryRunMigration()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error('Migration error:', err);
      process.exit(1);
    });
}

module.exports = { runDryRunMigration };
