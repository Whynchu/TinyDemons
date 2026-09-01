"""Shared typed errors for the sfx lab."""

from __future__ import annotations


class SfxLabError(Exception):
    """Base error for the sfx lab."""


class RecipeValidationError(SfxLabError):
    """A recipe failed schema validation."""


class BackendUnavailableError(SfxLabError):
    """The requested analysis backend is not available."""


class WorkspaceConflictError(SfxLabError):
    """A workspace path already exists and overwrite was not requested."""