# Tiny Demons — Authored Gear Catalogue

## Status

**Approved catalogue — all 44 rows are authored in the runtime schema and
available to the shared read model.** Names and numerical values remain
balance-review material. The slot structure, source metadata, and content direction are approved;
implementation uses the contracts in [`gear-catalogue-spec.md`](gear-catalogue-spec.md)
and [`gear-effect-contracts.md`](gear-effect-contracts.md). Rows with
`future` effect status remain visible to inspection but are gated from live
generation until their owner is implemented.

The catalogue deliberately distinguishes an item’s *identity* from its rarity.
One authored base can produce Common through Mythic instances while retaining
the same family question and visual identity.

## Catalogue key

- **Existing** means the name/identity already exists in the runtime catalogue.
- **New** means an expansion identity newly added to the runtime schema in this
  slice; a row can still be gated from live generation when its effect is
  marked `future`.
- `P` is the primary tier-scaled stat.
- `S` is a fixed secondary lane or visible tradeoff.
- An elemental name means resonance or ward behavior, not a silent replacement
  of the player’s current Chroma aspect.

## Weapon catalogue

| ID | Display name | State | Family | Role and stat lane | Signature question |
| --- | --- | --- | --- | --- | --- |
| `basic_sword` | BASIC SWORD | Existing | Blade | P: STR; S: reliable baseline | Can the starter weapon remain useful through fundamentals? |
| `soldier_sword` | SOLDIER SWORD | Existing | Blade | P: STR; S: modest AGI tradeoff | Can Attack 1 set up a stronger Attack 2 against a crowd? |
| `guardian_blade` | GUARDIAN BLADE | Existing | Blade | P: DEF; S: STR/AGI tradeoff | Can guard play turn defense into deliberate offense? |
| `blood_blade` | BLOOD BLADE | Existing | Blade | P: VIT; S: lower AGI | Is the player willing to spend or risk health for output? |
| `iron_maul` | IRON MAUL | Existing | Maul | P: STR; S: heavy AGI tradeoff | Does a slower charge or finisher create a stronger opening? |
| `quick_dagger` | QUICK DAGGER | Existing | Dagger | P: AGI; S: lighter physical output | Can movement, roll, run, and follow-up timing become the build? |
| `emberbrand` | EMBERBRAND | New | Blade | P: STR; S: Fire Imbue Resonance | Does matching Fire Imbue make the physical/magic split worth pursuing? |
| `tideglass_rapier` | TIDEGLASS RAPIER | New | Dagger/Blade | P: AGI; S: INT or MND | Can a precise, mobile attack build pair with Water utility? |
| `rootbreaker` | ROOTBREAKER | New | Maul | P: DEF or STR; S: knockback/charge lane | Can weight and positioning control a room without becoming a raw damage stick? |
| `mindweave_rod` | MINDWEAVE ROD | New | Focus/Rod | P: INT; S: MND and Imbue support | Can a magic-forward weapon make Triangle and Imbue distinct choices? |

Existing weapon transmutation associations remain explicit:

| Base | Current transmutation | Catalogue role |
| --- | --- | --- |
| SOLDIER SWORD | Gathering Edge | Multi-target Attack 1 into Attack 2 |
| BLOOD BLADE | Blood Feed | Damage-to-healing identity |
| GUARDIAN BLADE | Reserved for a future defensive blade effect | Do not invent a hidden passive during migration |

`EMBERBRAND`, `TIDEGLASS RAPIER`, `ROOTBREAKER`, and `MINDWEAVE ROD` require
effect contracts before they can enter the drop pool. Their names do not by
themselves add new animations or weapon input.

## Head catalogue

| ID | Display name | State | Family | Role and stat lane | Signature question |
| --- | --- | --- | --- | --- | --- |
| `plain_hood` | PLAIN HOOD | New | Cloth | P: none; zero-power starter | Can the new Head slot be visible without free power inflation? |
| `iron_helm` | IRON HELM | New | Helm | P: DEF or VIT; S: AGI tradeoff | Is physical safety worth slower movement and recovery? |
| `feather_cap` | FEATHER CAP | New | Light headgear | P: AGI; S: small recovery utility | Can a light build stay active without duplicating Swift Boots? |
| `mind_circlet` | MIND CIRCLET | New | Circlet | P: MND; S: INT | Can MND become visibly valuable through M.DEF and magic defense? |
| `ember_crown` | EMBER CROWN | New | Elemental crown | P: INT or MND; Fire Ward/Resonance | Does it reward matching Fire without changing the player’s aspect? |
| `shadow_mask` | SHADOW MASK | New | Mask | P: MND or AGI; Shadow Ward/utility | Can a risky, evasive identity remain readable and bounded? |

