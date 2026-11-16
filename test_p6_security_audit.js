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

async function runSecurityAudit() {
  console.log('======================================================================');
  console.log('P6 SECURITY POST-REMEDIATION VERIFICATION SUITE (FIRESTORE EMULATOR)');
  console.log('Testing Project: elameen on 127.0.0.1:8088');
  console.log('======================================================================\n');

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

  const superAdminToken = makeToken('admin_root', { admin: true });
  const viewOnlyAdminToken = makeToken('admin_analyst');
  const studentToken = makeToken('student_alice');
  const studentBobToken = makeToken('student_bob');
  const studentCharlieToken = makeToken('student_charlie');

  // Pre-seed admin_analyst
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

  // Setup: Create a paid multi-level course with protected lessons
  await firestoreRequest({
    method: 'PATCH',
    path: '/courses/course_math_physics_paid',
    token: superAdminToken,
    data: toFields({
      title: 'الفيزياء المتقدمة - دورة شاملة متعددة المستويات',
      accessMode: 'closed',
      price: 1500,
      enrolledCount: 0,
    }),
  });

  // Level 1 protected lesson (Purchased by Alice)
  await firestoreRequest({
    method: 'PATCH',
    path: '/courses/course_math_physics_paid/protected_lessons/lesson_lvl1_intro',
    token: superAdminToken,
    data: toFields({
      levelId: 'lvl_1',
      title: 'المستوى 1: محاضرة الحركة الخطية',
      muxPlaybackId: 'mux_lvl1_secret_playback_token_abc123',
    }),
  });

  // Level 2 protected lesson (NOT purchased by Alice, separate payment level)
  await firestoreRequest({
    method: 'PATCH',
    path: '/courses/course_math_physics_paid/protected_lessons/lesson_lvl2_advanced',
    token: superAdminToken,
    data: toFields({
      levelId: 'lvl_2',
      title: 'المستوى 2: الديناميكا الحرارية والفيزياء النووية',
      muxPlaybackId: 'mux_lvl2_CONFIDENTIAL_playback_token_xyz999',
    }),
  });

  // Free preview lesson in paid course
  await firestoreRequest({
    method: 'PATCH',
    path: '/courses/course_math_physics_paid/protected_lessons/lesson_free_preview',
    token: superAdminToken,
    data: toFields({
      levelId: 'lvl_1',
      title: 'معاينة مجانية للمستوى الأول',
      isFreePreview: true,
      muxPlaybackId: 'mux_free_preview_playback_token',
    }),
  });

  // Legacy lesson with missing levelId in paid course
  await firestoreRequest({
    method: 'PATCH',
    path: '/courses/course_math_physics_paid/protected_lessons/lesson_legacy_no_level',
    token: superAdminToken,
    data: toFields({
      title: 'محاضرة قديمة بدون levelId',
      muxPlaybackId: 'mux_legacy_secret_playback_token',
    }),
  });

  // Seed Alice: Individual level purchase for Level 1 only
  await firestoreRequest({
    method: 'PATCH',
    path: '/users/student_alice',
    token: superAdminToken,
    data: toFields({
      displayName: 'Alice Student',
      email: 'alice@alameen.com',
      role: 'student',
      enrolledCourseIds: ['course_math_physics_paid'],
      levelEntitlements: ['course_math_physics_paid:lvl_1'],
      fullCourseEntitlements: [],
      unlockedLevelIds: [],
      completedLessonIds: [],
      totalWatchSeconds: 0,
      processedSessionEnds: ['initial_sess_001'],
    }),
  });

  // Seed Charlie: Full-course purchase
  await firestoreRequest({
    method: 'PATCH',
    path: '/users/student_charlie',
    token: superAdminToken,
    data: toFields({
      displayName: 'Charlie Full Access',
      email: 'charlie@alameen.com',
      role: 'student',
      enrolledCourseIds: ['course_math_physics_paid'],
      fullCourseEntitlements: ['course_math_physics_paid'],
      levelEntitlements: [],
      unlockedLevelIds: [],
      completedLessonIds: [],
      totalWatchSeconds: 0,
      processedSessionEnds: ['initial_sess_001'],
    }),
  });

  // Seed Bob: Unenrolled student
  await firestoreRequest({
    method: 'PATCH',
    path: '/users/student_bob',
    token: superAdminToken,
    data: toFields({
      displayName: 'Bob Target',
      email: 'bob@alameen.com',
      phone: '01099998888',
      role: 'student',
      enrolledCourseIds: [],
      fullCourseEntitlements: [],
      levelEntitlements: [],
    }),
  });

  // ----------------------------------------------------------------------------------
  // TEST 1: Level-Specific Protected Playback Access (HIGH / RELEASE BLOCKER FIX)
  // ----------------------------------------------------------------------------------
  console.log('--- 1. Level-Specific Protected Playback Access ---');
  {
    // A: Alice (Level 1 only) tries to access Level 2 protected lesson
    const resLvl2 = await firestoreRequest({
      method: 'GET',
      path: '/courses/course_math_physics_paid/protected_lessons/lesson_lvl2_advanced',
      token: studentToken,
    });
    assert(
      resLvl2.status === 403,
      'Student with Level 1 CANNOT read Level 2 protected Mux token (403 Forbidden)',
      `Actual status: ${resLvl2.status}`
    );

    // B: Alice (Level 1 only) accesses Level 1 protected lesson
    const resLvl1 = await firestoreRequest({
      method: 'GET',
      path: '/courses/course_math_physics_paid/protected_lessons/lesson_lvl1_intro',
      token: studentToken,
    });
    assert(
      resLvl1.status === 200,
      'Student with Level 1 CAN read Level 1 protected Mux token (200 OK)',
      `Actual status: ${resLvl1.status}`
    );

    // C: Charlie (Full course entitlement) accesses Level 2 protected lesson
    const resCharlieLvl2 = await firestoreRequest({
      method: 'GET',
      path: '/courses/course_math_physics_paid/protected_lessons/lesson_lvl2_advanced',
      token: studentCharlieToken,
    });
    assert(
      resCharlieLvl2.status === 200,
      'Student with Full Course entitlement CAN read Level 2 protected lesson (200 OK)',
      `Actual status: ${resCharlieLvl2.status}`
    );

    // D: Unenrolled Bob accesses Free Preview lesson
    const resFreePreview = await firestoreRequest({
      method: 'GET',
      path: '/courses/course_math_physics_paid/protected_lessons/lesson_free_preview',
      token: studentBobToken,
    });
    assert(
      resFreePreview.status === 200,
      'Any student CAN read Free Preview lesson in paid course (200 OK)',
      `Actual status: ${resFreePreview.status}`
    );

    // E: Legacy lesson with missing levelId fails closed for Level 1 subscriber
    const resLegacyLvl1 = await firestoreRequest({
      method: 'GET',
      path: '/courses/course_math_physics_paid/protected_lessons/lesson_legacy_no_level',
      token: studentToken,
    });
    assert(
      resLegacyLvl1.status === 403,
      'Legacy lesson with missing levelId FAILS CLOSED for individual level subscriber (403 Forbidden)',
      `Actual status: ${resLegacyLvl1.status}`
    );

    // F: Legacy lesson accessible to Full Course subscriber
    const resLegacyFull = await firestoreRequest({
      method: 'GET',
      path: '/courses/course_math_physics_paid/protected_lessons/lesson_legacy_no_level',
      token: studentCharlieToken,
    });
    assert(
      resLegacyFull.status === 200,
      'Legacy lesson with missing levelId is accessible to Full Course subscriber (200 OK)',
      `Actual status: ${resLegacyFull.status}`
    );
  }

  // ----------------------------------------------------------------------------------
  // TEST 2: Authoritative Entitlement & Privilege Isolation (HIGH FIX)
  // ----------------------------------------------------------------------------------
  console.log('\n--- 2. Authoritative Entitlement & Privilege Isolation ---');
  {
    // A: Alice tries to grant herself fullCourseEntitlements
    const resForgeFull = await firestoreRequest({
      method: 'PATCH',
      path: '/users/student_alice?updateMask.fieldPaths=fullCourseEntitlements',
      token: studentToken,
      data: toFields({
        fullCourseEntitlements: ['course_math_physics_paid'],
      }),
    });
    assert(
      resForgeFull.status === 403,
      'Student CANNOT forge fullCourseEntitlements (403 Forbidden)',
      `Actual status: ${resForgeFull.status}`
    );

    // B: Alice tries to grant herself levelEntitlements for Level 2
    const resForgeLvl2 = await firestoreRequest({
      method: 'PATCH',
      path: '/users/student_alice?updateMask.fieldPaths=levelEntitlements',
      token: studentToken,
      data: toFields({
        levelEntitlements: ['course_math_physics_paid:lvl_1', 'course_math_physics_paid:lvl_2'],
      }),
    });
    assert(
      resForgeLvl2.status === 403,
      'Student CANNOT forge levelEntitlements (403 Forbidden)',
      `Actual status: ${resForgeLvl2.status}`
    );

    // C: Alice tries to forge certifiedCourseIds
    const resForgeCert = await firestoreRequest({
      method: 'PATCH',
      path: '/users/student_alice?updateMask.fieldPaths=certifiedCourseIds',
      token: studentToken,
      data: toFields({
        certifiedCourseIds: ['course_math_physics_paid'],
      }),
    });
    assert(
      resForgeCert.status === 403,
      'Student CANNOT forge certificate / certifiedCourseIds (403 Forbidden)',
      `Actual status: ${resForgeCert.status}`
    );

    // D: Even if Alice marks completedLessonIds with Level 2 lesson, she still cannot access Level 2 protected lesson
    await firestoreRequest({
      method: 'PATCH',
      path: '/users/student_alice?updateMask.fieldPaths=completedLessonIds',
      token: studentToken,
      data: toFields({
        completedLessonIds: ['lesson_lvl2_advanced'],
      }),
    });
    const resLvl2AfterCheckmark = await firestoreRequest({
      method: 'GET',
      path: '/courses/course_math_physics_paid/protected_lessons/lesson_lvl2_advanced',
      token: studentToken,
    });
    assert(
      resLvl2AfterCheckmark.status === 403,
      'Forged client completedLessonIds CANNOT unlock protected lesson playback (403 Forbidden)',
      `Actual status: ${resLvl2AfterCheckmark.status}`
    );
  }

  // ----------------------------------------------------------------------------------
  // TEST 3: Replay Protection Cache Integrity (HIGH FIX)
  // ----------------------------------------------------------------------------------
  console.log('\n--- 3. Replay Protection Sliding Window Cache Integrity ---');
  {
    // A: Alice attempts to wipe processedSessionEnds array
    const resWipe = await firestoreRequest({
      method: 'PATCH',
      path: '/users/student_alice?updateMask.fieldPaths=processedSessionEnds',
      token: studentToken,
      data: toFields({
        processedSessionEnds: [],
      }),
    });
    assert(
      resWipe.status === 403,
      'Student CANNOT wipe processedSessionEnds array to reset replay cache (403 Forbidden)',
      `Actual status: ${resWipe.status}`
    );

    // B: Legitimate append to processedSessionEnds is allowed
    const resAppend = await firestoreRequest({
      method: 'PATCH',
      path: '/users/student_alice?updateMask.fieldPaths=processedSessionEnds',
      token: studentToken,
      data: toFields({
        processedSessionEnds: ['initial_sess_001', 'sess_new_002'],
      }),
    });
    assert(
      resAppend.status === 200,
      'Legitimate append to processedSessionEnds is ALLOWED (200 OK)',
      `Actual status: ${resAppend.status}`
    );
  }

  // ----------------------------------------------------------------------------------
  // TEST 4: Student Privacy & Active Watch Sessions Directory Isolation (HIGH FIX)
  // ----------------------------------------------------------------------------------
  console.log('\n--- 4. Active Watch Sessions Privacy & Directory Isolation ---');
  {
    // Seed Bob's active watch session
    await firestoreRequest({
      method: 'PATCH',
      path: '/active_watch_sessions/sess_bob_active',
      token: studentBobToken,
      data: toFields({
        studentId: 'student_bob',
        studentName: 'Bob Target',
        studentEmail: 'bob@alameen.com',
        studentPhone: '01099998888',
        ipAddress: '197.34.120.45',
        isPlaying: true,
      }),
    });

    // A: Student Alice attempts broad list of /active_watch_sessions
    const resListSessions = await firestoreRequest({
      method: 'GET',
      path: '/active_watch_sessions',
      token: studentToken,
    });
    assert(
      resListSessions.status === 403,
      'Student CANNOT list /active_watch_sessions directory of peers (403 Forbidden)',
      `Actual status: ${resListSessions.status}`
    );

    // B: Student Alice attempts direct read of Bob's active watch session
    const resGetBobSession = await firestoreRequest({
      method: 'GET',
      path: '/active_watch_sessions/sess_bob_active',
      token: studentToken,
    });
    assert(
      resGetBobSession.status === 403,
      'Student CANNOT read peer student active watch session doc (403 Forbidden)',
      `Actual status: ${resGetBobSession.status}`
    );

    // C: Student Alice CAN create and read her own active session
    await firestoreRequest({
      method: 'PATCH',
      path: '/active_watch_sessions/sess_alice_active',
      token: studentToken,
      data: toFields({
        studentId: 'student_alice',
        studentName: 'Alice Student',
        isPlaying: true,
      }),
    });
    const resGetAliceSession = await firestoreRequest({
      method: 'GET',
      path: '/active_watch_sessions/sess_alice_active',
      token: studentToken,
    });
    assert(
      resGetAliceSession.status === 200,
      'Student CAN read her own active watch session doc (200 OK)',
      `Actual status: ${resGetAliceSession.status}`
    );

    // D: Admin with view_analytics CAN list /active_watch_sessions
    const resAdminList = await firestoreRequest({
      method: 'GET',
      path: '/active_watch_sessions',
      token: viewOnlyAdminToken,
    });
    assert(
      resAdminList.status === 200,
      'Admin with view_analytics CAN list /active_watch_sessions for live radar (200 OK)',
      `Actual status: ${resAdminList.status}`
    );
  }

  // ----------------------------------------------------------------------------------
  // TEST 5: Watch Logs Immutability of sessionEndCommitted Flag
  // ----------------------------------------------------------------------------------
  console.log('\n--- 5. Watch Logs sessionEndCommitted Flag Immutability ---');
  {
    // Create committed watch log
    await firestoreRequest({
      method: 'PATCH',
      path: '/watch_logs/watch_alice_session_committed',
      token: studentToken,
      data: toFields({
        studentId: 'student_alice',
        courseId: 'course_math_physics_paid',
        lessonId: 'lesson_lvl1_intro',
        durationSeconds: 1200,
        secondsWatched: 1200,
        sessionEndCommitted: true,
      }),
    });

    // Alice attempts to flip sessionEndCommitted back to false
    const resFlip = await firestoreRequest({
      method: 'PATCH',
      path: '/watch_logs/watch_alice_session_committed',
      token: studentToken,
      data: toFields({
        sessionEndCommitted: false,
      }),
    });
    assert(
      resFlip.status === 403,
      'Student CANNOT uncommit or reset sessionEndCommitted flag in watch_logs (403 Forbidden)',
      `Actual status: ${resFlip.status}`
    );
  }

  console.log('\n======================================================================');
  console.log(`SECURITY VERIFICATION SUMMARY: ${passed} PASSED, ${failed} FAILED`);
  console.log('======================================================================');

  if (failed > 0) {
    process.exit(1);
  }
  return passed;
}

runSecurityAudit()
  .then((count) => {
    console.log(`\nAll ${count} security checks PASSED cleanly!`);
    process.exit(0);
  })
  .catch((err) => {
    console.error('Audit execution error:', err);
    process.exit(1);
  });
