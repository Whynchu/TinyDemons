# Gameplay Stability Investigation and Correction Plan

Status: active; bone-hit attack preservation accepted in playtest; mobile
freeze, hitch, doorway, and skeleton-spacing acceptance remain open

Owner: movement/collision, pickup persistence, effects/combat, and enemy AI

Reports: 2026-09-26–27 playtesting; hitching is the highest-priority concern

## Reported behavior

1. Player combat near a doorway can leave the player stuck in the opening.
2. Gameplay hitches during reward collection and flame interaction.
3. Mobile browser gameplay can freeze during boss fights, especially around
   area attacks and reward collection. The trigger is not yet isolated.
4. Skeletons close too far instead of holding a useful mid-range throwing
   position.
5. A bone hit should not cancel a player attack or sword-beam charge already
   in progress.

These symptoms have different owners. Do not treat the mobile freeze as proof
that enemy count, particles, or pickup persistence is the cause until a trace
reproduces it.

## Findings and current corrections

### 1. Collection and interaction hitches — highest priority

The pickup path has confirmed synchronous work. Gold, Souls, and world-item
collection call the profile save path at contact time. That path serializes the
profile, writes a temporary file, validates it, rotates a backup, renames the
file, and writes browser `localStorage` on Web. Chroma pickups also refresh
player presentation and spawn pickup feedback. Multiple contacts in one frame
can repeat these costs. A single contact can still hitch; frame coalescing is
not considered a complete performance fix.

First correction: pickup persistence requests are coalesced and flushed once at
the end of the gameplay frame. This bounds multiple pickups collected together
to one save while preserving the current same-frame save boundary.

Second correction (2026-10-02): the coalescing above was real but did not
actually remove the hitch, exactly as this section warned. The flush still ran
on the same physics frame that queued it, so a single contact performed a full
serialize + write + **re-read + re-parse + `PlayerProfile` rebuild** plus four
more filesystem operations alongside the particle burst, the audio start, and
the HUD count-up. The write is now queued rather than performed, never lands on
the requesting frame, and the re-parse is replaced by a byte-length check; see
`KNOWN_ISSUES.md` for the full list. `RunCheckpointService` and `RunSettlement`
force the queue so durability boundaries are unchanged.

Next evidence: the fixed-seed harness now has an `item_pickup` scenario and
`profile_save_write` / `profile_save_queue_delay` recorded scopes. Still needed
on real hardware: cold and warm frames for one gold pickup, a multi-pickup
burst, first flame interaction, and first-use audio/effect work, recorded as
worst frame, average, and save duration separately on desktop and a mobile
browser/device. **No post-change measurement has been taken yet.**

### 2. Boss AOE freeze — open investigation

The current effect path can create many individual particle sprites when
several enemies die together; boss combat also updates projectiles, hit flashes,
health bars, targeting, and pickup drops in the same frame. These are concrete
cost centers, not a confirmed cause. The existing particle cap is applied in
the update path and does not prevent a large burst from being constructed
before that update.

Reproduce with a fixed boss seed and separate scenarios: sword beam without
kills, AOE hitting several enemies, simultaneous death effects, pickup burst,
and the combined sequence. Capture frame timing and peak effect/pickup/node
counts. Inspect Web console errors and memory growth during repeated trials.
Only then bound or pool the measured hot effect path, retaining hit, outline,
and impact readability at native pixel scale.

### 3. Doorway combat pinning — first movement correction

Active door sockets are intentionally walkable, and enemy contact normally
reduces player movement and resolves overlap by pushing either actor. In a
narrow opening, that response can hold the player against the enemy or socket.
While the player's foot guide is inside an available active socket, player
movement now bypasses enemy-contact damping and enemy-contact separation. The
door transition remains responsible for crossing the socket; closed sockets
are unaffected.

Acceptance: fight beside each supported doorway orientation, walk into and out
of the opening while touching an enemy, and confirm the player can always leave
without passing through static walls or opening a locked exit.

### 4. Skeleton spacing — first AI correction

Skeletons currently reuse the slime aggro target at roughly 72% of melee attack
range. Their steering therefore pulls them toward the player even though their
attack is ranged. Skeletons now use a 72 px preferred distance with a 12 px
settling band; beyond the band they approach, inside it they orbit, and too
close they retreat. Their attack eligibility distance is capped to that band.
Slime and boss spacing rules are unchanged.

Acceptance: observe skeletons at open floor, near walls, and in a boss room;
they should hold a visible mid-range, reposition when the player closes in, and
continue throwing reliably without approaching into melee contact.

### 5. Bone hits during player attacks — resolved in playtest

Skeleton bones use the ranged-hit path in `SlimeActor.apply_attack_hit`. That
path previously called the same attack interruption routine as melee hits.
Bone hits now keep their damage, flash, hitstop, and knockback feedback but do
not cancel an active attack or charge. The attack must still complete if the
player holds the input; death and ordinary melee-hit interruption behavior are
unchanged.

Acceptance: the user reports this behavior now works. Reopen only if a
regression appears; the code path keeps its damage feedback while preserving
the player's active attack and charge.

## Work order

1. Coalesce same-frame pickup saves and profile the pickup/flame interactions.
2. Confirm the doorway escape behavior with focused movement evidence and
   correct any remaining socket-specific geometry issue.
3. Use the skeleton preferred-range rule and tune only from gameplay evidence.
4. Bone-hit attack preservation is accepted; retain it during future combat
   changes.
5. Reproduce the potentially open boss AOE freeze with isolated and combined
   Web scenarios.
6. Optimize the measured freeze cause, then compare before/after on desktop and
   mobile browser/device. Keep a repeat-run and long-session memory check.

## Completion bar for personal testing

- No repeatable doorway pinning in authored doorway orientations.
- Skeletons hold and recover a readable throwing distance without melee
  crowding.
- Bone hits do not cancel ordinary attacks or sword-beam charge, and still
  deliver their normal damage response.
- Pickup and flame interactions show no repeated visible hitch in a warmed
  session, with cold first-use costs recorded separately.
- Boss AOE, multi-death effects, and reward collection complete without a
  browser freeze across repeated runs on the target phone.
- Before/after frame samples, Web console output, and peak scene counts are
  recorded. A desktop-only pass does not close the mobile freeze report.

See [`long-term-composition-and-performance-plan.md`](long-term-composition-and-performance-plan.md)
for the existing T3 harness and device-budget policy.
