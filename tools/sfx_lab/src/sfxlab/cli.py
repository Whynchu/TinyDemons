"""CLI entry point for the sfx lab (spec section 12)."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="sfxlab")
    subparsers = parser.add_subparsers(dest="command", required=True)

    analyze = subparsers.add_parser("analyze", help="analyze a reference WAV into a workspace")
    analyze.add_argument("--input", required=True)
    analyze.add_argument("--output-workspace", default=None)
    analyze.add_argument("--overwrite", action="store_true")
    analyze.add_argument("--json", action="store_true")

    validate = subparsers.add_parser("validate", help="validate a recipe JSON file")
    validate.add_argument("--recipe", required=True)

    mutate = subparsers.add_parser("mutate", help="apply a mutation plan to a recipe")
    mutate.add_argument("--recipe", required=True)
    mutate.add_argument("--plan", required=True)
    mutate.add_argument("--dry-run", action="store_true", help="validate and report without rendering")
    mutate.add_argument("--output", default=None, help="output mutated recipe JSON path")
    mutate.add_argument("--output-wav", default=None, help="output rendered variant WAV path")

    return parser


def main() -> None:
    parser = _build_parser()
    args = parser.parse_args()
    if args.command == "analyze":
        from .analysis.pipeline import run_analysis

        result = run_analysis(args.input, output_workspace=args.output_workspace, overwrite=args.overwrite)
        if args.json:
            print(json.dumps(result, indent=2, sort_keys=True))
        else:
            print(f"workspace={result['workspace']}")
            print(f"tracks={result['track_count']} components={result['component_count']} duration_s={result['duration_s']:.4f}")
            print(f"recipe_id={result['recipe_id']}")
        return
    if args.command == "validate":
        from .recipe.validate_io import load_recipe

        recipe = load_recipe(args.recipe)
        print(f"recipe {recipe.recipe_id} valid (schema {recipe.schema_version})")
        return
    if args.command == "mutate":
        from .mutate.operations import apply_mutation_plan, mutation_distance
        from .mutate.plans import load_plan
        from .recipe.validate_io import dump_recipe, load_recipe
        from .recipe.models import validate_recipe
        from .synthesis.renderer import render_recipe

        recipe = load_recipe(args.recipe)
        plan = load_plan(args.plan)
        mutated = apply_mutation_plan(recipe, plan)
        validate_recipe(mutated)
        distance = mutation_distance(recipe, mutated)
        if args.dry_run:
            print(json.dumps({"dry_run": True, "recipe_id": mutated.recipe_id, "operations": len(mutated.operations), "distance": distance}, indent=2, sort_keys=True))
            return
        if args.output:
            Path(args.output).parent.mkdir(parents=True, exist_ok=True)
            Path(args.output).write_text(json.dumps(dump_recipe(mutated), indent=2, sort_keys=True), encoding="utf-8")
            print(f"wrote recipe -> {args.output}")
        if args.output_wav:
            render = render_recipe(mutated)
            from .audio.io import write_wav

            write_wav(args.output_wav, render["mix"], mutated.sample_rate_hz)
            print(f"wrote wav -> {args.output_wav}")
        print(f"mutated recipe {mutated.recipe_id} (parent {mutated.parent_recipe_id}) distance={distance}")
        return
    parser.print_help()
    sys.exit(2)


if __name__ == "__main__":
    main()