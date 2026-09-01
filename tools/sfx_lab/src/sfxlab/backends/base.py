"""AnalysisBackend protocol boundary.

The rest of the application consumes internal typed models, never a specific
library's arrays. This keeps an AGPL backend like sms-tools replaceable behind
one narrow adapter (spec section 9).
"""

from __future__ import annotations

from typing import Protocol, runtime_checkable

import numpy as np

from ..analysis.models import SinusoidalAnalysis


@runtime_checkable
class AnalysisBackend(Protocol):
    name: str
    version: str

    def analyze(self, samples: np.ndarray, sample_rate: int) -> SinusoidalAnalysis: ...

    def synthesize(self, analysis: SinusoidalAnalysis, sample_rate: int) -> np.ndarray: ...

    def extract_residual(self, samples: np.ndarray, sample_rate: int, analysis: SinusoidalAnalysis) -> np.ndarray: ...