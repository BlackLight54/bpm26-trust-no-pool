# Supplementary Artifact: Tamarin Prover Models

![DOI](https://zenodo.org/badge/1187315711.svg)](https://doi.org/10.5281/zenodo.20273971)
This repository contains the Tamarin prover theories and automation scripts for the formal verification results reported in the paper. All 20 configurations (4 platform enforcement profiles x 4 adversary designations, plus the honest baseline) can be reproduced from this artifact.

## Repository Structure

```
.
├── lemmas.spthy              # Main theory file (single entry point)
├── common/
│   ├── modelSetup.spthy      # Collaboration topology and process instantiation
│   ├── poolPA.spthy          # Honest behavior: Procurement Authority
│   ├── poolRA.spthy          # Honest behavior: Regulatory Authority
│   ├── poolSA.spthy          # Honest behavior: Supplier A
│   └── poolSB.spthy          # Honest behavior: Supplier B
├── profiles/
│   ├── Pi0/                  # Secure channel baseline (all honest)
│   ├── PiLC/                 # Loose coupling profile
│   ├── PiSC/                 # Smart contract profile
│   ├── PiVC/                 # VC-based profile
│   └── PiDY/                 # Full Dolev-Yao profile
├── run_all.sh                # Automated verification script
└── results/                  # Pre-computed verification logs
```

Each profile directory contains `delivery.spthy` (message delivery rules) and, where applicable, `adversary.spthy` (adversary capabilities).

## Prerequisites

- **Tamarin prover** (version 1.8.0 or later): [https://tamarin-prover.com/](https://tamarin-prover.com/)
  - Tamarin requires Maude (>= 2.7.1) and Haskell Stack; both are installed automatically if you follow the official installation instructions.
- **Bash 4+** (for the automated script; available by default on Linux and macOS)
- **Linux, macOS, or WSL** (Windows Subsystem for Linux)

No other dependencies are required. The script uses only standard Unix utilities (`xargs`, `grep`, `nproc`).

## Reproducing the Results

### Automated (recommended)

The `run_all.sh` script runs all 20 configurations in parallel, collects the results, and compares them against the expected outcomes reported in the paper.

```bash
chmod +x run_all.sh
./run_all.sh
```

By default, the script uses all available CPU cores. To limit parallelism:

```bash
./run_all.sh -j 4
```

The script produces two summary tables on completion:

1. **Verification Results** — the proved/falsified status of each security property (G1, G2, G3, G4, G6a, G7) under each configuration.
2. **Expected vs. Actual** — a comparison against the expected results from the paper, flagging any mismatches.

Verification logs are saved to `results/`.

### Manual (individual configurations)

To verify a single configuration, invoke Tamarin directly with the appropriate preprocessor flags:

```bash
# Example: Loose coupling profile, adversarial Procurement Authority
tamarin-prover --prove -D=PROFILE_LC -D=ADV_PA lemmas.spthy

# Example: VC-based profile with atomic VDR, adversarial Supplier A
tamarin-prover --prove -D=PROFILE_VC -D=ADV_SA -D=ATOMIC_VDR lemmas.spthy

# Example: Honest baseline (no flags)
tamarin-prover --prove lemmas.spthy
```

Available preprocessor flags:

| Flag | Description |
|------|-------------|
| `PROFILE_LC` | Loose coupling (authenticated channels) |
| `PROFILE_SC` | Smart contract orchestration |
| `PROFILE_VC` | VC-based self-orchestration |
| `PROFILE_DY` | Full Dolev-Yao network adversary |
| *(none)* | Secure channel baseline (all honest) |
| `ADV_PA` | Procurement Authority is adversarial |
| `ADV_RA` | Regulatory Authority is adversarial |
| `ADV_SA` | Supplier A is adversarial |
| `ADV_SB` | Supplier B is adversarial |
| `ATOMIC_VDR` | Atomic VDR semantics (only with `PROFILE_VC`) |

## Estimated Runtime

Total verification time depends on hardware. On a machine with 12 cores x86 and 96 GB RAM, the full suite completes under 2 minutes. Individual configurations typically terminate within 30 seconds.
