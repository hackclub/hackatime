# Hackatime Desktop evidence protocol (v1)

Every client signal is a claim. The server credits time only when evidence the client cannot cheaply fake backs it, and caps credit by what the shipped output plausibly took.

The server implementation is `app/services/evidence/crypto.rb`. The macOS implementation is `desktop/macos/Sources/HackatimeDesktopCore/Protocol.swift`. Both check the same vectors (`desktop/macos/Tests/HackatimeDesktopCoreTests/test-vectors.json`, generated from Ruby).

No primitive is hand-written. SHA-256, ChaCha20-Poly1305 and ECDSA P-256 come from OpenSSL (server) and CryptoKit (client). This document only defines how they are combined.

## Pairing (PKCE)

1. The app makes a random verifier and opens the companion site's `/pair?challenge=BASE64URL(SHA256(verifier))&name=…` in its own window.
2. The signed-in user ticks consent to the timelapse and approves. The app always records a timelapse, so there is no pairing without that consent.
3. The site gets a one-time code (10 minutes) from `POST /api/v1/authenticated/desktop/pairings`. In the app's window the page hands the code straight to the app; in a browser it shows the code and opens `hackatime-desktop://pair?code=…`.
4. The app calls `POST /api/desktop/v1/pair` with `code`, `code_verifier`, its name and version, and receives a device token. A code works once, and only with its verifier.

Accounts can enrol at most 3 new machines in 30 days. Pairing a Mac that the same account already paired replaces the earlier pairing and does not count again.

## Device key (optional)

`POST /api/desktop/v1/key` enrols one ECDSA P-256 public key (DER SubjectPublicKeyInfo).

| Tier | Where | Bonus |
| --- | --- | --- |
| `software` | Keychain key | none |
| `secure_enclave` / `tpm` | hardware-bound key, as the client claims | none: nothing verifies the claim |
| `app_attest` | Secure Enclave key attested by Apple (macOS 27+, Developer ID app with the App Attest entitlement, main bundle only) | small |

App Attest client data is `hkt-attest-v1|<device uid>|<current beacon value>|<base64 public key>`. A failed attestation leaves the device at its plain tier. Hardware is never required and never a penalty. A keyed hash of the platform UUID keeps one account per machine; the raw value is not stored.

## Beacons

`GET /api/desktop/v1/beacon` returns, for the current Unix minute:

- `value`: 32 public random bytes. Mixing it into a block proves the block was not made before that minute.
- `commitment = SHA256("hkt-beacon-secret-v1\n" || device_secret)`, where `device_secret = HMAC-SHA256(key = beacon secret, "hkt-device-secret-v1\n" || device uid)`. Every device gets its own commitment for the same minute. The beacon secret itself never leaves the server; a device's secret is revealed only to that device, when it ships a range containing that minute.
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
- the beacon exists, is not newer than the block, and is newer than every beacon a ship of this device has already revealed (`revealed_beacon` otherwise: once a secret is known, the device must not chain new frames or trees under it). A beacon older than the previous minute, or a block more than 5 minutes behind server time, marks the block `offline` (accepted at lower confidence, never older than 24 hours);
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

1. `POST /api/desktop/v1/ships {project, from_seq, to_seq, excluded}` opens a draft and reveals the device's secrets for the beacons of the minutes it keeps (`revealed[].secret`). Clients check each against its commitment. From then on the device cannot chain blocks under those beacons or older ones. `excluded` is optional: a list of `{from_seq, to_seq}` ranges (inclusive, inside the ship's range, at most 200 after merging, leaving at least one minute) that the user removed on the app's review timeline. A removed minute earns nothing, its secret is not revealed, and none of its frames or snapshots are asked for. The response returns them merged as `excluded_ranges` (`[[from, to], …]`). Opening the same range again replaces the draft's removed minutes. Removing a minute after an earlier draft had already asked for its frame or snapshot is allowed but flagged for reviewers (`removed_checks`).
2. A timelapse frame is required when `SHA256("hkt-required-v1\n" || device_secret || frame_hash)[0] < 256 × 0.08` (about five an hour). Required frames can be redacted (the copy is marked redacted and lists its regions for reviewers) but not removed. A redacted copy is sealed with the frame's own segment key, must be a PNG or JPEG (the server cannot decode HEIC; the app sends JPEG), must be at most 2,560 pixels on a side, must list at least one region (`x`, `y`, `w`, `h` in whole pixels from the top left, inside the image, covering at most half of it), and its block must have committed the frame's `phash`. `phash` is the frame as an 8×8 greyscale grid: the mean brightness (0 to 255) of each cell, one byte per cell, row by row from the top left, written as 128 hex digits. The server decrypts the copy and recomputes the grid. At least 16 cells must be untouched by every region, and at most a tenth of those may differ from the committed value by more than 12. Covering part of a frame does not change the cells left clear, so any honest redaction passes; a different picture does not.
3. The server picks code spot-checks: the first and last snapshots of the range, plus every snapshot whose `SHA256("hkt-spot-check-v1\n" || device_secret || tree_root)[0] < 256 × 0.08`. The number varies. Each choice depends only on the block, so opening, re-ranging or re-creating a draft never changes it.
4. `POST /ships/:id/frames` uploads each frame with its segment key. A minute the ship keeps must have committed the frame's hash. An unredacted frame must hash to its committed value and decrypt.
5. `POST /ships/:id/submit` sends the final shipped files (git-tracked only) and each spot-checked snapshot as its ordered leaf list. Tracked files go with content; every other file goes as its leaf hash only. Each snapshot must hash back to its committed root and overlap the shipped repo by winnowed k-gram fingerprints (as in MOSS). A root mismatch zeroes the ship.

## Scoring

Rules run first: mouse movement alone and jiggler or injected-input minutes earn nothing, a block without `keys` and `clicks` (no Input Monitoring permission) has unknown input and is never treated as idle or mouse-only but earns no human-input confidence, runs of the same frame `hash` zero out (the app repeats a hash while the screen is unchanged; `phash` is too coarse to tell an edit from a frozen screen), switches of about 2 minutes still count, minutes whose `project` is another project (compared case-insensitively) and minutes the user removed from the ship count nothing, not even as a switch, and research, testing and AI waiting count only when an edit, prompt or commit follows within 10 minutes. A timelapse frame counts as on time only when its block was sent online and its `at_ms` is no later than the block's `captured_at_ms` and at most two minutes before it, so frames belong in the block sealed after they were taken. Only an `app_attest` key adds confidence; `secure_enclave` and `tpm` are recorded as claimed but nothing verifies them. Then a calibrated LightGBM model (`EVIDENCE_MODEL_PATH`, trained by `script/evidence/train_model.py`) or the rules-only weights give each stretch a confidence. The output ceiling from the shipped diff caps the total.

Weights, thresholds and ceilings live in private config (`EVIDENCE_CONFIG_PATH`); the defaults in `app/services/evidence/config.rb` are only starting points.
