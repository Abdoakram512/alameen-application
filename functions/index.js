/**
 * Alameen Center Secure Backend (Firebase Cloud Functions v2)
 *
 * Responsibilities:
 * 1. Isolates Mux API credentials (MUX_TOKEN_ID, MUX_TOKEN_SECRET) strictly on the server.
 * 2. Issues RS256 Signed Playback JWTs (MUX_SIGNING_KEY_ID, MUX_SIGNING_PRIVATE_KEY) for enrolled students.
 * 3. Dispatches real-time FCM push notifications on new payment receipts and approval/rejection updates.
 *
 * Configure secrets before deploying on Firebase Blaze plan:
 *   firebase functions:secrets:set MUX_TOKEN_ID
 *   firebase functions:secrets:set MUX_TOKEN_SECRET
 *   firebase functions:secrets:set MUX_SIGNING_KEY_ID        (optional — enables signed playback policy)
 *   firebase functions:secrets:set MUX_SIGNING_PRIVATE_KEY   (optional — base64 or PEM RSA private key)
 */

const crypto = require('node:crypto');
const admin = require('firebase-admin');
const { onRequest } = require('firebase-functions/v2/https');
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require('firebase-functions/v2/firestore');
const { defineSecret } = require('firebase-functions/params');

admin.initializeApp();
const db = admin.firestore();

const muxTokenId = defineSecret('MUX_TOKEN_ID');
const muxTokenSecret = defineSecret('MUX_TOKEN_SECRET');

const ALLOWED_ADMIN_EMAIL = 'elameencenter66@gmail.com';
const ALLOWED_ADMIN_UID = 'zkmjl8rJXOQCahdS1CXKt1rjWT83';

function base64UrlEncode(input) {
  const buffer = Buffer.isBuffer(input) ? input : Buffer.from(input, 'utf8');
  return buffer
    .toString('base64')
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
}

/**
 * Signs a short-lived RS256 JWT for Mux Signed Playback (`aud: 'v'` or `aud: 't'`).
 */
function signMuxPlaybackToken({
  playbackId,
  keyId,
  privateKeyRaw,
  audience = 'v',
  ttlSeconds = 7200,
}) {
  const pemKey = privateKeyRaw.includes('BEGIN')
    ? privateKeyRaw
    : Buffer.from(privateKeyRaw, 'base64').toString('utf8');

  const header = {
    alg: 'RS256',
    typ: 'JWT',
    kid: keyId,
  };

  const payload = {
    sub: playbackId,
    aud: audience,
    exp: Math.floor(Date.now() / 1000) + ttlSeconds,
  };

  const signingInput = `${base64UrlEncode(JSON.stringify(header))}.${base64UrlEncode(
    JSON.stringify(payload)
  )}`;

  const signer = crypto.createSign('RSA-SHA256');
  signer.update(signingInput);
  signer.end();
  const signature = signer.sign(pemKey);

  return `${signingInput}.${base64UrlEncode(signature)}`;
}

async function verifyBearerToken(req) {
  const authHeader = req.headers.authorization || '';
  if (!authHeader.startsWith('Bearer ')) {
    const err = new Error('Missing Bearer token');
    err.statusCode = 401;
    throw err;
  }
  const idToken = authHeader.slice('Bearer '.length).trim();
  return admin.auth().verifyIdToken(idToken);
}

async function assertAdminCaller(decoded) {
  if (
    decoded.admin === true ||
    decoded.uid === ALLOWED_ADMIN_UID ||
    (decoded.email &&
      decoded.email_verified === true &&
      decoded.email.toLowerCase() === ALLOWED_ADMIN_EMAIL)
  ) {
    return;
  }
  const adminDoc = await db.collection('admins').doc(decoded.uid).get();
  if (adminDoc.exists && adminDoc.data()?.active !== false) {
    return;
  }
  const err = new Error('Forbidden: Admin privileges required');
  err.statusCode = 403;
  throw err;
}

