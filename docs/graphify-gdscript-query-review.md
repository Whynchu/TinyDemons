# Graphify GDScript query review

Status: all six Tiny Demons map queries were checked against source. The
seventh, which concerns Graphify's own incremental CLI, was checked in the
separate fork test suite because the fork is excluded from this map.

## Refreshed target graph

- 21,073 nodes, 46,226 edges, 727 communities.
- 1,016 unique source paths; zero paths from graphify-godot/.
- graph.html and GRAPH_REPORT.md were regenerated in the ignored local map at
  graphify-godot/.tools/tiny-demons-map/. The HTML contains all nine source
  groups: Docs, Tests, Scripts, Scenes, Resources, Tools, Addons, Config, Other.
- The root .gitignore rule /graphify-godot/ was confirmed with git check-ignore.

## Vocabulary expansions used

These terms came from the refreshed graph's node-label vocabulary before the
scoped queries ran:

1. slime actor damage apply attack hit skeleton inheritance
2. enemy geometry profile hitbox polygon body factory collision actor definition runtime
3. enemy definition body hitbox polygon read gameplay resource
4. hub screen actions set page callable pressed button connect handler
5. main scene gameplay bootstrap initialize autoload script
6. test actor geometry smoke dynamic call manifest registered
7. incremental godot uid rename delete diagnostic parity autoload scene cli test

## Reviewed questions

### 1. Which methods call a slime damage handler, including inheritance?

The graph links CombatRuntimeController.damage_slime_with_number to
SlimeActor.damage_actor at combat_runtime_controller.gd:128. It links
SlimeRuntimeController.apply_slime_attack_hit to SlimeActor.apply_attack_hit at
slime_runtime_controller.gd:866; the skeleton projectile path calls the same
handler with ranged_hit enabled at line 948. The inheritance edge links
SkeletonActor to SlimeActor at skeleton_actor.gd:2.

This shows source relationships and inheritance, not how often runtime paths
execute.

### 2. Which consumers use authored collision geometry?

The graph connects EnemyFactory.geometry_profile to type_id and the family
profile selector, and connects EnemyFactory.apply_geometry to geometry_profile.
It also shows the family geometry resources for skeleton and slime carrying the
profile fields. Source confirms apply_geometry reads body_hitbox_polygon from
that selected profile and applies it to the actor's body hitbox. ActorGeometry,
SlimeGeometryQueries, room placement, combat and debug drawing then consume the
resulting actor geometry.

Resource loading and serialized assignments alone do not establish runtime
authority. See enemy_factory.gd:156-207 and enemy_geometry_profile.gd:10-50.

### 3. Is an authored enemy field assigned but without a gameplay read?

EnemyDefinition.body_hitbox_polygon is exported, assigned in enemy definition
resources, validated and serialized. The graph query found the validation read
but did not surface a gameplay read from that definition-side field. Runtime
geometry instead reads the matching field from the family EnemyGeometryProfile
selected by type_id. The authoring workbench also edits the family profile.

Treat the definition-side value as a duplicated authoring surface that needs a
clear ownership decision, not as proof that collision hitboxes are unused.
Static absence does not establish runtime dead data. See
enemy_definition.gd:50-220, enemy_factory.gd:156-207 and
enemy_preview_workbench.gd:1438-1444.

### 4. Which Callable connects the UI action to its handler?

Source confirms HubScreenActions.from_gameplay_root creates set_page as a
Callable to root._set_hub_page at hub_screen_actions.gd:43-50. The command-shell
presenter binds the page value and connects it to page_button.pressed at
hub_command_shell_presenter.gd:52. The graph links HubScreenActions to the
presenter, but its signal-connection query did not recover this specific
Callable-to-pressed edge.

That missing callback relationship is a concrete G5 extraction gap. Do not
infer arbitrary callbacks from matching method names.

### 5. What owns the main-scene entry path?

The graph links project.godot's application/run/main_scene setting to Main and
links the Main scene's script attachment to scripts/runtime/controllers/gameplay.gd.
Source confirms the root creates GameplayBootstrap at runtime and calls
initialize(self, preview_session) in gameplay.gd:34. MCPRuntimeServer is
configured as an autoload in project.godot:21; no main-scene source call to
that autoload was found.

The bootstrap is runtime-created, not a serialized scene child. The map's
project and attachment edges do not by themselves establish dynamic child
creation behavior.

### 6. Which geometry tests reference the owner, and what remains dynamic?

The graph links actor_geometry_smoke to ActorGeometry and links the pure smoke
to tests/manifest.csv at line 57. It also shows runtime ActorGeometry
consumers. Source review found tests/actor_geometry_smoke.gd,
tests/actor_geometry_scene_smoke.gd, tests/boss_geometry_scene_smoke.gd and
tests/enemy_room_entrance_scene_smoke.gd. The scene tests retain dynamic
gameplay.call wrappers such as _slime_body_polygon and _collision_rect.

A graph reference describes a source dependency, not successful execution or
behavioral coverage. The graph shows the manifest registration; the test runner
and its results establish execution.

### 7. Do rename and delete updates remove old edges and report new gaps?

This question belongs to graphify-godot, so it is intentionally absent from the
Tiny Demons map. The fork's
test_incremental_godot_scene_autoload_uid_rename_and_delete_match_full_build
passed in both raw and clustered modes. It compares incremental output with a
forced full build after autoload replacement, inherited scene attachment
override, path/UID rename and target deletion, and checks the new unresolved
reference diagnostics.

This is bounded fixture coverage, not proof of every editor-time mutation or
engine-specific scene override.

## Remaining extraction gaps shown by this review

- G4: the graph can find the duplicated definition field and family resources,
  but source review is still needed to establish which profile controls runtime
  geometry. Do not label fields dead from missing edges alone.
- G5: the specific set_page Callable and bound Button.pressed connection are not
  represented as a complete graph relationship.
- G6/G7: the main-scene attachment is represented, while runtime-created
  bootstrap wiring and dynamic gameplay.call test wrappers still require source
  context or explicit boundary diagnostics.
- G1-G7 remain partial according to the fork support matrix. This review proves
  useful bounded paths; it does not declare complete Godot language support.
