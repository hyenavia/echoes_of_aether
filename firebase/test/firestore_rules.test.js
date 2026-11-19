import test, { before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import {
  Bytes,
  Timestamp,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  serverTimestamp,
  setDoc,
  setLogLevel,
} from 'firebase/firestore';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const firebaseDir = path.resolve(__dirname, '..');

const rulesSource = fs.readFileSync(
  path.join(firebaseDir, 'firestore.rules'),
  'utf8',
);
const testVectors = JSON.parse(
  fs.readFileSync(path.join(firebaseDir, 'test_vectors.json'), 'utf8'),
);

let testEnv;

function toFirestoreDoc(rawDoc, savedAtValue) {
  const copy = {};
  for (const [k, v] of Object.entries(rawDoc)) {
    if (k === '_targetSlot') continue;
    if (k === 'blobBase64') {
      copy.blob = Bytes.fromUint8Array(Buffer.from(v, 'base64'));
    } else {
      copy[k] = v;
    }
  }
  copy.savedAt = savedAtValue;
  return copy;
}

before(async () => {
  setLogLevel('error');
  testEnv = await initializeTestEnvironment({
    projectId: 'echoes-of-aether-rules-test',
    firestore: {
      rules: rulesSource,
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

after(async () => {
  if (testEnv) {
    await testEnv.cleanup();
  }
});

for (const vector of testVectors) {
  test(`vector: ${vector.name}`, async () => {
    const uid = 'alice';
    const ctx = testEnv.authenticatedContext(uid);
    const db = ctx.firestore();

    if (vector.prev !== null) {
      const prevSlot =
        vector.prev._targetSlot ?? String(vector.prev.revision % 2);
      const prevSavedAtMs = Date.now() - vector.dtSeconds * 1000 - 25;
      const prevPayload = toFirestoreDoc(
        vector.prev,
        Timestamp.fromMillis(prevSavedAtMs),
      );
      await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
        await setDoc(
          doc(adminCtx.firestore(), 'saves', uid, 'slots', prevSlot),
          prevPayload,
        );
      });
    }

    const nextSlot =
      vector.next._targetSlot ?? String(vector.next.revision % 2);
    const nextPayload = toFirestoreDoc(vector.next, serverTimestamp());
    const targetRef = doc(db, 'saves', uid, 'slots', nextSlot);

    if (vector.expectAccept) {
      await assertSucceeds(setDoc(targetRef, nextPayload));
    } else {
      await assertFails(setDoc(targetRef, nextPayload));
    }
  });
}

test('security: unauthenticated read, list, write, and delete are denied', async () => {
  const sample = testVectors.find((v) => v.name === 'accept_first_upload_revision_1');
  assert.ok(sample);

  await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
    await setDoc(
      doc(adminCtx.firestore(), 'saves', 'alice', 'slots', '1'),
      toFirestoreDoc(sample.next, Timestamp.fromMillis(Date.now() - 1000)),
    );
    await setDoc(
      doc(adminCtx.firestore(), 'saves', 'alice', 'clock', 'ping'),
      { t: Timestamp.fromMillis(Date.now() - 1000) },
    );
  });

  const anonDb = testEnv.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(anonDb, 'saves', 'alice', 'slots', '1')));
  await assertFails(getDocs(collection(anonDb, 'saves', 'alice', 'slots')));
  await assertFails(
    setDoc(
      doc(anonDb, 'saves', 'alice', 'slots', '1'),
      toFirestoreDoc(sample.next, serverTimestamp()),
    ),
  );
  await assertFails(deleteDoc(doc(anonDb, 'saves', 'alice', 'slots', '1')));
  await assertFails(getDoc(doc(anonDb, 'saves', 'alice', 'clock', 'ping')));
  await assertFails(
    setDoc(doc(anonDb, 'saves', 'alice', 'clock', 'ping'), {
      t: serverTimestamp(),
    }),
  );
});

test('security: non-owner cannot get, list, write, or delete another user data', async () => {
  const sample = testVectors.find((v) => v.name === 'accept_first_upload_revision_1');
  assert.ok(sample);

  await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
    await setDoc(
      doc(adminCtx.firestore(), 'saves', 'alice', 'slots', '1'),
      toFirestoreDoc(sample.next, Timestamp.fromMillis(Date.now() - 1000)),
    );
    await setDoc(
      doc(adminCtx.firestore(), 'saves', 'alice', 'clock', 'ping'),
      { t: Timestamp.fromMillis(Date.now() - 1000) },
    );
  });

  const bobDb = testEnv.authenticatedContext('bob').firestore();
  await assertFails(getDoc(doc(bobDb, 'saves', 'alice', 'slots', '1')));
  await assertFails(getDocs(collection(bobDb, 'saves', 'alice', 'slots')));
  await assertFails(
    setDoc(
      doc(bobDb, 'saves', 'alice', 'slots', '0'),
      toFirestoreDoc({ ...sample.next, revision: 2 }, serverTimestamp()),
    ),
  );
  await assertFails(deleteDoc(doc(bobDb, 'saves', 'alice', 'slots', '1')));
  await assertFails(getDoc(doc(bobDb, 'saves', 'alice', 'clock', 'ping')));
  await assertFails(
    setDoc(doc(bobDb, 'saves', 'alice', 'clock', 'ping'), {
      t: serverTimestamp(),
    }),
  );
});

