const http = require('http');

function base64Url(str) {
  return Buffer.from(str).toString('base64url');
}

function makeToken(uid, customClaims = {}) {
  const header = JSON.stringify({ alg: 'none', typ: 'JWT' });
  const payload = JSON.stringify({
    user_id: uid,
    sub: uid,
    uid: uid,
    ...customClaims,
  });
  return `${base64Url(header)}.${base64Url(payload)}.`;
}

function firestoreRequest({ method, path, data, token }) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: '127.0.0.1',
      port: 8088,
      path: `/v1/projects/elameen/databases/(default)/documents${path}`,
      method: method,
      headers: {
        'Content-Type': 'application/json',
      },
    };

    if (token) {
      options.headers['Authorization'] = `Bearer ${token}`;
    }

    const req = http.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => (body += chunk));
      res.on('end', () => {
        let parsed = null;
        try {
          parsed = JSON.parse(body);
        } catch (_) {
          parsed = body;
        }
        resolve({ status: res.statusCode, data: parsed });
      });
    });

    req.on('error', reject);
    if (data) {
      req.write(JSON.stringify(data));
    }
    req.end();
  });
}

// Convert plain JSON to Firestore REST API fields format
function toFields(obj) {
  const fields = {};
  for (const [key, val] of Object.entries(obj)) {
    if (typeof val === 'string') {
      fields[key] = { stringValue: val };
    } else if (typeof val === 'number') {
      if (Number.isInteger(val)) {
        fields[key] = { integerValue: val.toString() };
      } else {
        fields[key] = { doubleValue: val };
      }
    } else if (typeof val === 'boolean') {
      fields[key] = { booleanValue: val };
    } else if (Array.isArray(val)) {
      fields[key] = {
        arrayValue: {
          values: val.map((v) => {
            if (typeof v === 'string') return { stringValue: v };
            if (typeof v === 'number') return { integerValue: v.toString() };
            return { stringValue: String(v) };
          }),
        },
      };
    } else if (val === null) {
      fields[key] = { nullValue: null };
    }
  }
  return { fields };
}