function getMuxBasicAuthHeader() {
  const id = (muxTokenId.value() || '').trim();
  const secret = (muxTokenSecret.value() || '').trim();
  if (!id || !secret) {
    const err = new Error('Mux server credentials are not configured');
    err.statusCode = 503;
    throw err;
  }
  return `Basic ${Buffer.from(`${id}:${secret}`, 'utf8').toString('base64')}`;
}

/**
 * 1. Create a Mux Direct Upload URL on the server (Admin only).
 */
exports.createMuxDirectUpload = onRequest(
  { cors: true, secrets: [muxTokenId, muxTokenSecret] },
  async (req, res) => {
    if (req.method !== 'POST') {
      return res.status(405).json({ error: 'Method Not Allowed' });
    }
    try {
      const decoded = await verifyBearerToken(req);
      await assertAdminCaller(decoded);

      const useSignedPolicy = Boolean(
        process.env.MUX_SIGNING_KEY_ID && process.env.MUX_SIGNING_PRIVATE_KEY
      );

      const muxResp = await fetch('https://api.mux.com/video/v1/uploads', {
        method: 'POST',
        headers: {
          Authorization: getMuxBasicAuthHeader(),
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          cors_origin: '*',
          new_asset_settings: {
            playback_policy: [useSignedPolicy ? 'signed' : 'public'],
          },
        }),
      });

      if (!muxResp.ok) {
        const text = await muxResp.text();
        return res
          .status(502)
          .json({ error: 'Mux upload creation failed', details: text });
      }

      const payload = await muxResp.json();
      return res.status(201).json({
        uploadId: payload.data.id,
        uploadUrl: payload.data.url,
        playbackPolicy: useSignedPolicy ? 'signed' : 'public',
      });
    } catch (err) {
      return res
        .status(err.statusCode || 500)
        .json({ error: err.message || 'Internal Server Error' });
    }
  }
);

/**
 * 2. Poll Mux Upload & Asset status on the server (Admin only).
 */
exports.getMuxUploadStatus = onRequest(
  { cors: true, secrets: [muxTokenId, muxTokenSecret] },
  async (req, res) => {
    if (req.method !== 'GET' && req.method !== 'POST') {
      return res.status(405).json({ error: 'Method Not Allowed' });
    }
    try {
      const decoded = await verifyBearerToken(req);
      await assertAdminCaller(decoded);

      const uploadId = (req.query.uploadId || req.body?.uploadId || '').trim();
      if (!uploadId) {
        return res.status(400).json({ error: 'uploadId is required' });
      }

      const authHeader = getMuxBasicAuthHeader();
      const uploadResp = await fetch(
        `https://api.mux.com/video/v1/uploads/${encodeURIComponent(uploadId)}`,
        { headers: { Authorization: authHeader } }
      );

      if (!uploadResp.ok) {
        return res.status(502).json({ error: 'Failed to inspect Mux upload' });
      }

      const uploadJson = await uploadResp.json();
      const assetId = uploadJson.data?.asset_id;
      if (!assetId) {
        return res.status(200).json({ ready: false, status: uploadJson.data?.status });
      }

      const assetResp = await fetch(
        `https://api.mux.com/video/v1/assets/${encodeURIComponent(assetId)}`,
        { headers: { Authorization: authHeader } }
      );

      if (!assetResp.ok) {
        return res.status(200).json({ ready: false, assetId });
      }

      const assetJson = await assetResp.json();
      const firstPlayback = (assetJson.data?.playback_ids || [])[0];
      if (!firstPlayback?.id) {
        return res.status(200).json({ ready: false, assetId });
      }

      return res.status(200).json({
        ready: true,
        uploadId,
        assetId,
        playbackId: firstPlayback.id,
        playbackPolicy: firstPlayback.policy || 'public',
      });
    } catch (err) {
      return res
        .status(err.statusCode || 500)
        .json({ error: err.message || 'Internal Server Error' });
    }
  }
);

/**
 * 3. Resolve & Sign Lesson Stream URL for Enrolled Students (or Free Previews).
 */
