# Hackatime Desktop evidence protocol (v1)

Every client signal is a claim. The server credits time only when evidence the client cannot cheaply fake backs it, and caps credit by what the shipped output plausibly took.

The server implementation is `app/services/evidence/crypto.rb`. The macOS implementation is `desktop/macos/Sources/HackatimeDesktopCore/Protocol.swift`. Both check the same vectors (`desktop/macos/Tests/HackatimeDesktopCoreTests/test-vectors.json`, generated from Ruby).

No primitive is hand-written. SHA-256, ChaCha20-Poly1305 and ECDSA P-256 come from OpenSSL (server) and CryptoKit (client). This document only defines how they are combined.

## Pairing (PKCE)

1. The app makes a random verifier and opens the companion site's `/pair?challenge=BASE64URL(SHA256(verifier))&name=…` in its own window.
2. The signed-in user ticks consent to the timelapse and approves. The app always records a timelapse, so there is no pairing without that consent.
3. The site gets a one-time code (10 minutes) from `POST /api/v1/authenticated/desktop/pairings`. In the app's window the page hands the code straight to the app; in a browser it shows the code and opens `hackatime-desktop://pair?code=…`.
4. The app calls `POST /api/desktop/v1/pair` with `code`, `code_verifier`, its name and version, and receives a device token. A code works once, and only with its verifier.

Accounts can enrol at most 3 new devices in 30 days.

## Device key (optional)

`POST /api/desktop/v1/key` enrols one ECDSA P-256 public key (DER SubjectPublicKeyInfo).

| Tier | Where | Bonus |
| --- | --- | --- |
| `software` | Keychain key | none |
| `secure_enclave` / `tpm` | hardware-bound key | small |
| `app_attest` | Secure Enclave key attested by Apple (macOS 27+, Developer ID app with the App Attest entitlement, main bundle only) | slightly larger |

App Attest client data is `hkt-attest-v1|<device uid>|<current beacon value>|<base64 public key>`. A failed attestation leaves the device at its plain tier. Hardware is never required and never a penalty. A keyed hash of the platform UUID keeps one account per machine; the raw value is not stored.

## Beacons

`GET /api/desktop/v1/beacon` returns, for the current Unix minute:

- `value`: 32 public random bytes. Mixing it into a block proves the block was not made before that minute.
- `commitment = SHA256("hkt-beacon-secret-v1\n" || secret)`: the secret is revealed only when a range containing that minute is shipped.
- `next_expected_at`: when this minute's timelapse frame is due. The second is `SHA256("hkt-timelapse-v1\n" || value || uid)[0] mod 60`, so the client cannot choose when it is watched. Each frame in a payload carries `at_ms`; frames within `timelapse_window_seconds` (default 30) of the due time count as on time. An unchanged screen repeats the previous frame hash instead of storing a new image.

## Hash chain

One block per minute:

```
hash = SHA256("hkt-chain-v1\n" || prev_hash || beacon_value || SHA256(payload))
signature = ECDSA-P256-SHA256(hash bytes)        # when a key is enrolled
```

`POST /api/desktop/v1/blocks` accepts a block only when:

- `seq` is head + 1 and `prev_hash` is the current head (no forks);
- `captured_at_ms` falls in `minute`, minutes and `mono_ms` strictly increase, and capturedAt is no more than 5 minutes ahead of server time;
- the beacon exists and is not newer than the block. A beacon older than the previous minute, or a block more than 5 minutes behind server time, marks the block `offline` (accepted at lower confidence, never older than 24 hours);
- `hash` and, if present, `signature` verify.

`payload` is canonical JSON holding summary claims only: `focus` (`project`, `research`, `unrelated`, `unknown`, classified on device), `project`, `category`, `active_s`, input counts (`keys`, `clicks`, `moves`, `injected`), `rhythm` and `jiggler` scores, `edits`, `commits`, `builds`, `ai` (an object of integer counts from 0 to 10,000,000: `prompts`, `in_tokens`, `out_tokens`, `ai_lines`, `human_lines`, `accepted`, plus a boolean `waiting`; anything else rejects the block as `malformed`), `tree.root` and `frames[]` (`hash`, `kind`, `trigger`, `phash`). Titles, URLs, keystrokes and source never leave the machine.

Accepted project and research minutes also become ordinary heartbeats, so desktop time shows on the dashboard.

## Working tree snapshots

On a project minute, at most once every 5 minutes, the client takes a salted Merkle tree of the project:

```
leaf = SHA256(0x00 || salt || path || 0x00 || SHA256(content))     # sorted by path bytes
node = SHA256(0x01 || left || right)                               # an odd last node is promoted
```

Never hashed: `.env*`, keys and certificates, credential files, databases, `.git`, `node_modules`, build and cache directories, files over 512 KB, symlinks, files past the first 2,000 and anything matching `.hackatimeignore`. Only `tree.root` is sent. The client keeps the leaf list and an encrypted copy of each file locally.

## Screenshots

Only the focused window, only when it is allowlisted (project editor or terminal, localhost, docs, repos, matched AI chat). The never list (password managers, banking and payments, mail and chat apps, private windows, notifications) always wins. Text that looks like a secret is blacked out on device before encryption. If text cannot be read at all, every text region is blacked out, and if even that fails, the frame is dropped.

Frames are grouped into 5-minute segments. Each segment has its own random 256-bit key, stored only wrapped by a vault key in the Keychain:

```
frame blob = nonce(12) || ChaCha20-Poly1305(segment_key, heic, aad = "hkt-frame-v1") || tag(16)
frame hash = SHA256(frame blob)    # this goes into the block
```

Each segment key seals a few dozen frames, so random 96-bit nonces stay far inside their safety margin. Segments are crypto-shredded after 30 days by deleting their wrapped keys, shipped or not, because the server keeps its own copy of shipped frames. "Delete everything" replaces the vault key in the Keychain, so no copy of the vault can be decrypted, and removes every frame and snapshot file.

## Shipping

1. `POST /api/desktop/v1/ships {project, from_seq, to_seq}` opens a draft and reveals the beacon secrets for the range. Clients check each against its commitment.
2. A timelapse frame is required when `SHA256("hkt-required-v1\n" || secret || frame_hash)[0] < 256 × 0.08` (about five an hour). Required frames can be redacted (the copy is marked redacted and lists its regions for reviewers) but not removed.
3. The server picks code spot-checks: the first and last snapshots plus one more chosen by the secret.
4. `POST /ships/:id/frames` uploads each frame with its segment key. An unredacted frame must hash to its committed value and decrypt.
5. `POST /ships/:id/submit` sends the final shipped files (git-tracked only) and each spot-checked snapshot as its ordered leaf list. Tracked files go with content; every other file goes as its leaf hash only. Each snapshot must hash back to its committed root and overlap the shipped repo by winnowed k-gram fingerprints (as in MOSS). A root mismatch zeroes the ship.

## Scoring

Rules run first: mouse movement alone and jiggler or injected-input minutes earn nothing, runs of identical frames zero out, switches of about 2 minutes still count, and research, testing and AI waiting count only when an edit, prompt or commit follows within 10 minutes. Then a calibrated LightGBM model (`EVIDENCE_MODEL_PATH`, trained by `script/evidence/train_model.py`) or the rules-only weights give each stretch a confidence. The output ceiling from the shipped diff caps the total.

Weights, thresholds and ceilings live in private config (`EVIDENCE_CONFIG_PATH`); the defaults in `app/services/evidence/config.rb` are only starting points.
