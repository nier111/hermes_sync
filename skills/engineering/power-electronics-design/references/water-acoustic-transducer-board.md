# 水声板 (Underwater Acoustic Transducer Board) — project state

User: 仲耀, embedded engineer. Canonical project profile lives at ~/persona/projects-profile.md — keep that file in sync with new findings, and this reference carries the technical state for future design sessions.

## System / drive chain (as of 2026-08-06)
- MCU: STM32G474RET6, HRTIM (184ps resolution ≈ "5.44GHz equivalent counting" — internal digital resolution, NOT a physical clock, no special PCB constraints from it)
- Drivers: LMG1210 ×2 (TI 100V GaN half-bridge driver). NOTE: in dual-input (HI/LI complementary) mode the IC does NOT insert dead time — DT-pin dead-time programming only works in single-input PWM mode. Dead time must come from MCU.
- GaN: INN700 series (700V class) — overkill for 12-32V rail; advisor wants lower-voltage / higher-current 100V-class parts for V2 (EPC / InnoGaN 100V), matching LMG1210's 100V rating.
- "Sine" = variable-duty PWM at 1MHz carrier + 2nd-order LC low-pass (L=15µH, C value forgotten by user) — not clean; quantization ~33 PWM cycles per 30kHz sine period. Two HRTIM channels set inverted (complementary) with NO dead-time generator → zero dead time currently (dangerous; DTG must be enabled).
- V1 supply: direct 24V/32V rail (transformer removed after incident). Lab scope: 200MHz — sufficient for 10-120kHz band + 1MHz carrier.

## V1 experimental findings (user-reported 2026-08-05)
- 24V: only ~100-120kHz band responds; low frequencies buried in noise. 32V: ~10kHz also responds → 10-120kHz coverage achieved via voltage (acoustic power ∝ V²).
- Some transducers show heavy harmonics when driven at ~30kHz (only some transducers) — suspected front-end (PWM quantization + asymmetry) more than transducer nonlinearity; still unresolved. Discriminating test: FFT at transducer terminals (clean terminals + harmonic acoustic output = transducer nonlinearity; harmonics on terminals = front-end fault).
- Transformer incident: advisor-provided off-the-shelf transformer (claimed 2:3 turns / "3x amplification" — turns ratio 2:3 is 1.5x voltage, numbers didn't add up) burned the 12V→5V DC-DC; hot + ringing = core saturation (confirmed). Removed; direct rail drive since.

## V2 plan (advisor-mandated)
- Single 12V rail: 12V to GaN driver, buck for logic; GaN bridge + step-up transformer → transducer (low-voltage bridge + step-up transformer = standard topology).
- Swap INN700 (700V) → lower-voltage, higher-current GaN (100V class).
- Enable HRTIM DTG dead time (DTR/DTF; start 20-50ns, tighten later), BRK interlock for overcurrent/UVLO, primary series DC-blocking cap (volt-second balance), RC snubber for leakage ringing, transformer designed for own frequency/power (N = V/(4.44·f·Bmax·Ae), Bmax ≈ 1/3 saturation).
- Transducer harmonic issue: treat at source (HRTIM resolution kills quantization harmonics; symmetric dead time; matched edges) — NOT by stacking LC filter stages.

## Open parameters / next steps
- LC filter C value (user to measure)
- Transducer impedance curves / datasheets (needed for transformer turns ratio ≈ 8-10 for 12V→~100Vpp, core choice, matching inductor initial value)
- Carrier frequency decision (raise to 3-4MHz vs HRTIM high-resolution at lower carrier)
- Transformer design session (user studying magnetics: reluctance, air gap, window utilization Ku, eddy currents, magnetizing current)