exports.getSignedPlaybackUrl = onRequest({ cors: true }, async (req, res) => {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method Not Allowed' });
  }
  try {
    const { courseId, lessonId } = req.body || {};
    if (!courseId || !lessonId) {
      return res
        .status(400)
        .json({ error: 'courseId and lessonId are required' });
    }

    const courseSnap = await db.collection('courses').doc(courseId).get();
    if (!courseSnap.exists) {
      return res.status(404).json({ error: 'Course not found' });
    }

    const courseData = courseSnap.data() || {};
    let targetLesson = null;
    for (const level of courseData.levels || []) {
      for (const lesson of level.lessons || []) {
        if (lesson.id === lessonId) {
          targetLesson = lesson;
          break;
        }
      }
      if (targetLesson) break;
    }

    if (!targetLesson) {
      return res.status(404).json({ error: 'Lesson not found' });
    }

    let isAuthorized = Boolean(targetLesson.isFreePreview);
    if (!isAuthorized) {
      const decoded = await verifyBearerToken(req);
      try {
        await assertAdminCaller(decoded);
        isAuthorized = true;
      } catch (_) {
        const userSnap = await db.collection('users').doc(decoded.uid).get();
        const enrolled = userSnap.data()?.enrolledCourseIds || [];
        isAuthorized = Array.isArray(enrolled) && enrolled.includes(courseId);
      }
    }

    if (!isAuthorized) {
      return res
        .status(403)
        .json({ error: 'Student is not enrolled in this course' });
    }

    let playbackId = (targetLesson.muxPlaybackId || '').trim();
    if (!playbackId) {
      const protectedSnap = await db
        .collection('courses')
        .doc(courseId)
        .collection('protected_lessons')
        .doc(lessonId)
        .get();
      playbackId = (protectedSnap.data()?.muxPlaybackId || '').trim();
    }

    if (!playbackId) {
      return res.status(404).json({ error: 'Playback stream unavailable' });
    }

    const signingKeyId = process.env.MUX_SIGNING_KEY_ID;
    const signingPrivateKey = process.env.MUX_SIGNING_PRIVATE_KEY;

    if (signingKeyId && signingPrivateKey) {
      const videoToken = signMuxPlaybackToken({
        playbackId,
        keyId: signingKeyId,
        privateKeyRaw: signingPrivateKey,
        audience: 'v',
      });
      const thumbToken = signMuxPlaybackToken({
        playbackId,
        keyId: signingKeyId,
        privateKeyRaw: signingPrivateKey,
        audience: 't',
      });

      return res.status(200).json({
        playbackId,
        streamUrl: `https://stream.mux.com/${playbackId}.m3u8?token=${videoToken}`,
        thumbnailUrl: `https://image.mux.com/${playbackId}/thumbnail.jpg?token=${thumbToken}`,
      });
    }

    return res.status(200).json({
      playbackId,
      streamUrl: `https://stream.mux.com/${playbackId}.m3u8`,
      thumbnailUrl: `https://image.mux.com/${playbackId}/thumbnail.jpg?width=600&height=340&fit_mode=smart`,
    });
  } catch (err) {
    return res
      .status(err.statusCode || 500)
      .json({ error: err.message || 'Internal Server Error' });
  }
});

/**
 * 3b. Import a video into Mux from a public HTTPS URL (Drive/Dropbox/etc.) (Admin only).
 * Body: { url: "https://..." }  ->  { assetId }
 */