Head effects are defensive or spell-facing. A Head item should not become a
second Accessory with a general gold, Souls, or drop-rate multiplier.

## Body catalogue

`armor` is the legacy data key for this slot. New documentation and UI use
`body`/BODY.

| ID | Display name | State | Family | Role and stat lane | Signature question |
| --- | --- | --- | --- | --- | --- |
| `basic_tunic` | BASIC TUNIC | Existing | Tunic | P: VIT; S: DEF | Does the baseline survive while the player learns the room? |
| `bloodwoven_tunic` | BLOODWOVEN TUNIC | Existing | Tunic | P: VIT; S: AGI | Can Core HP and VIT support controlled health-risk effects? |
| `iron_cuirass` | IRON CUIRASS | Existing | Heavy armor | P: DEF; S: VIT and AGI penalty | Is raw physical protection worth reduced mobility? |
| `feather_cloak` | FEATHER CLOAK | Existing | Cloak | P: AGI; S: light survival | Can mobility compensate for lower raw defense? |
| `mindweave_robe` | MINDWEAVE ROBE | Existing | Robe | P: MND; S: INT | Can a robe protect against magic without competing with a shield? |
| `chainmail` | CHAINMAIL | New | Mail | P: VIT or DEF; S: balanced package | Is a dependable middle path better than a sharp specialization? |
| `ash_mantle` | ASH MANTLE | New | Mantle | P: INT or MND; Fire Ward/Imbue utility | Can elemental protection be useful without overriding Chroma? |
| `rootplate` | ROOTPLATE | New | Heavy plate | P: DEF; S: knockback resistance and AGI penalty | Can the player hold ground against forceful enemies? |

Existing Body transmutation:

| Base | Current transmutation | Catalogue role |
| --- | --- | --- |
| BLOODWOVEN TUNIC | Bloodwoven Core | Core HP and VIT-health identity |

## Arm catalogue

| ID | Display name | State | Family | Role and stat lane | Signature question |
| --- | --- | --- | --- | --- | --- |
| `cloth_wraps` | CLOTH WRAPS | New | Wraps | P: none; zero-power starter | Can the new Arm slot be present without adding free stats? |
| `iron_gauntlets` | IRON GAUNTLETS | New | Gauntlets | P: STR; S: charge/lunge | Can a heavy hand make committed attacks feel deliberate? |
| `duelist_gloves` | DUELIST GLOVES | New | Gloves | P: AGI; S: Attack 2/recovery | Can precise follow-ups reward timing instead of raw damage? |
| `sage_sleeves` | SAGE SLEEVES | New | Sleeves | P: INT; S: MND/Imbue | Can magic strength enter the physical kit without replacing STR? |
| `guard_bracers` | GUARD BRACERS | New | Bracers | P: DEF; S: guard recovery | Can active blocking feel stronger without making shields mandatory? |
| `thorn_claws` | THORN CLAWS | New | Claws | P: STR or DEF; counter/knockback lane | Can a successful block or hit create a visible counter decision? |

Arm effects must use existing attack, charge, spin, guard, recovery, and
running-attack boundaries where possible. They may not directly award Style.

## Shield catalogue

| ID | Display name | State | Family | Role and stat lane | Signature question |
| --- | --- | --- | --- | --- | --- |
| `basic_shield` | BASIC SHIELD | Existing | Shield | P: DEF; S: VIT and small AGI penalty | Does the player understand the core guard contract? |
| `living_bulwark` | LIVING BULWARK | Existing | Bulwark | P: DEF; S: high guard durability and AGI penalty | Can the shield anchor a defensive build? |
| `thorn_guard` | THORN GUARD | Existing | Thorn shield | P: VIT; S: DEF and counter lane | Can absorbing pressure create an offensive answer? |
| `parry_buckler` | PARRY BUCKLER | Existing | Buckler | P: DEF; S: light guard and AGI | Can a player trade durability for active timing? |
| `mirror_ward` | MIRROR WARD | New | Ward shield | P: MND; S: elemental ward and lighter guard | Can magic defense matter while the shield remains interactive? |
| `frostwall` | FROSTWALL | New | Heavy shield | P: DEF; S: Ice Ward and AGI penalty | Can a stable wall build control elemental pressure? |

