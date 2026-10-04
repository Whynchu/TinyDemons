# Tiny Demons at a glance

**Status:** current summary; verify shipped details against the linked sources.

Tiny Demons is a bite-sized isometric action dungeon crawler about a small
elemental demon. The player explores compact rooms, fights readable enemies,
collects Chroma and gear, changes element during a run, and brings lasting
rewards back to the Demon Hub.

## The identity

An element is a combat class, not just a color. It shapes the player's spell,
combat matchups, and some optional routes. Universal weapon skills keep the
player capable even when an element is a poor matchup.

## The loop

```text
Choose a flame → explore and fight → collect rewards and learn the route
      ↑                                                        ↓
      └──── return to the Demon Hub, tune the build, dive again ┘
```

Runs are short and replayable. Death ends the current run while preserving
long-term progression and collected gear.

## Design pillars

- Element is class identity.
- Combat rewards attention and timing.
- Each run should ask a different question.
- A small number of rules should create useful combinations.
- Any starter element can complete the critical path.
- Telegraphs and outcomes must read at the game's small pixel-art scale.
- Important actions give immediate, legible feedback.
- The tone is cozy and mysterious, with a little cruelty around failure.

## State of the game

Use the labels below when discussing features:

- **Shipped:** exists in the current build; confirm with the current game and
  [known issues](../KNOWN_ISSUES.md).
- **Planned:** accepted or proposed work that is not necessarily implemented;
  follow the status stated by its owning plan.
- **Open:** a decision or verification question remains unanswered.

This page is a compact orientation only. The [game design document](../game-design-document.md)
owns the full game contract, status markers, systems, and 1.0 direction. The
[roadmap](../ROADMAP.md) owns sequencing; [AUDIT.md](../AUDIT.md) and
[KNOWN_ISSUES.md](../KNOWN_ISSUES.md) own implementation and verification reality.

## Visual entry points

The repository has a [game screenshot](../game-screenshot.png) and
[generated dungeon map diagrams](../../screenshots/dungeon_maps/). The visual
guide explains how to capture and label future examples.
