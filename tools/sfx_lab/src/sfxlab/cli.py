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
    parser.print_help()
    sys.exit(2)


if __name__ == "__main__":
    main()