Existing Shield transmutation:

| Base | Current transmutation | Catalogue role |
| --- | --- | --- |
| LIVING BULWARK | Bastion Core | DEF-scaled durability and Attack 2 knockback charges |

## Accessory catalogue

| ID | Display name | State | Family | Role and stat lane | Signature question |
| --- | --- | --- | --- | --- | --- |
| `bangle` | BANGLE | Existing | Bracelet | P: balanced small stats | Is a flexible baseline useful without being optimal everywhere? |
| `duelist_seal` | DUELIST SEAL | Existing | Seal | P: STR; S: AGI tradeoff | Can target lock create a single-target commitment? |
| `warrior_charm` | WARRIOR CHARM | Existing | Charm | P: STR; S: DEF and AGI tradeoff | Can a straightforward physical build stay attractive? |
| `swift_boots` | SWIFT BOOTS | Existing | Boots | P: AGI; S: mobility | Can run, roll, and attack flow become a complete identity? |
| `chroma_talisman` | CHROMA TALISMAN | Existing | Talisman | P: INT; S: MND and Chroma utility | Can Chroma support be meaningful without free Souls? |
| `soul_locket` | SOUL LOCKET | New | Locket | P: MND or VIT; pickup-radius utility | Can collecting Souls feel smoother without multiplying currency? |
| `runebound_knot` | RUNEBOUND KNOT | New | Knot | P: AGI or INT; combo-window utility | Can sustained contact be supported without directly adding Style? |
| `elemental_knot` | ELEMENTAL KNOT | New | Knot | P: INT or MND; Imbue Resonance | Can matching an active aspect make the composite weapon contract sing? |

Existing Accessory transmutation:

| Base | Current transmutation | Catalogue role |
| --- | --- | --- |
| DUELIST SEAL | Duelist Focus | Locked-target STR scaling with an off-target tradeoff |

`SOUL LOCKET` may improve collection distance, landing behavior, or pickup
comfort. It may not increase Souls per enemy. `RUNEBOUND KNOT` is a working
name for a combo-window utility and must receive a concrete effect contract
before implementation. The ID remains lowercase and stable.

## Reserved future families

These are supported by the catalogue schema but intentionally do not enter the
drop pool yet:

| Family | Required before implementation |
| --- | --- |
| Spear | Reach profile, directional hit shape, animation, and lunge rules |
| Bow/Thrown | Projectile ownership, ammo/resource rules, and mobile targeting |
| Tome | Spell selection and a clear distinction from Triangle/Focus |
| Fist/Claw | Unarmed or close-range animation identity beyond Arm gear |
| Bell/Harp | Support/status contracts that do not bypass the action kit |
| Dark weapon line | A deliberate Shadow-element rule and matchup presentation |

The existence of these families must not force placeholder stats into the
current generator. They are documentation extension points only.

## Implementation record matrix

The overview tables above preserve the design questions for review. This
matrix is the implementation handoff: it assigns every approved base a
primary/secondary package, an effect owner or explicit stat-only state, source
tags, a provisional rarity gate, and player-facing copy. Numeric values remain
in the balance pass.

