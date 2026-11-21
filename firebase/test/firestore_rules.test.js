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

async function seedSlotDoc(uid, rawDoc, dtSeconds = 60) {
  const slot = String(rawDoc.revision % 2);
  const savedAtMs = Date.now() - dtSeconds * 1000 - 25;
  await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
    await setDoc(
      doc(adminCtx.firestore(), 'saves', uid, 'slots', slot),
      toFirestoreDoc(rawDoc, Timestamp.fromMillis(savedAtMs)),
    );
  });
}

test('migration: M16 schemaVersion 10 -> 11 clamps level 604->90, rank 13->5, and allows legacy gold bonus 2570000', async () => {
  const sample = testVectors.find((v) => v.name === 'accept_first_upload_revision_1');
  assert.ok(sample);

  const prev = {
    ...sample.next,
    revision: 1,
    schemaVersion: 10,
    level: 604,
    highestAscensionRank: 13,
    gold: 10000,
  };
  await seedSlotDoc('alice', prev, 60);

  const aliceDb = testEnv.authenticatedContext('alice').firestore();
  const next = {
    ...sample.next,
    revision: 2,
    schemaVersion: 11,
    level: 90,
    highestAscensionRank: 5,
    gold: 10000 + (604 - 90) * 5000, // +2570000 Aether Legacy Gift
  };
  await assertSucceeds(
    setDoc(
      doc(aliceDb, 'saves', 'alice', 'slots', '0'),
      toFirestoreDoc(next, serverTimestamp()),
    ),
  );
});

test('migration: M16 schemaVersion 10 -> 11 high-level 100000->90 grants (100000-90)*5000 legacy gold bonus', async () => {
  const sample = testVectors.find((v) => v.name === 'accept_first_upload_revision_1');
  assert.ok(sample);

  const legacyBonus = (100000 - 90) * 5000; // 499550000
  const prev = {
    ...sample.next,
    revision: 1,
    schemaVersion: 10,
    level: 100000,
    highestAscensionRank: 0,
    gold: 10000,
  };
  await seedSlotDoc('alice', prev, 60);

  const aliceDb = testEnv.authenticatedContext('alice').firestore();
  await assertSucceeds(
    setDoc(
      doc(aliceDb, 'saves', 'alice', 'slots', '0'),
      toFirestoreDoc(
        {
          ...sample.next,
          revision: 2,
          schemaVersion: 11,
          level: 90,
          highestAscensionRank: 0,
          gold: 10000 + legacyBonus,
        },
        serverTimestamp(),
      ),
    ),
  );

  // Exceeding base gold ceiling + legacyGoldBonus must still be rejected.
  await seedSlotDoc('bob', prev, 60);
  const bobDb = testEnv.authenticatedContext('bob').firestore();
  await assertFails(
    setDoc(
      doc(bobDb, 'saves', 'bob', 'slots', '0'),
      toFirestoreDoc(
        {
          ...sample.next,
          revision: 2,
          schemaVersion: 11,
          level: 90,
          highestAscensionRank: 0,
          gold: 10000 + legacyBonus + 100000000,
        },
        serverTimestamp(),
      ),
    ),
  );
});

test('migration: M16 schemaVersion 10 -> 11 rejects level below 90, rank below 5, or unclamped drops', async () => {
  const sample = testVectors.find((v) => v.name === 'accept_first_upload_revision_1');
  assert.ok(sample);

  const prevHigh = {
    ...sample.next,
    revision: 1,
    schemaVersion: 10,
    level: 604,
    highestAscensionRank: 13,
    gold: 10000,
  };
  await seedSlotDoc('alice', prevHigh, 60);
  const aliceDb = testEnv.authenticatedContext('alice').firestore();

  // Level dropped below 90 fails.
  await assertFails(
    setDoc(
      doc(aliceDb, 'saves', 'alice', 'slots', '0'),
      toFirestoreDoc(
        {
          ...sample.next,
          revision: 2,
          schemaVersion: 11,
          level: 89,
          highestAscensionRank: 5,
          gold: 10000,
        },
        serverTimestamp(),
      ),
    ),
  );

  // Rank dropped below 5 fails.
  await assertFails(
    setDoc(
      doc(aliceDb, 'saves', 'alice', 'slots', '0'),
      toFirestoreDoc(
        {
          ...sample.next,
          revision: 2,
          schemaVersion: 11,
          level: 90,
          highestAscensionRank: 4,
          gold: 10000,
        },
        serverTimestamp(),
      ),
    ),
  );

  // Level <= 90 cannot drop during 10 -> 11.
  await seedSlotDoc(
    'bob',
    {
      ...sample.next,
      revision: 1,
      schemaVersion: 10,
      level: 85,
      highestAscensionRank: 4,
      gold: 10000,
    },
    60,
  );
  const bobDb = testEnv.authenticatedContext('bob').firestore();
  await assertFails(
    setDoc(
      doc(bobDb, 'saves', 'bob', 'slots', '0'),
      toFirestoreDoc(
        {
          ...sample.next,
          revision: 2,
          schemaVersion: 11,
          level: 80,
          highestAscensionRank: 4,
          gold: 10000,
        },
        serverTimestamp(),
      ),
    ),
  );

  // Rank <= 5 cannot drop during 10 -> 11.
  await assertFails(
    setDoc(
      doc(bobDb, 'saves', 'bob', 'slots', '0'),
      toFirestoreDoc(
        {
          ...sample.next,
          revision: 2,
          schemaVersion: 11,
          level: 85,
          highestAscensionRank: 3,
          gold: 10000,
        },
        serverTimestamp(),
      ),
    ),
  );
});

