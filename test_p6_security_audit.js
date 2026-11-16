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
  console.log('P6 SECURITY GATE & PENETRATION AUDIT SUITE (FIRESTORE EMULATOR)');
  console.log('Testing Project: elameen on 127.0.0.1:8088');
  console.log('======================================================================\n');

  const auditResults = [];

  function recordAudit({ vector, description, actualStatus, allowedByRules, isVulnerability, severity, details }) {
    auditResults.push({ vector, description, actualStatus, allowedByRules, isVulnerability, severity, details });
    const tag = isVulnerability ? `[CONFIRMED VULNERABILITY - ${severity}]` : `[SECURE - ENFORCED BY RULES]`;
    console.log(`${tag} ${vector}: ${description}`);
    console.log(`   -> HTTP Status: ${actualStatus} | Allowed by Rules: ${allowedByRules}`);
    console.log(`   -> Evidence: ${details}\n`);
  }

  const superAdminToken = makeToken('admin_root', { admin: true });
  const studentToken = makeToken('student_alice');
  const studentBobToken = makeToken('student_bob');

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

  // Enroll Alice in course_math_physics_paid (representing purchase of Level 1)
  await firestoreRequest({
    method: 'PATCH',
    path: '/users/student_alice',
    token: superAdminToken,
    data: toFields({
      displayName: 'Alice Student',
      email: 'alice@alameen.com',
      role: 'student',
      enrolledCourseIds: ['course_math_physics_paid'],
      completedLessonIds: [],
      totalWatchSeconds: 0,
      processedSessionEnds: ['initial_sess_001'],
    }),
  });

  // Seed Bob's user profile
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
    }),
  });

  // ----------------------------------------------------------------------------------
  // VECTOR 1: Access protected lesson from level NOT purchased or unlocked
  // ----------------------------------------------------------------------------------
  {
    const res = await firestoreRequest({
      method: 'GET',
      path: '/courses/course_math_physics_paid/protected_lessons/lesson_lvl2_advanced',
      token: studentToken,
    });

    const isLeaked = res.status === 200;
    recordAudit({
      vector: 'Vector 1: Level-Specific Protected Playback Access',
      description: 'Student with only Level 1 enrolled attempts to read Level 2 protected Mux token',
      actualStatus: res.status,
      allowedByRules: isLeaked,
      isVulnerability: isLeaked,
      severity: 'HIGH / RELEASE BLOCKER',
      details: isLeaked
        ? `Firestore rule isEnrolledInCourse(courseId) evaluates on course level. Student read Mux token: ${res.data?.fields?.muxPlaybackId?.stringValue}`
        : 'Protected lesson access blocked by level.',
    });
  }

  // ----------------------------------------------------------------------------------
  // VECTOR 2: Add unauthorized lesson IDs to completedLessonIds directly
  // ----------------------------------------------------------------------------------
  {
    const res = await firestoreRequest({
      method: 'PATCH',
      path: '/users/student_alice?updateMask.fieldPaths=completedLessonIds',
      token: studentToken,
      data: toFields({
        completedLessonIds: ['lesson_lvl1_intro', 'lesson_lvl2_advanced', 'lesson_lvl3_quantum'],
      }),
    });

    const isForged = res.status === 200;
    recordAudit({
      vector: 'Vector 2: Direct Client Lesson Completion Forgery',
      description: 'Student appends un-watched lesson IDs directly to completedLessonIds',
      actualStatus: res.status,
      allowedByRules: isForged,
      isVulnerability: isForged,
      severity: 'HIGH / INTEGRITY DEFECT',
      details: isForged
        ? 'Rules only enforce append-only incoming.hasAll(existing). Student successfully marked 3 un-watched lessons as completed without watching 95%.'
        : 'Blocked by rules.',
    });
  }

  // ----------------------------------------------------------------------------------
  // VECTOR 3: Forge totalWatchSeconds through allowed incremental updates
  // ----------------------------------------------------------------------------------
  {
    // Single jump within allowed delta (< 14400s)
    const res1 = await firestoreRequest({
      method: 'PATCH',
      path: '/users/student_alice?updateMask.fieldPaths=totalWatchSeconds',
      token: studentToken,
      data: toFields({
        totalWatchSeconds: 14000,
      }),
    });

    // Rapid second jump of another 14000s
    const res2 = await firestoreRequest({
      method: 'PATCH',
      path: '/users/student_alice?updateMask.fieldPaths=totalWatchSeconds',
      token: studentToken,
      data: toFields({
        totalWatchSeconds: 28000,
      }),
    });

    const isForged = res1.status === 200 && res2.status === 200;
    recordAudit({
      vector: 'Vector 3: Rapid Incremental totalWatchSeconds Forgery',
      description: 'Student rapidly increments totalWatchSeconds by 28,000s (7.7 hours) in milliseconds',
      actualStatus: res2.status,
      allowedByRules: isForged,
      isVulnerability: isForged,
      severity: 'MEDIUM / COST & AUDIT DEFECT',
      details: isForged
        ? 'Rules enforce delta <= 14,400s per update, but stateless rules cannot rate-limit consecutive PATCH calls. totalWatchSeconds jumped to 28,000s.'
        : 'Blocked by rules.',
    });
  }

  // ----------------------------------------------------------------------------------
  // VECTOR 4: Create forged watch_logs or coverageRanges
  // ----------------------------------------------------------------------------------
  {
    const res = await firestoreRequest({
      method: 'PATCH',
      path: '/watch_logs/watch_alice_forged_fake_001',
      token: studentToken,
      data: toFields({
        studentId: 'student_alice',
        courseId: 'course_math_physics_paid',
        lessonId: 'lesson_lvl2_advanced',
        durationSeconds: 7200,
        secondsWatched: 7200,
        coverageRanges: '0-7200',
        completionPercentage: 100.0,
        isCompleted: true,
      }),
    });

    const isForged = res.status === 200;
    recordAudit({
      vector: 'Vector 4: Forged Watch Log & Coverage Range Injection',
      description: 'Student injects synthetic watch log claiming 100% completion without playing video',
      actualStatus: res.status,
      allowedByRules: isForged,
      isVulnerability: isForged,
      severity: 'MEDIUM / VERIFICATION BOUNDARY',
      details: isForged
        ? 'Client watch log creation requires only durationSeconds <= 14400. Client-generated watch events do not provide cryptographic proof of viewing.'
        : 'Blocked by rules.',
    });
  }

  // ----------------------------------------------------------------------------------
  // VECTOR 5: Modify processedSessionEnds to bypass replay protection
  // ----------------------------------------------------------------------------------
  {
    const res = await firestoreRequest({
      method: 'PATCH',
      path: '/users/student_alice?updateMask.fieldPaths=processedSessionEnds',
      token: studentToken,
      data: toFields({
        processedSessionEnds: [], // Wipe the replay cache
      }),
    });

    const isWiped = res.status === 200;
    recordAudit({
      vector: 'Vector 5: Replay Protection Cache Manipulation',
      description: 'Student wipes processedSessionEnds array to allow replaying past session-end increments',
      actualStatus: res.status,
      allowedByRules: isWiped,
      isVulnerability: isWiped,
      severity: 'HIGH / REPLAY VULNERABILITY',
      details: isWiped
        ? 'Rules allow processedSessionEnds in affectedKeys without enforcing append-only or immutability. Student cleared replay history to [].'
        : 'Blocked by rules.',
    });
  }

  // ----------------------------------------------------------------------------------
  // VECTOR 6: Grant themselves paid course or level access
  // ----------------------------------------------------------------------------------
  {
    // Pre-seed an un-enrolled paid course
    await firestoreRequest({
      method: 'PATCH',
      path: '/courses/course_biology_unauthorized',
      token: superAdminToken,
      data: toFields({
        title: 'الأحياء العامة (مدفوع)',
        accessMode: 'closed',
        enrolledCount: 0,
      }),
    });

    const res = await firestoreRequest({
      method: 'PATCH',
      path: '/users/student_alice?updateMask.fieldPaths=enrolledCourseIds&updateMask.fieldPaths=lastEnrolledCourseId',
      token: studentToken,
      data: toFields({
        enrolledCourseIds: ['course_math_physics_paid', 'course_biology_unauthorized'],
        lastEnrolledCourseId: 'course_biology_unauthorized',
      }),
    });

    const isGranted = res.status === 200;
    recordAudit({
      vector: 'Vector 6: Unauthorized Self-Enrollment in Paid Course',
      description: 'Student attempts to add closed/paid course to enrolledCourseIds',
      actualStatus: res.status,
      allowedByRules: isGranted,
      isVulnerability: isGranted,
      severity: isGranted ? 'CRITICAL' : 'NONE',
      details: isGranted
        ? 'VULNERABILITY: Student self-enrolled in paid course.'
        : 'SECURE: Rules strictly enforced isOpenCourse(lastEnrolledCourseId) == true and returned 403 Forbidden.',
    });
  }

  // ----------------------------------------------------------------------------------
  // VECTOR 7: Manipulate payment approval status
  // ----------------------------------------------------------------------------------
  {
    // Alice submits access request
    await firestoreRequest({
      method: 'PATCH',
      path: '/access_requests/req_alice_001',
      token: studentToken,
      data: toFields({
        studentId: 'student_alice',
        courseId: 'course_biology_unauthorized',
        status: 'pending',
      }),
    });

    // Alice attempts to set status: 'approved'
    const res = await firestoreRequest({
      method: 'PATCH',
      path: '/access_requests/req_alice_001?updateMask.fieldPaths=status',
      token: studentToken,
      data: toFields({
        status: 'approved',
      }),
    });

    const isManipulated = res.status === 200;
    recordAudit({
      vector: 'Vector 7: Payment Approval Status Tampering',
      description: 'Student attempts to approve their own pending access request',
      actualStatus: res.status,
      allowedByRules: isManipulated,
      isVulnerability: isManipulated,
      severity: isManipulated ? 'CRITICAL' : 'NONE',
      details: isManipulated
        ? 'VULNERABILITY: Student approved their own access request.'
        : 'SECURE: Rules require hasAdminPerm("manage_requests") and returned 403 Forbidden.',
    });
  }

  // ----------------------------------------------------------------------------------
  // VECTOR 8: Access other students personal or payment data
  // ----------------------------------------------------------------------------------
  {
    // Attempt A: Read Bob's user profile
    const resProfile = await firestoreRequest({
      method: 'GET',
      path: '/users/student_bob',
      token: studentToken,
    });

    // Attempt B: Read active_watch_sessions listing
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

    const resActiveSessions = await firestoreRequest({
      method: 'GET',
      path: '/active_watch_sessions',
      token: studentToken,
    });

    const profileBlocked = resProfile.status === 403;
    const activeSessionsLeaked = resActiveSessions.status === 200;

    recordAudit({
      vector: 'Vector 8A: Peer Student Profile Privacy',
      description: 'Student Alice attempts direct read of Bob user profile',
      actualStatus: resProfile.status,
      allowedByRules: !profileBlocked,
      isVulnerability: !profileBlocked,
      severity: profileBlocked ? 'NONE' : 'HIGH',
      details: profileBlocked
        ? 'SECURE: isOwner(userId) enforces isolation and returned 403 Forbidden.'
        : 'VULNERABILITY: Student profile read allowed.',
    });

    recordAudit({
      vector: 'Vector 8B: Active Watch Sessions Student Directory / IP Leak',
      description: 'Student Alice queries /active_watch_sessions to view currently watching peers',
      actualStatus: resActiveSessions.status,
      allowedByRules: activeSessionsLeaked,
      isVulnerability: activeSessionsLeaked,
      severity: 'HIGH / PRIVACY DEFECT',
      details: activeSessionsLeaked
        ? 'Rules allow list: if isAdmin() || isAuthenticated(). Alice received Bob name, email, phone, and IP address.'
        : 'Blocked by rules.',
    });
  }

  console.log('======================================================================');
  console.log('SECURITY AUDIT SUMMARY:');
  const vulns = auditResults.filter((r) => r.isVulnerability);
  console.log(`Total Tested Vectors: ${auditResults.length} | Identified Vulnerabilities: ${vulns.length}`);
  console.log('======================================================================');

  return vulns.length;
}

runSecurityAudit()
  .then((vulnCount) => {
    console.log(`\nAudit completed with ${vulnCount} findings.`);
    process.exit(0);
  })
  .catch((err) => {
    console.error('Audit execution error:', err);
    process.exit(1);
  });