| ID | Slot | State | Package | Effect contract / gate | Sources | Player-facing copy |
| --- | --- | --- | --- | --- | --- | --- |
| basic_sword | Weapon | Existing | P STR | Stat snapshot only | STARTER, SHOP, CHEST, CLEAR | A dependable blade with no trick. |
| soldier_sword | Weapon | Existing | P STR; S AGI - | Gathering Edge transmutation, EPIC+ | SHOP, CHEST, CLEAR | Attack 1 against several targets improves the same-target share of Attack 2. |
| guardian_blade | Weapon | Existing | P DEF; S AGI - | Stat snapshot only; future defensive effect is reserved | SHOP, CHEST, CLEAR | A defensive blade that turns DEF into a deliberate offensive choice. |
| blood_blade | Weapon | Existing | P VIT; S AGI - | Blood Feed transmutation, LEGENDARY+ | SHOP, CHEST, CLEAR | Damage dealt can return a bounded portion of the hit as health. |
| iron_maul | Weapon | Existing | P STR; S AGI - | Stat snapshot only; charge profile reserved | SHOP, CHEST, CLEAR | A heavy weapon whose committed timing is the price of its force. |
| quick_dagger | Weapon | Existing | P AGI | Stat snapshot only | SHOP, CHEST, CLEAR | A light blade for movement, running attacks, and follow-ups. |
| emberbrand | Weapon | New | P STR; S AGI - | Imbue Resonance FIRE, future, RARE+ | CHEST, CLEAR, BOSS | Matching Fire Imbue strengthens its magic portion without changing the demon’s aspect. |
| tideglass_rapier | Weapon | New | P AGI; S INT | Imbue Resonance WATER, future, RARE+ | CHEST, CLEAR, BOSS | A mobile precision blade for a matching Water Imbue. |
| rootbreaker | Weapon | New | P STR; S DEF; AGI - | Charge profile, future, RARE+ | CHEST, CLEAR, BOSS | A grounded maul for charged openings, lunge control, and knockback decisions. |
| mindweave_rod | Weapon | New | P INT; S MND | Stat snapshot only; magic-forward baseline | SHOP, CHEST, CLEAR | Strengthens Triangle and Imbue magic while leaving the physical STR portion intact. |
| plain_hood | Head | New | P none; zero power | No effect; starter-only | STARTER ONLY | Fills the Head slot without changing combat power. |
| iron_helm | Head | New | P DEF; S VIT; AGI - | Recovery multiplier, future, RARE+ | SHOP, CHEST, CLEAR | Heavy protection with a visible recovery tradeoff. |
| feather_cap | Head | New | P AGI; S MND | Recovery multiplier, future, RARE+ | SHOP, CHEST, CLEAR | Light headgear for staying active through clean movement and recovery. |
| mind_circlet | Head | New | P MND; S INT | Stat snapshot only | SHOP, CHEST, CLEAR | Raises M.DEF through MND and supports the magic side of the kit. |
| ember_crown | Head | New | P INT; S MND | Elemental Ward FIRE, future, EPIC+ | CHEST, CLEAR, BOSS | Reduces Fire pressure after the shared elemental matchup step. |
| shadow_mask | Head | New | P AGI; S MND | Elemental Ward SHADOW, future, EPIC+ | CHEST, CLEAR, BOSS | Adds Shadow protection without changing the player’s own element. |
| basic_tunic | Body | Existing | P VIT; S DEF | Stat snapshot only | STARTER, SHOP, CHEST, CLEAR | A plain survival baseline for learning rooms and building VIT. |
| bloodwoven_tunic | Body | Existing | P VIT; S AGI + | Bloodwoven Core transmutation, EPIC+ | SHOP, CHEST, CLEAR | Core HP and VIT make health-risk choices more forgiving. |
| iron_cuirass | Body | Existing | P DEF; S VIT; AGI - | Stat snapshot only | SHOP, CHEST, CLEAR | Reliable physical protection that gives up some mobility. |
| feather_cloak | Body | Existing | P AGI | Stat snapshot only | SHOP, CHEST, CLEAR | A mobile body layer for surviving through repositioning. |
| mindweave_robe | Body | Existing | P MND; S INT | Stat snapshot only | SHOP, CHEST, CLEAR | A magic-defense body layer that supports M.DEF and Triangle. |
| chainmail | Body | New | P VIT; S DEF | Stat snapshot only, COMMON+ | SHOP, CHEST, CLEAR | A dependable middle path with no sharp action requirement. |
| ash_mantle | Body | New | P MND; S INT | Imbue Resonance FIRE, future, RARE+ | CHEST, CLEAR, BOSS | A Fire-attuned layer that improves matching Imbue without assigning Fire to the demon. |
| rootplate | Body | New | P DEF; S VIT; AGI - | Knockback resistance, future | CHEST, CLEAR, BOSS | Holds ground against forceful enemies at a clear mobility cost. |
| cloth_wraps | Arm | New | P none; zero power | No effect; starter-only | STARTER ONLY | Fills the Arm slot without adding free combat power. |
| iron_gauntlets | Arm | New | P STR; S AGI - | Charge profile, future, RARE+ | SHOP, CHEST, CLEAR | Put weight behind charged attacks and accept a handling cost. |
| duelist_gloves | Arm | New | P AGI; S STR | Running Attack profile, future, RARE+ | CHEST, CLEAR | Reward the timing between a roll, a run, and the next attack without awarding Style. |
| sage_sleeves | Arm | New | P INT; S MND | Stat snapshot only | SHOP, CHEST, CLEAR | Strengthen Triangle and the magic portion of Imbue. |
| guard_bracers | Arm | New | P DEF; S VIT | Guard reduction, future, RARE+ | CHEST, CLEAR, BOSS | Make active blocking matter without replacing the Shield slot. |
| thorn_claws | Arm | New | P STR; S DEF | Attack lunge profile, future, RARE+ | CHEST, CLEAR, BOSS | Turn committed contact and knockback into a close-range decision. |
| basic_shield | Shield | Existing | P DEF; S VIT; AGI - | Built-in guard durability and reduction | STARTER, SHOP, CHEST, CLEAR | Teaches the core block contract with a readable guard package. |
| living_bulwark | Shield | Existing | P DEF; S VIT; AGI penalty | Built-in guard package; Bastion Core, EPIC+ | SHOP, CHEST, CLEAR | Converts DEF and successful blocks into a stronger Attack 2 opening. |
| thorn_guard | Shield | Existing | P VIT; S DEF; AGI - | Built-in guard package; counter identity reserved | SHOP, CHEST, CLEAR | Absorb pressure and choose when to answer. |
| parry_buckler | Shield | Existing | P DEF; S VIT | Light guard package; recovery multiplier reserved | SHOP, CHEST, CLEAR | Trade durability for a lighter, more responsive block rhythm. |
| mirror_ward | Shield | New | P MND; S DEF | Elemental Ward WATER, future, EPIC+ | CHEST, CLEAR, BOSS | Protect against Water pressure after the shared matchup step. |
| frostwall | Shield | New | P DEF; S VIT; AGI - | Elemental Ward ICE, future, EPIC+ | CHEST, CLEAR, BOSS | A stable wall against Ice pressure with a clear mobility cost. |
| bangle | Accessory | Existing | P STR; S VIT, AGI | Stat snapshot only | STARTER, SHOP, CHEST, CLEAR | A flexible bracelet with small benefits in several lanes. |
| duelist_seal | Accessory | Existing | P STR; S AGI - | Duelist Focus transmutation, EPIC+ | SHOP, CHEST, CLEAR | Commit to a locked target for stronger STR scaling and accept the off-target tradeoff. |
| warrior_charm | Accessory | Existing | P STR; S DEF; AGI - | Stat snapshot only | SHOP, CHEST, CLEAR | Value force and resilience over speed. |
| swift_boots | Accessory | Existing | P AGI | Stat snapshot only; move profile reserved | SHOP, CHEST, CLEAR | Make movement, running, and roll recovery the build’s center. |
| chroma_talisman | Accessory | Existing | P INT; S MND | Chroma presentation/utility only; no multiplier | SHOP, CHEST, CLEAR | Support the magic side of Chroma without granting free Souls or changing aspect. |
| soul_locket | Accessory | New | P MND; S VIT | Pickup radius, future, COMMON+ | SHOP, CHEST, CLEAR | Collect Souls and Chroma more comfortably without increasing their value. |
| runebound_knot | Accessory | New | P AGI; S INT | Combo window, future, RARE+ | CHEST, CLEAR, BOSS | Give sustained contact more room through the visible combo timer, not direct Style. |
| elemental_knot | Accessory | New | P INT; S MND | Imbue Resonance keyed to active aspect, future, RARE+ | CHEST, CLEAR, BOSS | Reward matching the active aspect without overriding it. |

The matrix intentionally contains no direct Souls, gold, global drop-rate, or
Style multiplier. It also keeps the two zero-power starters explicit, so a
new six-slot profile can show the complete layout without receiving six free
power packages.
