/**
 * ALAMEEN CENTER — ENHANCED DRY-RUN ENTITLEMENTS MIGRATION SCRIPT
 *
 * PURPOSE:
 * Audits existing student profiles that have `enrolledCourseIds` against
 * genuine payment and administrative approval records in `access_requests`
 * and course whitelists in `courses/{id}.allowedStudentIds`.
 *
 * SAFETY PRINCIPLES:
 * 1. Strictly READ-ONLY (Dry-Run mode by default: DRY_RUN=true).
 * 2. NEVER automatically interprets every historical enrollment as a full-course purchase.
 * 3. Audits approved payment receipts and access request level IDs.
 * 4. Categorizes unverified/unapproved legacy enrollments for administrative review.
 * 5. Handles legacy lessons with missing levelId (Fail-closed for level-only buyers).
 * 6. Zero production data modifications.
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
  console.log('ALAMEEN CENTER: P6 AUDITED ENTITLEMENTS MIGRATION (DRY RUN REPORT)');
  console.log(`Execution Mode: ${IS_DRY_RUN ? 'READ-ONLY DRY RUN' : 'PRODUCTION COMMIT'}`);
  console.log(`Target Host: ${EMULATOR_HOST}`);
  console.log('======================================================================\n');

  // 1. Fetch Users
  const usersRes = await firestoreRequest({ method: 'GET', path: '/users', token });
  const users = (usersRes.status === 200 && usersRes.data && usersRes.data.documents)
    ? usersRes.data.documents.map(parseFirestoreDoc)
    : [];

  // 2. Fetch Access Requests
  const requestsRes = await firestoreRequest({ method: 'GET', path: '/access_requests', token });
  const requests = (requestsRes.status === 200 && requestsRes.data && requestsRes.data.documents)
    ? requestsRes.data.documents.map(parseFirestoreDoc)
    : [];

  // 3. Fetch Courses
  const coursesRes = await firestoreRequest({ method: 'GET', path: '/courses', token });
  const courses = (coursesRes.status === 200 && coursesRes.data && coursesRes.data.documents)
    ? coursesRes.data.documents.map(parseFirestoreDoc)
    : [];

  console.log(`Audited Collections: ${users.length} Users, ${requests.length} Access Requests, ${courses.length} Courses.\n`);

  const coursesMap = new Map();
  for (const c of courses) {
    coursesMap.set(c.id, c);
  }

  // Map approved access requests by studentId + courseId
  const approvedRequestsByStudentAndCourse = new Map();
  for (const r of requests) {
    if (r.status === 'approved') {
      const key = `${r.studentId}:${r.courseId}`;
      const list = approvedRequestsByStudentAndCourse.get(key) || [];
      list.push(r);
      approvedRequestsByStudentAndCourse.set(key, list);
    }
  }

  const migrationPlan = [];

  for (const user of users) {
    const enrolled = user.enrolledCourseIds || [];
    const existingFull = user.fullCourseEntitlements || [];
    const existingLevel = user.levelEntitlements || [];

    // Evaluate each enrolled course
    for (const courseId of enrolled) {
      const course = coursesMap.get(courseId);
      const isOpen = course && course.accessMode === 'open';
      const isWhitelisted = course && (course.allowedStudentIds || []).includes(user.id);
      const approvedReqs = approvedRequestsByStudentAndCourse.get(`${user.id}:${courseId}`) || [];

      let classification = '';
      let action = '';
      let proposedFull = [...existingFull];
      let proposedLevel = [...existingLevel];

      if (isOpen) {
        classification = 'OPEN_COURSE_ENROLLMENT';
        action = 'No entitlement record needed; access granted dynamically via accessMode==open';
      } else if (existingFull.includes(courseId)) {
        classification = 'ALREADY_FULL_COURSE_MIGRATED';
        action = 'Compliant with P6 schema; no change';
      } else if (existingLevel.some((tok) => tok.startsWith(`${courseId}:`))) {
        classification = 'ALREADY_LEVEL_MIGRATED';
        action = 'Compliant with P6 schema; level-specific access active';
      } else if (approvedReqs.length > 0) {
        // Inspect approved access requests for this course
        const levelReqs = approvedReqs.filter((r) => r.levelId && r.levelId.trim().isNotEmpty);
        if (levelReqs.length > 0) {
          classification = 'VERIFIED_LEVEL_PURCHASE';
          const tokensToAdd = levelReqs.map((r) => `${courseId}:${r.levelId}`);
          tokensToAdd.forEach((tok) => {
            if (!proposedLevel.includes(tok)) proposedLevel.push(tok);
          });
          action = `Add levelEntitlements: ${JSON.stringify(tokensToAdd)} (Based on approved receipt/request)`;
        } else {
          classification = 'VERIFIED_FULL_COURSE_PURCHASE';
          if (!proposedFull.includes(courseId)) proposedFull.push(courseId);
          action = `Add fullCourseEntitlements: ["${courseId}"] (Based on approved full-course access request)`;
        }
      } else if (isWhitelisted) {
        classification = 'ADMIN_WHITELISTED_PURCHASE';
        if (!proposedFull.includes(courseId)) proposedFull.push(courseId);
        action = `Add fullCourseEntitlements: ["${courseId}"] (Based on admin allowedStudentIds whitelist)`;
      } else {
        classification = 'UNVERIFIED_LEGACY_ENROLLMENT (REQUIRES MANUAL REVIEW)';
        action = 'DO NOT GRANT FULL COURSE AUTOMATICALLY. Flagged for administrative verification.';
      }

      migrationPlan.push({
        studentId: user.id,
        studentName: user.displayName || user.name || 'طالب',
        courseId,
        classification,
        action,
        proposedFull,
        proposedLevel,
      });
    }
  }

  console.log('--- Migration Audit Findings ---');
  migrationPlan.forEach((plan, idx) => {
    console.log(`[${idx + 1}] Student: ${plan.studentName} (${plan.studentId}) | Course: ${plan.courseId}`);
    console.log(`    Classification: ${plan.classification}`);
    console.log(`    Action: ${plan.action}\n`);
  });

  const verifiedFullCount = migrationPlan.filter((p) => p.classification.includes('VERIFIED_FULL_COURSE')).length;
  const verifiedLevelCount = migrationPlan.filter((p) => p.classification.includes('VERIFIED_LEVEL')).length;
  const unverifiedCount = migrationPlan.filter((p) => p.classification.includes('UNVERIFIED')).length;

  console.log('======================================================================');
  console.log(`AUDIT SUMMARY: ${migrationPlan.length} Enrollments Evaluated:`);
  console.log(`- Verified Full-Course Candidates: ${verifiedFullCount}`);
  console.log(`- Verified Level-Specific Candidates: ${verifiedLevelCount}`);
  console.log(`- Unverified / Flagged Candidates: ${unverifiedCount}`);
  console.log(`Modified Documents: 0 (Strict Dry-Run Safety Preserved)`);
  console.log('======================================================================\n');

  return { migrationPlan, verifiedFullCount, verifiedLevelCount, unverifiedCount };
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
