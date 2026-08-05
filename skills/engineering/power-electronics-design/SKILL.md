---
name: power-electronics-design
description: "Use for power electronics: GaN drivers, dead time."
---

# Power Electronics Design (GaN / PWM / Dead Time / Transformer)

## When to use
- Half-bridge / full-bridge GaN or SiC drive, gate driver ICs (e.g. LMG1210), dead time, shoot-through
- PWM-synthesized sine / class-D style output with LC filtering; harmonic complaints
- Transformer design or failure (core saturation, burned supplies) in bridge topologies
- Transducer / capacitive-load matching (underwater acoustic, ultrasonic, piezo)
- Any 水声板 (underwater acoustic transducer board) discussion — see references/water-acoustic-transducer-board.md for project state

## Core principles

### 1. Dead time is mandatory — zero dead time is gambling
- Drive-level complementarity ≠ device-level state. GaN turns ON faster than it turns OFF; with perfectly aligned edges the on-device starts conducting before the off-device fully blocks → transient shoot-through every cycle.
- INVISIBLE on voltage waveforms (drive levels still look complementary). Verify via bus-current spikes and device temperature instead.
- Dead time's waveform signature: a "both-low" notch between edges. User says "edges meet exactly, never both high or both low" → that IS the zero-dead-time signature. Warn, don't reassure.
- Size it from driver propagation-delay mismatch + device off-delay. Start conservative (20-50ns), tighten by watching temperature/efficiency.

### 2. Dead-time cost and compensation
- Fixed time per edge → duty loss ≈ 2·td·f_carrier. At td=50ns, f_carrier=1MHz ≈ 5-10% duty loss → baseband amplitude drop; acoustic power ∝ V² so ~10% power loss.
- Dead-time effect: during dead time output is clamped by freewheel diodes following load-current direction → error is a square wave at signal frequency → odd harmonics (3rd often in-band, e.g. 90kHz from 30kHz drive).
- Compensation: pre-boost comparator/counter values by the fixed loss (constant for fixed-frequency drive → trivial), keep DTR=DTF symmetric, use minimum safe td.

### 3. Driver IC modes (LMG1210 example)
- Single-input PWM mode: IC generates complementary outputs and CAN insert dead time (DT pin, resistor-programmed).
- Dual-input (HI/LI complementary) mode: IC passes timing straight through — NO dead time insertion. Dead time must come entirely from the MCU waveform.
- Check datasheet propagation-delay mismatch (HI vs LI path); dead time must cover it.

### 4. MCU-side dead time: STM32 HRTIM
- Use ONE timer unit's TA/TB output pair + the unit's dead-time generator (DTGE enable; DTR/DTF registers; 184ps resolution on G4).
- Do NOT hand-invert two independent channels — no dead-time mechanism, edge alignment is luck.
- BRK (brake input) tied to overcurrent/UVLO = the only hardware interlock when MCU generates both edges. PWM pins must be safe level at power-up (HRTIM outputs disabled by default).
- Dead time can be asymmetric (longer on turn-off edge) to compensate device threshold differences.

### 5. PWM harmonics: fix at source, not with more filters
- Two distinct problems:
  - Carrier residue (1MHz etc.): filterable with LC, but 2nd order = only 40dB/decade — cannot pass 10-120kHz and kill 1MHz simultaneously (100:1 span). Need 3rd/4th order or higher carrier.
  - In-band harmonics (60/90/120kHz from 30kHz drive): CANNOT be filtered without killing the band. They come from modulation nonlinearity.
- Rule-sampled PWM quantization: levels per signal cycle = f_carrier / f_signal. ~33 levels (1MHz/30kHz) is coarse → harmonic floor. Fixes: raise carrier (GaN handles 3-4MHz), high-resolution timer (HRTIM 184ps ≈ 5434 levels at 1MHz), symmetric dead time, matched edges.
- Alternative architecture: closed-loop class-D audio driver ICs (e.g. IRS2092) give ~0.01% THD — industry standard for ultrasonic transducers.

### 6. Transformers in PWM bridge drives
- Core saturation symptoms: excessive heat + ringing; spikes back-feed into the supply and kill DC-DC converters (observed: 12V→5V buck killed by saturating transformer).
- Volt-second imbalance (asymmetric duty/dead time, unequal on-voltages) walks the core into saturation in a few cycles — classic PWM-drive trap, not a "bad transformer". Fix: primary series DC-blocking cap (size for lowest signal frequency), strict symmetric dead time.
- Faraday sizing: N = V / (4.44·f·Bmax·Ae) for sine; Bmax ≈ 1/3 of saturation. Design for YOUR frequency/power/load — never reuse off-the-shelf transformers designed for other frequencies.
- RC snubber across primary/secondary for leakage ringing.
- Turns ratio ≠ voltage ratio: verify datasheets (2:3 turns = 1.5x voltage, not 3x).

### 7. Transducer / capacitive load matching
- Piezo transducers are capacitive; series/parallel inductor cancels reactance at resonance → bridge sees near-resistive load.
- Matching network + transformer leakage naturally form a bandpass — design it to also reject harmonics (free filter stage).
- Low-frequency response needs high drive voltage (acoustic power ∝ V²); TVR rolls off steeply below resonance — that's physics, not a fault.

### 8. Scope verification
- For a 10-120kHz band + 1MHz carrier, a 200MHz scope is plenty. Check dead time at 20-50ns/div; two-channel AND (or measure high-time overlap) for shoot-through; FFT at load terminals distinguishes front-end vs load nonlinearity.
- Ground spring (not long ground lead) on probes — most "ringing" artifacts are probe ground-loop.
- Bus-current waveform: spike per switching cycle = shoot-through.

## Workflow when asked a design question
1. Quantify first: compute duty loss, harmonic amplitudes, filter attenuation before recommending architecture.
2. Separate filterable (carrier) from non-filterable (in-band) harmonics; source fixes beat filter stacks.
3. Dead time is a bottom line, not an option — then minimize + compensate.
4. State the verification experiment (what to measure, with what) so the user can confirm.

## Pitfalls
- Reassuring a user whose edges "meet exactly" — that is the zero-dead-time signature; warn instead.
- Assuming a driver IC inserts dead time in dual-input mode (LMG1210 does not).
- "2nd-order LC should be enough" for 100:1 frequency spans — it isn't.
- Reusing transformers rated for other frequencies/powers.
- Treating 5.44GHz HRTIM resolution as a PCB clock — it's internal digital resolution (184ps), no special layout constraints.

## References
- references/water-acoustic-transducer-board.md — 水声板 project state: chain, V1 findings, V2 plan, open parameters.