async function runTests() {
  console.log('===============================================================');
  console.log('FIRESTORE EMULATOR SECURITY RULES REAL VALIDATION SUITE');
  console.log('Testing Project: elameen on 127.0.0.1:8088');
  console.log('===============================================================\n');

  let passed = 0;
  let failed = 0;

  function assert(condition, description, detail = '') {
    if (condition) {
      console.log(`[PASS] ${description}`);
      passed++;
    } else {
      console.error(`[FAIL] ${description} | Detail: ${detail}`);
      failed++;
    }
  }

  const studentToken = makeToken('student_alice');
  const studentBobToken = makeToken('student_bob');
  const superAdminToken = makeToken('admin_root', { admin: true });
  const viewOnlyAdminToken = makeToken('admin_analyst');

  // Pre-seed an admin document for admin_analyst with only view_analytics permission
  await firestoreRequest({
    method: 'PATCH',
    path: '/admins/admin_analyst',
    token: superAdminToken,
    data: toFields({
      isActive: true,
      role: 'staff',
      permissions: ['view_analytics'],
    }),
  });

  // Pre-seed a closed course
  await firestoreRequest({
    method: 'PATCH',
    path: '/courses/course_chemistry_paid',
    token: superAdminToken,
    data: toFields({
      title: 'الكيمياء المتقدمة',
      accessMode: 'closed',
      enrolledCount: 10,
    }),
  });

  // Pre-seed an open course
  await firestoreRequest({
    method: 'PATCH',
    path: '/courses/course_math_open',
    token: superAdminToken,
    data: toFields({
      title: 'مقدمة في الجبر (مفتوح)',
      accessMode: 'open',
      enrolledCount: 25,
    }),
  });

  // --- TEST GROUP 1: UNAUTHENTICATED ACCESS ---
  console.log('\n--- 1. Unauthenticated Access Controls ---');
  {
    // Unauthenticated read of public catalog
    const res = await firestoreRequest({
      method: 'GET',
      path: '/courses/course_math_open',
    });
    assert(res.status === 200, 'Unauthenticated user CAN read public course metadata');

    // Unauthenticated read of protected lesson playback
    const res2 = await firestoreRequest({
      method: 'GET',
      path: '/courses/course_chemistry_paid/protected_lessons/lesson_1',
    });
    assert(res2.status === 403, 'Unauthenticated user CANNOT read protected lesson URL (403)');

    // Unauthenticated write to users
    const res3 = await firestoreRequest({
      method: 'PATCH',
      path: '/users/student_anon',
      data: toFields({ displayName: 'Hacker' }),
    });
    assert(res3.status === 403, 'Unauthenticated user CANNOT create or update user profile (403)');
  }

  // --- TEST GROUP 2: STUDENT PRIVILEGE ESCALATION PREVENTION ---
  console.log('\n--- 2. Student Privilege Escalation & Field Allowlist ---');
  {
    // Student creates legitimate profile
    const createRes = await firestoreRequest({
      method: 'PATCH',
      path: '/users/student_alice',
      token: studentToken,
      data: toFields({
        displayName: 'Alice Student',
        phone: '01012345678',
        role: 'student',
        enrolledCourseIds: [],
        totalWatchSeconds: 0,
        completedLessonIds: [],
      }),
    });
    assert(createRes.status === 200, 'Student CAN create own initial profile with role=student');

    // Escalation Attempt A: Student tries to give themselves isAdmin: true
    const hackAdminRes = await firestoreRequest({
      method: 'PATCH',
      path: '/users/student_alice?updateMask.fieldPaths=isAdmin',
      token: studentToken,
      data: toFields({ isAdmin: true }),
    });
    assert(hackAdminRes.status === 403, 'Student CANNOT escalate to isAdmin: true (403)');

    // Escalation Attempt B: Student tries to modify role to 'admin'
    const hackRoleRes = await firestoreRequest({
      method: 'PATCH',
      path: '/users/student_alice?updateMask.fieldPaths=role',
      token: studentToken,
      data: toFields({ role: 'admin' }),
    });
    assert(hackRoleRes.status === 403, 'Student CANNOT modify role to admin (403)');

    // Escalation Attempt C: Student tries to unblock themselves
    const hackBlockRes = await firestoreRequest({
      method: 'PATCH',
      path: '/users/student_alice?updateMask.fieldPaths=isBlocked',
      token: studentToken,
      data: toFields({ isBlocked: false }),
    });
    assert(hackBlockRes.status === 403, 'Student CANNOT modify isBlocked field (403)');

    // Escalation Attempt D: Student tries to forge certificate eligibility
    const hackCertRes = await firestoreRequest({
      method: 'PATCH',
      path: '/users/student_alice?updateMask.fieldPaths=certificateEligible',
      token: studentToken,
      data: toFields({ certificateEligible: true }),
    });
    assert(hackCertRes.status === 403, 'Student CANNOT inject arbitrary/certificate fields (403)');

    // Escalation Attempt E: Student tries to enroll in a CLOSED course directly
    const hackClosedEnrollRes = await firestoreRequest({
      method: 'PATCH',
      path: '/users/student_alice?updateMask.fieldPaths=enrolledCourseIds&updateMask.fieldPaths=lastEnrolledCourseId',
      token: studentToken,
      data: toFields({
        enrolledCourseIds: ['course_chemistry_paid'],
        lastEnrolledCourseId: 'course_chemistry_paid',
      }),
    });
    assert(hackClosedEnrollRes.status === 403, 'Student CANNOT enroll themselves in a closed course (403)');

    // Legitimate Enrollment: Student enrolls in an OPEN course
    const validOpenEnrollRes = await firestoreRequest({
      method: 'PATCH',
      path: '/users/student_alice?updateMask.fieldPaths=enrolledCourseIds&updateMask.fieldPaths=lastEnrolledCourseId',
      token: studentToken,
      data: toFields({
        enrolledCourseIds: ['course_math_open'],
        lastEnrolledCourseId: 'course_math_open',
      }),
    });
    assert(validOpenEnrollRes.status === 200, 'Student CAN enroll in verified open course');
  }

  // --- TEST GROUP 3: WATCH LOG INTEGRITY & SPOOFING PREVENTION ---
  console.log('\n--- 3. Watch Log Integrity & Spoofing Prevention ---');
  {
    // Valid log creation by student_alice
    const logRes = await firestoreRequest({
      method: 'PATCH',
      path: '/watch_logs/watch_alice_math_l1_sess1',
      token: studentToken,
      data: toFields({
        id: 'watch_alice_math_l1_sess1',
        studentId: 'student_alice',
        courseId: 'course_math_open',
        lessonId: 'lesson_1',
        durationSeconds: 300,
        secondsWatched: 300,
      }),
    });
    assert(logRes.status === 200, 'Student CAN create own watch log with valid duration');

    // Spoofing Attempt A: student_bob tries to overwrite student_alice's watch log
    const spoofRes = await firestoreRequest({
      method: 'PATCH',
      path: '/watch_logs/watch_alice_math_l1_sess1',
      token: studentBobToken,
      data: toFields({
        durationSeconds: 900,
        secondsWatched: 900,
      }),
    });
    assert(spoofRes.status === 403, 'Different student CANNOT overwrite another student log (403)');

    // Spoofing Attempt B: student_alice tries to log a forged 50-hour session (180,000s > 14,400s)
    const forgeDurationRes = await firestoreRequest({
      method: 'PATCH',
      path: '/watch_logs/watch_alice_math_l1_sess2',
      token: studentToken,
      data: toFields({
        studentId: 'student_alice',
        courseId: 'course_math_open',
        lessonId: 'lesson_1',
        durationSeconds: 180000,
        secondsWatched: 180000,
      }),
    });
    assert(forgeDurationRes.status === 403, 'Student CANNOT forge duration exceeding 14,400s limit (403)');

    // Monotonic Duration: student_alice updates log to 600s (greater than 300s)
    const validProgressRes = await firestoreRequest({
      method: 'PATCH',
      path: '/watch_logs/watch_alice_math_l1_sess1',
      token: studentToken,
      data: toFields({
        studentId: 'student_alice',
        courseId: 'course_math_open',
        lessonId: 'lesson_1',
        durationSeconds: 600,
        secondsWatched: 600,
      }),
    });
    assert(validProgressRes.status === 200, 'Student CAN increase progress to 600s');

    // Regressive Duration Attempt: student_alice tries to regress duration from 600s to 100s
    const regressiveRes = await firestoreRequest({
      method: 'PATCH',
      path: '/watch_logs/watch_alice_math_l1_sess1',
      token: studentToken,
      data: toFields({
        studentId: 'student_alice',
        courseId: 'course_math_open',
        lessonId: 'lesson_1',
        durationSeconds: 100,
        secondsWatched: 100,
      }),
    });
    assert(regressiveRes.status === 403, 'Student CANNOT regress watch duration (403)');
  }

  // --- TEST GROUP 4: ADMINISTRATIVE READ-ONLY WRITE RESTRICTION ---
  console.log('\n--- 4. Administrative Read-Only Write Restriction ---');
  {
    // Admin with view_analytics CAN read logs
    const adminReadRes = await firestoreRequest({
      method: 'GET',
      path: '/watch_logs/watch_alice_math_l1_sess1',
      token: viewOnlyAdminToken,
    });
    assert(adminReadRes.status === 200, 'Admin with view_analytics CAN read watch logs');

    // Admin with view_analytics CANNOT update watch logs
    const adminUpdateRes = await firestoreRequest({
      method: 'PATCH',
      path: '/watch_logs/watch_alice_math_l1_sess1',
      token: viewOnlyAdminToken,
      data: toFields({ durationSeconds: 1200 }),
    });
    assert(adminUpdateRes.status === 403, 'Admin with view_analytics CANNOT update watch logs (403)');

    // Admin with view_analytics CANNOT delete watch logs
    const adminDeleteRes = await firestoreRequest({
      method: 'DELETE',
      path: '/watch_logs/watch_alice_math_l1_sess1',
      token: viewOnlyAdminToken,
    });
    assert(adminDeleteRes.status === 403, 'Admin with view_analytics CANNOT delete watch logs (403)');
  }

  console.log('\n===============================================================');
  console.log(`EMULATOR TEST SUITE SUMMARY: ${passed} PASSED, ${failed} FAILED`);
  console.log('===============================================================');

  if (failed > 0) {
    process.exit(1);
  }
}

runTests().catch((err) => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
