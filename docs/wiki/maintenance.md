# Wiki maintenance

The wiki should make decisions easier to find. Keep it smaller than the full
design archive and link to the documents that own details.

## Page status

Use one of these labels near the top of every substantial page:

- **Current:** describes the approved or shipped state; include evidence and
  links to its authority.
- **Proposed:** an idea that needs review. Do not present it as implemented.
- **Accepted:** the owner approved the direction, but it may not be shipped.
- **Shipped:** implemented; link to the owning spec, code, and verification.
- **Historical:** kept for rationale. Name its successor and do not link it as
  current authority.

## Authority and freshness

- Each rule has one detailed owner. The wiki summarizes it and links there.
- Mark decisions with dates and state who made or ratified them when helpful.
- When implementation diverges from intent, describe both and point to
  `AUDIT.md` or `KNOWN_ISSUES.md`; do not quietly rewrite history.
- When changing ownership, update `ARCHITECTURE.md`,
  `DOCUMENTATION_MAP.md`, and the relevant wiki index in the same change.
- Prefer moving a decision into an existing authority over creating another
  overlapping plan.

## Images and experiments

Follow [visual references and experiments](visuals-and-experiments.md). Captures
of actual game builds and browser-only prototypes must have distinct labels.
Keep large raw capture sets out of the wiki. Keep source project art in its
existing folders and respect the [asset provenance guide](../asset-provenance.md).

## Adding a page

Start from the [feature brief template](feature-brief-template.md), remove
sections that do not apply, and link the final page from this wiki index and
the relevant topic in [systems map](systems-map.md). Do not duplicate long
implementation plans, tuning tables, or code inventories here.
