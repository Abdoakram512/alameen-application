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
  console.log('P6 DEFINITIVE COMPREHENSIVE SECURITY VERIFICATION SUITE');
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

  // Setup 1: Paid multi-level sequential course
  await firestoreRequest({
    method: 'PATCH',
    path: '/courses/course_math_physics_paid',
    token: superAdminToken,
    data: toFields({
      title: 'الفيزياء المتقدمة - دورة شاملة متعددة المستويات (تتابعي)',
      accessMode: 'closed',
      price: 1500,
      enrolledCount: 0,
    }),
  });

  // Level 1 protected lesson (Level order 1)
  await firestoreRequest({
    method: 'PATCH',
    path: '/courses/course_math_physics_paid/protected_lessons/lesson_lvl1_intro',
    token: superAdminToken,
    data: toFields({
      levelId: 'lvl_1',
      levelOrder: 1,
      isSequential: true,
      title: 'المستوى 1: محاضرة الحركة الخطية',
      muxPlaybackId: 'mux_lvl1_secret_playback_token_abc123',
    }),
  });

  // Level 2 protected lesson (Level order 2 - Sequential progression)
  await firestoreRequest({
    method: 'PATCH',
    path: '/courses/course_math_physics_paid/protected_lessons/lesson_lvl2_advanced',
    token: superAdminToken,
    data: toFields({
      levelId: 'lvl_2',
      levelOrder: 2,
      isSequential: true,
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
      levelOrder: 1,
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

  // Seed Charlie: Full-course purchase (starts with only Level 1 unlocked sequentially)
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

  // ==================================================================================
  // 1. COMPLETION FORGERY & ENTITLEMENT CONSISTENCY
  // ==================================================================================
  console.log('\n--- 1. Completion Forgery vs Authoritative Gating ---');
  {
    // A: Student appends to completedLessonIds directly (changing NO other fields)
    const resAppendCompleted = await firestoreRequest({
      method: 'PATCH',
      path: '/users/student_alice?updateMask.fieldPaths=completedLessonIds',
      token: studentToken,
      data: toFields({
        completedLessonIds: ['lesson_lvl1_intro', 'lesson_lvl2_advanced'],
      }),
    });
    assert(
      resAppendCompleted.status === 200,
      'Student CAN append completedLessonIds directly (200 OK) for personal client checkmarks',
      `Actual status: ${resAppendCompleted.status}`
    );

    // B: Does forged completedLessonIds unlock Level 2 protected lesson?
    const resLvl2Attempt = await firestoreRequest({
      method: 'GET',
      path: '/courses/course_math_physics_paid/protected_lessons/lesson_lvl2_advanced',
      token: studentToken,
    });
    assert(
      resLvl2Attempt.status === 403,
      'Forged completedLessonIds CANNOT unlock Level 2 protected playback (403 Forbidden)',
      `Actual status: ${resLvl2Attempt.status}`
    );

    // C: Student attempts to directly grant themselves certifiedCourseIds
    const resCertForge = await firestoreRequest({
      method: 'PATCH',
      path: '/users/student_alice?updateMask.fieldPaths=certifiedCourseIds',
      token: studentToken,
      data: toFields({
        certifiedCourseIds: ['course_math_physics_paid'],
      }),
    });
    assert(
      resCertForge.status === 403,
      'Student CANNOT forge authoritative certificate / certifiedCourseIds (403 Forbidden)',
      `Actual status: ${resCertForge.status}`
    );

    // D: Student attempts to directly grant themselves fullCourseEntitlements
    const resFullForge = await firestoreRequest({
      method: 'PATCH',
      path: '/users/student_alice?updateMask.fieldPaths=fullCourseEntitlements',
      token: studentToken,
      data: toFields({
        fullCourseEntitlements: ['course_math_physics_paid'],
      }),
    });
    assert(
      resFullForge.status === 403,
      'Student CANNOT forge fullCourseEntitlements (403 Forbidden)',
      `Actual status: ${resFullForge.status}`
    );

    // E: Student attempts to directly grant themselves levelEntitlements
    const resLvlForge = await firestoreRequest({
      method: 'PATCH',
      path: '/users/student_alice?updateMask.fieldPaths=levelEntitlements',
      token: studentToken,
      data: toFields({
        levelEntitlements: ['course_math_physics_paid:lvl_2'],
      }),
    });
    assert(
      resLvlForge.status === 403,
      'Student CANNOT forge levelEntitlements (403 Forbidden)',
      `Actual status: ${resLvlForge.status}`
    );

    // F: Student attempts to directly grant themselves unlockedLevelIds
    const resUnlockForge = await firestoreRequest({
      method: 'PATCH',
      path: '/users/student_alice?updateMask.fieldPaths=unlockedLevelIds',
      token: studentToken,
      data: toFields({
        unlockedLevelIds: ['course_math_physics_paid:lvl_2'],
      }),
    });
    assert(
      resUnlockForge.status === 403,
      'Student CANNOT forge unlockedLevelIds (403 Forbidden)',
      `Actual status: ${resUnlockForge.status}`
    );
  }

  // ==================================================================================
  // 2. REPLAY PROTECTION & CACHE INTEGRITY
  // ==================================================================================
  console.log('\n--- 2. Replay Protection & Sliding Window Cache Integrity ---');
  {
    // A: Attempt to wipe processedSessionEnds array to []
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
      'Student CANNOT wipe processedSessionEnds array to [] (403 Forbidden)',
      `Actual status: ${resWipe.status}`
    );

    // B: Seed exactly 50 session entries in a test user
    const fiftySessions = Array.from({ length: 50 }, (_, i) => `sess_item_${i + 1}`);
    await firestoreRequest({
      method: 'PATCH',
      path: '/users/student_fifty',
      token: superAdminToken,
      data: toFields({
        displayName: 'Fifty Sessions Student',
        email: 'fifty@alameen.com',
        role: 'student',
        processedSessionEnds: fiftySessions,
        totalWatchSeconds: 1000,
      }),
    });
    const fiftyToken = makeToken('student_fifty');

    // Attempt to replace all 50 sessions with 50 arbitrary/fabricated values
    const arbitraryFifty = Array.from({ length: 50 }, (_, i) => `arbitrary_fake_${i + 1}`);
    const resReplaceFifty = await firestoreRequest({
      method: 'PATCH',
      path: '/users/student_fifty?updateMask.fieldPaths=processedSessionEnds',
      token: fiftyToken,
      data: toFields({
        processedSessionEnds: arbitraryFifty,
      }),
    });
    assert(
      resReplaceFifty.status === 403,
      'Student CANNOT replace 50 existing sessions with 50 arbitrary values (403 Forbidden)',
      `Actual status: ${resReplaceFifty.status}`
    );

    // Legitimate sliding window update: drops index 0 and appends 1 new item (diff size == 1)
    const slidingFifty = [...fiftySessions.slice(1), 'sess_item_51_new'];
    const resValidSlide = await firestoreRequest({
      method: 'PATCH',
      path: '/users/student_fifty?updateMask.fieldPaths=processedSessionEnds',
      token: fiftyToken,
      data: toFields({
        processedSessionEnds: slidingFifty,
      }),
    });
    assert(
      resValidSlide.status === 200,
      'Legitimate sliding window update (drops 1, appends 1) is ALLOWED (200 OK)',
      `Actual status: ${resValidSlide.status}`
    );

    // C: Watch log immutability of sessionEndCommitted flag
    await firestoreRequest({
      method: 'PATCH',
      path: '/watch_logs/watch_alice_session_test',
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

    // Attempt to flip sessionEndCommitted back to false
    const resFlipFlag = await firestoreRequest({
      method: 'PATCH',
      path: '/watch_logs/watch_alice_session_test',
      token: studentToken,
      data: toFields({
        sessionEndCommitted: false,
      }),
    });
    assert(
      resFlipFlag.status === 403,
      'Student CANNOT flip sessionEndCommitted from true back to false in watch_logs (403 Forbidden)',
      `Actual status: ${resFlipFlag.status}`
    );
  }

  // ==================================================================================
  // 3. PURCHASED LEVEL VS UNLOCKED LEVEL (SEQUENTIAL PROGRESSION)
  // ==================================================================================
  console.log('\n--- 3. Purchased Level vs Unlocked Level (Sequential Progression) ---');
  {
    // A: Charlie has Full Course Entitlement. Does he get Level 1?
    const resCharlieLvl1 = await firestoreRequest({
      method: 'GET',
      path: '/courses/course_math_physics_paid/protected_lessons/lesson_lvl1_intro',
      token: studentCharlieToken,
    });
    assert(
      resCharlieLvl1.status === 200,
      'Full-Course subscriber CAN access Level 1 (order 1) initial level (200 OK)',
      `Actual status: ${resCharlieLvl1.status}`
    );

    // B: Charlie attempts to access Level 2 BEFORE it is unlocked
    const resCharlieLvl2Locked = await firestoreRequest({
      method: 'GET',
      path: '/courses/course_math_physics_paid/protected_lessons/lesson_lvl2_advanced',
      token: studentCharlieToken,
    });
    assert(
      resCharlieLvl2Locked.status === 403,
      'Full-Course subscriber CANNOT access Level 2 (order 2) merely because course was purchased (403 Forbidden)',
      `Actual status: ${resCharlieLvl2Locked.status}`
    );

    // C: Admin authorizes unlocking Level 2 for Charlie (adds courseId:lvl_2 to unlockedLevelIds)
    await firestoreRequest({
      method: 'PATCH',
      path: '/users/student_charlie?updateMask.fieldPaths=unlockedLevelIds',
      token: superAdminToken,
      data: toFields({
        unlockedLevelIds: ['course_math_physics_paid:lvl_2'],
      }),
    });

    // Now Charlie accesses Level 2
    const resCharlieLvl2Unlocked = await firestoreRequest({
      method: 'GET',
      path: '/courses/course_math_physics_paid/protected_lessons/lesson_lvl2_advanced',
      token: studentCharlieToken,
    });
    assert(
      resCharlieLvl2Unlocked.status === 200,
      'Full-Course subscriber CAN access Level 2 once authorized in unlockedLevelIds (200 OK)',
      `Actual status: ${resCharlieLvl2Unlocked.status}`
    );

    // D: Level 1-only subscriber (Alice) still cannot access Level 2
    const resAliceLvl2 = await firestoreRequest({
      method: 'GET',
      path: '/courses/course_math_physics_paid/protected_lessons/lesson_lvl2_advanced',
      token: studentToken,
    });
    assert(
      resAliceLvl2.status === 403,
      'Level 1 subscriber CANNOT access Level 2 (403 Forbidden)',
      `Actual status: ${resAliceLvl2.status}`
    );

    // E: Non-sequential course: full-course subscriber gets immediate access to all levels
    await firestoreRequest({
      method: 'PATCH',
      path: '/courses/course_open_progression',
      token: superAdminToken,
      data: toFields({
        title: 'دورة البرمجة المفتوحة (غير تتابعي)',
        accessMode: 'closed',
      }),
    });
    await firestoreRequest({
      method: 'PATCH',
      path: '/courses/course_open_progression/protected_lessons/lesson_advanced_nonseq',
      token: superAdminToken,
      data: toFields({
        levelId: 'lvl_advanced',
        levelOrder: 2,
        isSequential: false, // Explicitly non-sequential!
        title: 'محاضرة متقدمة في دورة غير تتابعية',
        muxPlaybackId: 'mux_nonseq_playback_token',
      }),
    });
    await firestoreRequest({
      method: 'PATCH',
      path: '/users/student_charlie?updateMask.fieldPaths=fullCourseEntitlements',
      token: superAdminToken,
      data: toFields({
        fullCourseEntitlements: ['course_math_physics_paid', 'course_open_progression'],
      }),
    });
    const resNonSeq = await firestoreRequest({
      method: 'GET',
      path: '/courses/course_open_progression/protected_lessons/lesson_advanced_nonseq',
      token: studentCharlieToken,
    });
    assert(
      resNonSeq.status === 200,
      'Full-Course subscriber CAN access higher levels in non-sequential course (200 OK)',
      `Actual status: ${resNonSeq.status}`
    );

    // F: Free preview accessible to unenrolled Bob
    const resFreePreview = await firestoreRequest({
      method: 'GET',
      path: '/courses/course_math_physics_paid/protected_lessons/lesson_free_preview',
      token: studentBobToken,
    });
    assert(
      resFreePreview.status === 200,
      'Any student CAN read Free Preview lesson (200 OK)',
      `Actual status: ${resFreePreview.status}`
    );

    // G: Legacy lesson without levelId fails closed for Level 1 buyer, open for full course
    const resLegacyLvl = await firestoreRequest({
      method: 'GET',
      path: '/courses/course_math_physics_paid/protected_lessons/lesson_legacy_no_level',
      token: studentToken,
    });
    assert(
      resLegacyLvl.status === 403,
      'Legacy lesson without levelId FAILS CLOSED for individual level subscriber (403 Forbidden)',
      `Actual status: ${resLegacyLvl.status}`
    );
  }

  // ==================================================================================
  // 4. ACTIVE WATCH SESSION INTEGRITY & IDENTITY MISMATCH PREVENTION
  // ==================================================================================
  console.log('\n--- 4. Active Watch Session Integrity & Impersonation Prevention ---');
  {
    // A: Alice attempts to create session claiming studentId == student_bob (Impersonation)
    const resImpersonate = await firestoreRequest({
      method: 'PATCH',
      path: '/active_watch_sessions/sess_impersonate_001',
      token: studentToken,
      data: toFields({
        studentId: 'student_bob',
        studentName: 'Bob Target Spoofed',
        isPlaying: true,
      }),
    });
    assert(
      resImpersonate.status === 403,
      'Student CANNOT create session with mismatched studentId to impersonate peer (403 Forbidden)',
      `Actual status: ${resImpersonate.status}`
    );

    // B: Alice attempts to create session with studentUid: 'student_alice' but studentId: 'student_bob'
    const resMismatchedIds = await firestoreRequest({
      method: 'PATCH',
      path: '/active_watch_sessions/sess_mismatch_002',
      token: studentToken,
      data: toFields({
        studentUid: 'student_alice',
        studentId: 'student_bob',
        studentName: 'Bob Target Spoofed 2',
        isPlaying: true,
      }),
    });
    assert(
      resMismatchedIds.status === 403,
      'Student CANNOT submit conflicting studentUid and studentId fields (403 Forbidden)',
      `Actual status: ${resMismatchedIds.status}`
    );

    // C: Alice creates valid session with own studentId
    const resValidSession = await firestoreRequest({
      method: 'PATCH',
      path: '/active_watch_sessions/sess_alice_valid',
      token: studentToken,
      data: toFields({
        studentId: 'student_alice',
        studentUid: 'student_alice',
        studentName: 'Alice Student',
        isPlaying: true,
      }),
    });
    assert(
      resValidSession.status === 200,
      'Student CAN create own active watch session with matching studentId (200 OK)',
      `Actual status: ${resValidSession.status}`
    );

    // D: Alice attempts broad listing of /active_watch_sessions
    const resListSessions = await firestoreRequest({
      method: 'GET',
      path: '/active_watch_sessions',
      token: studentToken,
    });
    assert(
      resListSessions.status === 403,
      'Student CANNOT perform unconstrained list of /active_watch_sessions (403 Forbidden)',
      `Actual status: ${resListSessions.status}`
    );

    // E: Admin with view_analytics performs broad listing for live radar
    const resAdminList = await firestoreRequest({
      method: 'GET',
      path: '/active_watch_sessions',
      token: viewOnlyAdminToken,
    });
    assert(
      resAdminList.status === 200,
      'Admin with view_analytics CAN list all active watch sessions for live radar (200 OK)',
      `Actual status: ${resAdminList.status}`
    );
  }

  console.log('\n======================================================================');
  console.log(`FINAL SECURITY VERIFICATION SUMMARY: ${passed} PASSED, ${failed} FAILED`);
  console.log('======================================================================');

  if (failed > 0) {
    process.exit(1);
  }
  return passed;
}

runSecurityAudit()
  .then((count) => {
    console.log(`\nAll ${count} P6 final security checks PASSED cleanly!`);
    process.exit(0);
  })
  .catch((err) => {
    console.error('Audit execution error:', err);
    process.exit(1);
  });
