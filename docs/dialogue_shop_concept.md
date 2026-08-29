# Dialogue and Shop System Concept

## Purpose

Bring the useful interaction ideas from the inspected Open Net Battle Lua system into Tiny Demons as a small, reusable Godot system. The goal is to port the behavior and flow—not the Lua API, multiplayer assumptions, or artwork.

This system should make NPC conversations and shops feel deliberate, readable, and safe to use with the game's pixel-art presentation.

The shop interaction contract remains useful, but current equipment identity,
six-slot stock, source tags, and purchase boundaries are defined in
gear-catalogue-spec.md and gear-drop-tables.md.

## Goals

1. Provide reliable NPC dialogue with pages, typewriter text, confirm/cancel input, and clean open/close behavior.
2. Provide a reusable vertical choice menu with a visible cursor, highlighted rows, confirm, and cancel.
3. Build shops as a dialogue-driven flow: browse an item, inspect its price, confirm, receive a result, then continue shopping or leave.
4. Prevent modal input from leaking into movement, attacks, or the next interaction.
5. Reuse Tiny Demons' existing pixel text, UI layout, player gold, and state-management conventions.

## Non-goals for the first implementation

- Importing Lua scripts or creating a Lua compatibility layer.
- Recreating multiplayer/player-ID abstractions from Open Net Battle.
- Adding shop artwork before the interaction flow is proven.
- Expanding the economy system beyond the existing gold/resource source.
- Making every dialogue a general-purpose scripting language.

## Intended interaction flow

```text
NPC interaction
    -> Open dialogue
    -> Typewriter text
    -> Wait for confirm
    -> Browse choices or shop items
    -> Confirm selection
    -> Show result
    -> Return to menu or close
```

The dialogue state machine should use explicit states such as:

```text
CLOSED -> OPENING -> TYPING -> WAITING
                           -> MENU -> CONFIRMING -> RESULT
                                      ^              |
                                      +--------------+
                           -> CLOSING -> CLOSED
```

The exact names can follow existing project conventions, but transitions must be explicit. A closed interaction must not retain stale text, cursor position, or purchase state.

## Responsibility boundaries

### Dialogue controller

- Owns the active conversation and page index.
- Reveals text with the typewriter effect.
- Handles confirm-to-finish-typing and confirm-to-advance behavior.
- Locks gameplay input while active.
- Swallows the interaction button that opened the conversation.
- Guarantees that closing requires a fresh input edge.

### Menu controller

- Owns options, cursor position, row highlighting, and navigation.
- Provides confirm and cancel results to its caller.
- Does not directly change gold or inventory.

### Shop controller

- Owns the shop catalog and selected item.
- Displays item name, description, price, and affordability.
- Requests a purchase through the economy/inventory boundary.
- Shows success or insufficient-gold feedback.
- Returns to browsing after a result or exits cleanly.

### Rendering layer

- Uses the existing Tiny Demons pixel text and UI components.
- Keeps arrows, cursor glyphs, and highlighted text consistent with the customize menu.
- Starts with text and existing panels; artwork can be added later without changing shop logic.

### Economy boundary

Purchases must validate affordability and mutate gold exactly once. The shop should receive a success/failure result rather than reaching into unrelated gameplay state. A failed purchase must never subtract gold or partially grant an item.

## Suggested shop data

Shop entries should be data, not hard-coded branches in the UI:

```gdscript
{
    "id": &"potion",
    "name": "Potion",
    "price": 25,
    "description": "Restores health.",
}
```

The original concept allowed a small static catalog while the boundary was
being built. Current equipment purchases must use the authored item catalogue
and the real inventory/economy boundary; menu presentation must not invent
gear definitions.

## Tiny Demons integration

- An NPC controller starts a dialogue session when the player interacts.
- The screen/state controller owns the modal interaction mode, or delegates to a dedicated dialogue mode if that better matches the current architecture.
- The frame controller updates dialogue/menu logic while active and suppresses player movement, attacks, and room interaction.
- Existing gold data remains the source of truth.
- Existing pixel UI helpers remain the source of truth for presentation.

## Input safety requirements

Input handling is a core part of the feature, not polish:

- The opening interaction press cannot also advance the first page.
- Confirming a choice cannot trigger movement or an attack on the same frame.
- Holding a button cannot repeatedly buy an item or skip multiple pages.
- Cancel closes the current menu before closing the whole conversation when appropriate.
- Only one modal dialogue or shop session can be active at a time.

## Implementation phases

1. Extract a dialogue state machine and test it with a simple NPC conversation.
2. Add the reusable vertical menu and connect it to dialogue choices.
3. Add a shop catalog, price display, affordability checks, and purchase results.
4. Integrate the existing gold/inventory boundary.
5. Polish typewriter timing, cursor behavior, input buffering, and pixel layout.

## Acceptance criteria

- Dialogue opens without immediately consuming the opening input.
- Player movement and attacks are disabled during the modal interaction.
- Confirm, cancel, and held-button behavior are edge-safe.
- Dialogue can be reopened with no stale page or cursor state.
- An unaffordable item leaves gold and inventory unchanged.
- A successful purchase subtracts the price once and grants the result once.
- The player can browse multiple items, see a result, return to the shop, and exit normally.
- The system remains usable without any imported Open Net Battle artwork or Lua runtime.

## Design principle

Port the interaction model, not the implementation. Tiny Demons should get a focused Godot-native dialogue and shop system that fits its current state, input, economy, and pixel-art architecture.