test('security: owner can get and list slots, cannot delete or use invalid slot id', async () => {
  const sample = testVectors.find((v) => v.name === 'accept_first_upload_revision_1');
  assert.ok(sample);

  const aliceDb = testEnv.authenticatedContext('alice').firestore();
  await assertSucceeds(
    setDoc(
      doc(aliceDb, 'saves', 'alice', 'slots', '1'),
      toFirestoreDoc(sample.next, serverTimestamp()),
    ),
  );

  const singleSnap = await assertSucceeds(
    getDoc(doc(aliceDb, 'saves', 'alice', 'slots', '1')),
  );
  assert.equal(singleSnap.exists(), true);

  const listSnap = await assertSucceeds(
    getDocs(collection(aliceDb, 'saves', 'alice', 'slots')),
  );
  assert.equal(listSnap.size, 1);

  await assertFails(deleteDoc(doc(aliceDb, 'saves', 'alice', 'slots', '1')));
  await assertFails(
    setDoc(
      doc(aliceDb, 'saves', 'alice', 'slots', '2'),
      toFirestoreDoc({ ...sample.next, revision: 2 }, serverTimestamp()),
    ),
  );
  // Cannot reset slot 1 back to revision 1 once revision 1 exists.
  await assertFails(
    setDoc(
      doc(aliceDb, 'saves', 'alice', 'slots', '1'),
      toFirestoreDoc(sample.next, serverTimestamp()),
    ),
  );
});

test('security: alternating 2-slot chain rev1 -> rev2 -> rev3 works and rev2 without rev1 fails', async () => {
  const sample = testVectors.find((v) => v.name === 'accept_first_upload_revision_1');
  assert.ok(sample);
  const aliceDb = testEnv.authenticatedContext('alice').firestore();

  // Writing revision 2 to slot 0 without revision 1 in slot 1 fails.
  await assertFails(
    setDoc(
      doc(aliceDb, 'saves', 'alice', 'slots', '0'),
      toFirestoreDoc({ ...sample.next, revision: 2 }, serverTimestamp()),
    ),
  );

  // Chain: rev 1 (slot 1) -> rev 2 (slot 0) -> rev 3 (slot 1 overwrite).
  await assertSucceeds(
    setDoc(
      doc(aliceDb, 'saves', 'alice', 'slots', '1'),
      toFirestoreDoc({ ...sample.next, revision: 1 }, serverTimestamp()),
    ),
  );
  await assertSucceeds(
    setDoc(
      doc(aliceDb, 'saves', 'alice', 'slots', '0'),
      toFirestoreDoc(
        { ...sample.next, revision: 2, lifetimeClears: 4, gold: 800 },
        serverTimestamp(),
      ),
    ),
  );
  await assertSucceeds(
    setDoc(
      doc(aliceDb, 'saves', 'alice', 'slots', '1'),
      toFirestoreDoc(
        { ...sample.next, revision: 3, lifetimeClears: 5, gold: 1100 },
        serverTimestamp(),
      ),
    ),
  );
});

test('security: forged savedAt, missing required field, and mismatched blobBytes fail', async () => {
  const sample = testVectors.find((v) => v.name === 'accept_first_upload_revision_1');
  assert.ok(sample);

  const aliceDb = testEnv.authenticatedContext('alice').firestore();
  await assertFails(
    setDoc(
      doc(aliceDb, 'saves', 'alice', 'slots', '1'),
      toFirestoreDoc(sample.next, Timestamp.fromMillis(Date.now() - 5000)),
    ),
  );

  const missingSha = toFirestoreDoc(sample.next, serverTimestamp());
  delete missingSha.blobSha256;
  await assertFails(
    setDoc(doc(aliceDb, 'saves', 'alice', 'slots', '1'), missingSha),
  );

  const badBlobBytes = toFirestoreDoc(
    { ...sample.next, blobBytes: 999 },
    serverTimestamp(),
  );
  await assertFails(
    setDoc(doc(aliceDb, 'saves', 'alice', 'slots', '1'), badBlobBytes),
  );
});

test('security: clock/ping only accepts serverTimestamp in field t and rejects deletes or extra fields', async () => {
  const aliceDb = testEnv.authenticatedContext('alice').firestore();
  const pingRef = doc(aliceDb, 'saves', 'alice', 'clock', 'ping');

  await assertSucceeds(setDoc(pingRef, { t: serverTimestamp() }));
  const pingSnap = await assertSucceeds(getDoc(pingRef));
  assert.equal(pingSnap.exists(), true);

  await assertFails(
    setDoc(pingRef, { t: Timestamp.fromMillis(Date.now() - 1000) }),
  );
  await assertFails(setDoc(pingRef, { t: serverTimestamp(), extra: 'bad' }));
  await assertFails(setDoc(pingRef, {}));
  await assertFails(deleteDoc(pingRef));
});

test('security: all unlisted collection paths are denied', async () => {
  const aliceDb = testEnv.authenticatedContext('alice').firestore();
  await assertFails(setDoc(doc(aliceDb, 'saves', 'alice'), { any: 1 }));
  await assertFails(
    setDoc(doc(aliceDb, 'saves', 'alice', 'meta', 'info'), { any: 1 }),
  );
  await assertFails(getDoc(doc(aliceDb, 'leaderboard', 'global')));
});
