# Tiny Demons — Mobile Touch Button and Haptics Plan

Status: approved direction (design interview 2026-09-18)

Scope: touch-layer action buttons and mobile input haptics only; no change to
desktop or gamepad mappings

Owner: `touch_controls_layer.gd`, `input_router.gd`, `settings_service.gd`

Current code: `touch_controls_layer.gd` (`BUTTON_ARC`, `BUTTON_LABELS`,
`_finger_down`, `tap_interact` path), `input_device_tracker.gd`, `input_router.gd`

Verification: touch smoke tests, device-input tests, and manual phone/web touch
checks

Supersedes: none; this records interview decisions for regular implementation

Updated: 2026-09-18

## 1. Remove the USE button

The mobile touch overlay currently shows six gameplay buttons: `attack`,
`roll`, `magic`, `guard`, `target`, and `interact`. The `interact` button is
labeled `USE` (`BUTTON_LABELS`) and sits on the action arc at angle `110`,
radius `1.60` (`BUTTON_ARC`).

Decision: remove the `USE`/`interact` button from the touch overlay and reflow
the remaining buttons into its place on the arc.

Rationale:

- World taps already drive interaction through the `tap_interact` path
  (`_finger_down` assigns `TAP_INTERACT_ACTION` and presses the `interact`
  input, `touch_controls_layer.gd:521-525`). The USE button is therefore a
  redundant explicit control on touch.
- Removing it reduces thumb reach distance for the remaining actions and frees
  the upper-left arc position currently occupied by `interact`.
- Touch-only players still interact by tapping an interactable in the world;
  the contextual prompt remains.

### 1.1 Reflow plan

- Remove `&"interact"` from `BUTTON_ARC` and from `BUTTON_ORDER`.
- Re-space the remaining arc actions (`attack`, `magic`, `guard`, `target`)
  around the `roll` primary so no button overlaps and the cluster stays within
  thumb reach.
- Keep the `tap_interact` world-touch path and `set_button_state(&"interact",
  ...)` behavior intact; it must not depend on a visible button.
- The `interact` input action itself remains for keyboard/controller and for
  the menu/dialogue contexts.

## 2. Haptics on mobile button presses

Decision: add a slight input vibration when gameplay touch buttons are pressed
on mobile.

Guidance:

- Small, short pulse on press; do not vibrate on release or on finger drag.
- Keep it optional and user-controllable through the existing settings service
  (vibration toggle), consistent with the accessibility question in the design
  questionnaire (Q17.6: adjust vibration, audio, or flash intensity).
- Respect device capability: no-op where haptics are unsupported or disabled.
- Do not add vibration to the virtual stick movement; only discrete presses.
- Intensity should be subtle, not a "hit" rumble — it signals button
  registration, not damage feedback.

## 3. Out of scope

- Desktop and gamepad input mappings (unchanged).
- Damage/hit haptics in combat (separate concern, not decided here).
- Changing the action arc layout for controller or keyboard.