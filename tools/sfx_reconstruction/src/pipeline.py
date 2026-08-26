"""CLI entry point for the reconstruction pipeline."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .render import render_json
from .recipe import validate_recipe
from .analyze import analyze_wav
from .fit import fit_to_json
from .click_workbench import analyze_click, fit_click_recipe
from .forensic import analyze_forensic, fit_forensic_recipe
from .metric import compare_to_json
from .optimize import optimize
from .sequence import fit_sequence_recipe
from .contract import validate_analysis_report


def main() -> None:
    parser = argparse.ArgumentParser(prog="sfx-reconstruction")
    subparsers = parser.add_subparsers(dest="command", required=True)
    render_parser = subparsers.add_parser("render")
    render_parser.add_argument("--recipe", required=True)
    render_parser.add_argument("--output", required=True)
    analyze_parser = subparsers.add_parser("analyze")
    analyze_parser.add_argument("--input", required=True)
    analyze_parser.add_argument("--output", required=True)
    fit_parser = subparsers.add_parser("fit")
    fit_parser.add_argument("--input", required=True)
    fit_parser.add_argument("--output", required=True)
    click_parser = subparsers.add_parser("click")
    click_parser.add_argument("--input", required=True)
    click_parser.add_argument("--analysis-output", required=True)
    click_parser.add_argument("--recipe-output", required=True)
    forensic_parser = subparsers.add_parser("forensic")
    forensic_parser.add_argument("--input", required=True)
    forensic_parser.add_argument("--output", required=True)
    forensic_fit_parser = subparsers.add_parser("forensic-fit")
    forensic_fit_parser.add_argument("--input", required=True)
    forensic_fit_parser.add_argument("--analysis", required=True)
    forensic_fit_parser.add_argument("--output", required=True)
    score_parser = subparsers.add_parser("score")
    score_parser.add_argument("--reference", required=True)
    score_parser.add_argument("--candidate", required=True)
    score_parser.add_argument("--output", required=True)
    optimize_parser = subparsers.add_parser("optimize")
    optimize_parser.add_argument("--recipe", required=True)
    optimize_parser.add_argument("--reference", required=True)
    optimize_parser.add_argument("--output-recipe", required=True)
    optimize_parser.add_argument("--output-wav", required=True)
    optimize_parser.add_argument("--rounds", type=int, default=4)
    sequence_parser = subparsers.add_parser("sequence")
    sequence_parser.add_argument("--recipe", required=True)
    sequence_parser.add_argument("--analysis", required=True)
    sequence_parser.add_argument("--output", required=True)
    args = parser.parse_args()
    if args.command == "render":
        validate_recipe(json.loads(Path(args.recipe).read_text(encoding="utf-8")))
        render_json(Path(args.recipe), Path(args.output))
    elif args.command == "analyze":
        Path(args.output).parent.mkdir(parents=True, exist_ok=True)
        report = analyze_wav(args.input)
        validate_analysis_report(report)
        Path(args.output).write_text(json.dumps(report, indent=2), encoding="utf-8")
    elif args.command == "fit":
        fit_to_json(args.input, args.output)
    elif args.command == "click":
        analysis = analyze_click(args.input)
        Path(args.analysis_output).parent.mkdir(parents=True, exist_ok=True)
        Path(args.analysis_output).write_text(json.dumps(analysis, indent=2), encoding="utf-8")
        recipe = fit_click_recipe(analysis, args.input)
        Path(args.recipe_output).write_text(json.dumps(recipe, indent=2), encoding="utf-8")
    elif args.command == "forensic":
        Path(args.output).parent.mkdir(parents=True, exist_ok=True)
        Path(args.output).write_text(json.dumps(analyze_forensic(args.input), indent=2), encoding="utf-8")
    elif args.command == "forensic-fit":
        analysis = json.loads(Path(args.analysis).read_text(encoding="utf-8"))
        Path(args.output).parent.mkdir(parents=True, exist_ok=True)
        Path(args.output).write_text(json.dumps(fit_forensic_recipe(analysis, args.input), indent=2), encoding="utf-8")
    elif args.command == "score":
        Path(args.output).parent.mkdir(parents=True, exist_ok=True)
        compare_to_json(args.reference, args.candidate, args.output)
    elif args.command == "optimize":
        result = optimize(args.recipe, args.reference, args.output_recipe, args.output_wav, args.rounds)
        print(json.dumps(result, indent=2))
    elif args.command == "sequence":
        fit_sequence_recipe(args.recipe, args.analysis, args.output)


if __name__ == "__main__":
    main()
