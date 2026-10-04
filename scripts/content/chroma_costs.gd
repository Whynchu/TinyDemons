extends RefCounted

const BASIC_SPELL_FRACTION := 0.20
const SWORD_BEAM_FRACTION := 0.60
const IMBUE_FRACTION := 1.0


static func amount_for_fraction(maximum_chroma: int, fraction: float) -> int:
	if maximum_chroma <= 0:
		return 0
	return clampi(ceili(float(maximum_chroma) * clampf(fraction, 0.0, 1.0)), 1, maximum_chroma)