test('migration: same-schema 11 -> 11 rejects dropping level, rank, or claiming legacy gold bonus', async () => {
  const sample = testVectors.find((v) => v.name === 'accept_first_upload_revision_1');
  assert.ok(sample);

  const prevHigh = {
    ...sample.next,
    revision: 1,
    schemaVersion: 11,
    level: 604,
    highestAscensionRank: 13,
    gold: 10000,
  };
  await seedSlotDoc('alice', prevHigh, 60);
  const aliceDb = testEnv.authenticatedContext('alice').firestore();

  // Same-schema 11 -> 11 cannot drop level (604 -> 90).
  await assertFails(
    setDoc(
      doc(aliceDb, 'saves', 'alice', 'slots', '0'),
      toFirestoreDoc(
        {
          ...sample.next,
          revision: 2,
          schemaVersion: 11,
          level: 90,
          highestAscensionRank: 13,
          gold: 10000,
        },
        serverTimestamp(),
      ),
    ),
  );

  // Same-schema 11 -> 11 cannot drop highestAscensionRank (13 -> 5).
  await assertFails(
    setDoc(
      doc(aliceDb, 'saves', 'alice', 'slots', '0'),
      toFirestoreDoc(
        {
          ...sample.next,
          revision: 2,
          schemaVersion: 11,
          level: 604,
          highestAscensionRank: 5,
          gold: 10000,
        },
        serverTimestamp(),
      ),
    ),
  );

  // Same-schema 11 -> 11 cannot claim legacy gold bonus.
  await seedSlotDoc(
    'bob',
    {
      ...sample.next,
      revision: 1,
      schemaVersion: 11,
      level: 100000,
      highestAscensionRank: 0,
      gold: 10000,
    },
    60,
  );
  const bobDb = testEnv.authenticatedContext('bob').firestore();
  await assertFails(
    setDoc(
      doc(bobDb, 'saves', 'bob', 'slots', '0'),
      toFirestoreDoc(
        {
          ...sample.next,
          revision: 2,
          schemaVersion: 11,
          level: 100000,
          highestAscensionRank: 0,
          gold: 10000 + (100000 - 90) * 5000,
        },
        serverTimestamp(),
      ),
    ),
  );
});

test('security: /app_config/version allows authenticated get only, denies unauthenticated get and all list/set/delete', async () => {
  const aliceDb = testEnv.authenticatedContext('alice').firestore();
  const anonDb = testEnv.unauthenticatedContext().firestore();

  // Create on /app_config/version fails even when authenticated.
  await assertFails(
    setDoc(doc(aliceDb, 'app_config', 'version'), { latestVersion: '9.9.9' }),
  );

  await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
    await setDoc(doc(adminCtx.firestore(), 'app_config', 'version'), {
      minVersion: '1.0.0',
      latestVersion: '1.1.0',
    });
  });

  // Authenticated get succeeds.
  const versionSnap = await assertSucceeds(
    getDoc(doc(aliceDb, 'app_config', 'version')),
  );
  assert.equal(versionSnap.exists(), true);
  assert.equal(versionSnap.data().latestVersion, '1.1.0');

  // Unauthenticated get fails.
  await assertFails(getDoc(doc(anonDb, 'app_config', 'version')));

  // Authenticated list, update (set), and delete fail.
  await assertFails(getDocs(collection(aliceDb, 'app_config')));
  await assertFails(
    setDoc(doc(aliceDb, 'app_config', 'version'), { latestVersion: '9.9.9' }),
  );
  await assertFails(deleteDoc(doc(aliceDb, 'app_config', 'version')));

  // Other documents under /app_config remain denied.
  await assertFails(getDoc(doc(aliceDb, 'app_config', 'other')));
});