exports.createMuxAssetFromUrl = onRequest(
  { cors: true, secrets: [muxTokenId, muxTokenSecret] },
  async (req, res) => {
    if (req.method !== 'POST') {
      return res.status(405).json({ error: 'Method Not Allowed' });
    }
    try {
      const decoded = await verifyBearerToken(req);
      await assertAdminCaller(decoded);

      const url = String((req.body && req.body.url) || '').trim();
      if (!/^https:\/\//i.test(url)) {
        return res.status(400).json({ error: 'A valid https URL is required' });
      }

      const useSignedPolicy = Boolean(
        process.env.MUX_SIGNING_KEY_ID && process.env.MUX_SIGNING_PRIVATE_KEY
      );

      const muxResp = await fetch('https://api.mux.com/video/v1/assets', {
        method: 'POST',
        headers: {
          Authorization: getMuxBasicAuthHeader(),
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          input: [{ url }],
          playback_policy: [useSignedPolicy ? 'signed' : 'public'],
        }),
      });

      if (!muxResp.ok) {
        const text = await muxResp.text();
        return res
          .status(502)
          .json({ error: 'Mux asset creation failed', details: text });
      }

      const body = await muxResp.json();
      return res.status(201).json({ assetId: body.data.id });
    } catch (err) {
      return res
        .status(err.statusCode || 500)
        .json({ error: err.message || 'Internal Server Error' });
    }
  }
);

/**
 * 3c. Poll a Mux asset created from a URL until its playback id is ready (Admin only).
 * GET ?assetId=...  ->  { ready, errored, playbackId, assetId, duration }
 */
exports.getMuxAssetStatus = onRequest(
  { cors: true, secrets: [muxTokenId, muxTokenSecret] },
  async (req, res) => {
    try {
      const decoded = await verifyBearerToken(req);
      await assertAdminCaller(decoded);

      const assetId = String(req.query.assetId || '').trim();
      if (!assetId) {
        return res.status(400).json({ error: 'assetId is required' });
      }

      const muxResp = await fetch(
        `https://api.mux.com/video/v1/assets/${encodeURIComponent(assetId)}`,
        { headers: { Authorization: getMuxBasicAuthHeader() } }
      );
      if (!muxResp.ok) {
        const text = await muxResp.text();
        return res
          .status(502)
          .json({ error: 'Mux asset lookup failed', details: text });
      }

      const { data } = await muxResp.json();
      const playbackId = (data.playback_ids && data.playback_ids[0]?.id) || null;
      return res.status(200).json({
        assetId,
        ready: data.status === 'ready' && Boolean(playbackId),
        errored: data.status === 'errored',
        playbackId,
        duration: data.duration || 0,
      });
    } catch (err) {
      return res
        .status(err.statusCode || 500)
        .json({ error: err.message || 'Internal Server Error' });
    }
  }
);

/**
 * 4. Notify Admins on new payment receipt submission.
 */
exports.notifyOnAccessRequestCreated = onDocumentCreated(
  'access_requests/{requestId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    await admin.messaging().send({
      topic: 'admin_alerts',
      notification: {
        title: 'طلب انضمام جديد للمراجعة',
        body: `أرسل ${data.studentName || 'متدرب'} إيصال سداد لكورس "${
          data.courseTitle || ''
        }".`,
      },
      data: {
        type: 'access_request_created',
        requestId: event.params.requestId,
        courseId: String(data.courseId || ''),
      },
    });
  }
);

/**
 * 5. Notify Student when their access request is approved or rejected.
 */
exports.notifyOnAccessRequestReviewed = onDocumentUpdated(
  'access_requests/{requestId}',
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after || before.status === after.status) return;
    if (after.status !== 'approved' && after.status !== 'rejected') return;

    const studentId = after.studentId;
    if (!studentId) return;

    const userSnap = await db.collection('users').doc(studentId).get();
    const fcmToken = userSnap.data()?.fcmToken;
    if (!fcmToken) return;

    const approved = after.status === 'approved';
    await admin.messaging().send({
      token: fcmToken,
      notification: {
        title: approved
            ? 'تم تفعيل اشتراكك في الكورس'
            : 'تحديث بخصوص طلب الانضمام',
        body: approved
            ? `يمكنك الآن بدء مشاهدة محاضرات "${after.courseTitle || ''}".`
            : `تعذر قبول إيصال "${after.courseTitle || ''}". ${
                after.adminNotes ? `الملاحظة: ${after.adminNotes}` : ''
              }`,
      },
      data: {
        type: 'access_request_reviewed',
        status: String(after.status),
        courseId: String(after.courseId || ''),
      },
    });
  }
);

