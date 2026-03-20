#!/bin/bash
# run_all.sh — Run all 20 Tamarin configurations in parallel, compare against expected results.
# Usage: Run inside WSL or Linux with tamarin-prover on PATH.
#   ./run_all.sh [-j N]    (default: number of CPU cores)
set -uo pipefail

export PATH="/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

JOBS=$(nproc 2>/dev/null || echo 4)
while [[ $# -gt 0 ]]; do
  case $1 in
    -j) JOBS="$2"; shift 2 ;;
    *)  echo "Usage: $0 [-j N]"; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEORY="$SCRIPT_DIR/lemmas.spthy"
RESULTS="$SCRIPT_DIR/results"
mkdir -p "$RESULTS"

# Lemma names (column order)
LEMMAS=(no_bifurcation non_repudiation faithful_history authorized_progression instance_isolation value_secrecy)
SHORT=(G1 G2 G3 G4 G7 G6a)

# ── Configuration definitions ──
# Format: "name|flags|G1|G2|G3|G4|G7|G6a"
#   V = expected verified, F = expected falsified
CONFIGS=(
  "PiLC_PA|-D=PROFILE_LC -D=ADV_PA|F|V|F|V|F|F"
  "PiLC_RA|-D=PROFILE_LC -D=ADV_RA|F|V|F|V|F|F"
  "PiLC_SA|-D=PROFILE_LC -D=ADV_SA|V|V|F|V|F|F"
  "PiLC_SB|-D=PROFILE_LC -D=ADV_SB|V|V|F|V|F|F"
  "PiSC_PA|-D=PROFILE_SC -D=ADV_PA|V|V|V|V|V|F"
  "PiSC_RA|-D=PROFILE_SC -D=ADV_RA|V|V|V|V|V|F"
  "PiSC_SA|-D=PROFILE_SC -D=ADV_SA|V|V|V|V|V|F"
  "PiSC_SB|-D=PROFILE_SC -D=ADV_SB|V|V|V|V|V|F"
  "PiVC_PA_atomic|-D=PROFILE_VC -D=ADV_PA -D=ATOMIC_VDR|V|V|F|V|V|V"
  "PiVC_RA_atomic|-D=PROFILE_VC -D=ADV_RA -D=ATOMIC_VDR|V|V|F|V|V|V"
  "PiVC_SA_atomic|-D=PROFILE_VC -D=ADV_SA -D=ATOMIC_VDR|V|V|F|V|V|V"
  "PiVC_SB_atomic|-D=PROFILE_VC -D=ADV_SB -D=ATOMIC_VDR|V|V|F|V|V|V"
  "PiVC_PA_nonatomic|-D=PROFILE_VC -D=ADV_PA|F|V|F|V|V|V"
  "PiVC_RA_nonatomic|-D=PROFILE_VC -D=ADV_RA|F|V|F|V|V|V"
  "PiVC_SA_nonatomic|-D=PROFILE_VC -D=ADV_SA|V|V|F|V|V|V"
  "PiVC_SB_nonatomic|-D=PROFILE_VC -D=ADV_SB|V|V|F|V|V|V"
  "PiDY_PA|-D=PROFILE_DY -D=ADV_PA|F|F|F|F|F|F"
  "PiDY_RA|-D=PROFILE_DY -D=ADV_RA|F|F|F|F|F|F"
  "PiDY_SA|-D=PROFILE_DY -D=ADV_SA|F|F|F|F|F|F"
  "PiDY_SB|-D=PROFILE_DY -D=ADV_SB|F|F|F|F|F|F"
)

# ── Run all configurations in parallel ──
total=${#CONFIGS[@]}
echo "Running $total configurations with $JOBS parallel jobs..."
echo ""

run_one() {
  local entry="$1"
  IFS='|' read -r name flags _ <<< "$entry"
  local logfile="$RESULTS/${name}.log"
  # shellcheck disable=SC2086
  tamarin-prover --prove $flags "$THEORY" > "$logfile" 2>&1
  echo "  done: $name"
}
export -f run_one
export RESULTS THEORY

printf '%s\n' "${CONFIGS[@]}" | xargs -P "$JOBS" -I {} bash -c 'run_one "$@"' _ {}

echo ""
echo "All runs complete. Parsing results..."

# ── Parse results from logs ──
declare -A ACTUAL

for entry in "${CONFIGS[@]}"; do
  IFS='|' read -r name _ <<< "$entry"
  logfile="$RESULTS/${name}.log"

  for lem in "${LEMMAS[@]}"; do
    if grep -q "${lem}.*verified" "$logfile" && ! grep -q "${lem}.*falsified" "$logfile"; then
      ACTUAL["${name},${lem}"]="V"
    elif grep -q "${lem}.*falsified" "$logfile"; then
      ACTUAL["${name},${lem}"]="F"
    else
      ACTUAL["${name},${lem}"]="?"
    fi
  done
done

# ── Table 1: Results ──
echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo "  TABLE 1: Verification Results  (V=verified, F=falsified, ?=unknown)"
echo "═══════════════════════════════════════════════════════════════════════"
printf "%-25s" "Configuration"
for s in "${SHORT[@]}"; do printf " %4s" "$s"; done
echo ""
printf "%-25s" "─────────────────────────"
for _ in "${SHORT[@]}"; do printf " %4s" "────"; done
echo ""

for entry in "${CONFIGS[@]}"; do
  IFS='|' read -r name _ <<< "$entry"
  printf "%-25s" "$name"
  for lem in "${LEMMAS[@]}"; do
    val="${ACTUAL[${name},${lem}]}"
    printf " %4s" "$val"
  done
  echo ""
done

# ── Table 2: Expected vs Actual ──
echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo "  TABLE 2: Expected vs Actual  (✓=match, ✗=MISMATCH)"
echo "═══════════════════════════════════════════════════════════════════════"
printf "%-25s" "Configuration"
for s in "${SHORT[@]}"; do printf " %4s" "$s"; done
echo ""
printf "%-25s" "─────────────────────────"
for _ in "${SHORT[@]}"; do printf " %4s" "────"; done
echo ""

mismatches=0
for entry in "${CONFIGS[@]}"; do
  IFS='|' read -r name flags exp_g1 exp_g2 exp_g3 exp_g4 exp_g7 exp_g6a <<< "$entry"
  expected=("$exp_g1" "$exp_g2" "$exp_g3" "$exp_g4" "$exp_g7" "$exp_g6a")

  printf "%-25s" "$name"
  for i in "${!LEMMAS[@]}"; do
    lem="${LEMMAS[$i]}"
    val="${ACTUAL[${name},${lem}]}"
    exp="${expected[$i]}"
    if [[ "$val" == "$exp" ]]; then
      printf "    ✓"
    else
      printf "   ✗%s" "$val"
      mismatches=$((mismatches + 1))
    fi
  done
  echo ""
done

echo ""
if [[ $mismatches -eq 0 ]]; then
  echo "All results match expectations."
else
  echo "WARNING: $mismatches mismatch(es) found!"
fi
echo "Logs saved to: $RESULTS/"
