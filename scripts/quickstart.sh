#!/usr/bin/env bash
# Build MedTagger (if needed) and run the rule-based IE pipeline on sample notes.
#
# Usage:
#   bash scripts/quickstart.sh                       # build + run PASC/COVID demo
#   bash scripts/quickstart.sh IN_DIR OUT_DIR RULE_DIR [SECTION_FILE]
#   bash scripts/quickstart.sh --rebuild ...         # force a fresh Maven build
#   bash scripts/quickstart.sh --dist                # also create MedTagger.zip with ant
#
# Run scripts/setup_mac_env.sh once first.
set -euo pipefail

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

REBUILD=0; DIST=0; ARGS=()
for a in "$@"; do
  case "$a" in
    --rebuild) REBUILD=1 ;;
    --dist)    DIST=1 ;;
    -h|--help) sed -n 2,10p "$0"; exit 0 ;;
    *)         ARGS+=("$a") ;;
  esac
done

# --- 1. Environment ---------------------------------------------------------
# shellcheck disable=SC1090
[[ -f "$HOME/.medtagger/env.sh" ]] && source "$HOME/.medtagger/env.sh"
for t in java mvn; do
  command -v "$t" >/dev/null 2>&1 || die "'$t' not found. Run: bash scripts/setup_mac_env.sh"
done

# --- 2. Build ---------------------------------------------------------------
JAR="$REPO/target/medtagger.jar"
if [[ $REBUILD -eq 1 || ! -f "$JAR" ]]; then
  [[ -n "${SECRET_ACTOR:-}" && -n "${SECRET_TOKEN:-}" ]] \
    || die "GitHub credentials missing (needed for the Backbone dependency). Rerun scripts/setup_mac_env.sh"
  say "Building with Maven (first run downloads dependencies, a few minutes)..."
  mvn -q -s settings.xml -DskipTests clean package \
    || die "Maven build failed. A 401 error means the GitHub token is wrong or lacks read:packages."
fi
[[ -f "$JAR" ]] || die "Build finished but $JAR is missing."
say "Jar: $JAR"

if [[ $DIST -eq 1 ]]; then
  command -v ant >/dev/null 2>&1 || die "'ant' not found. Run: bash scripts/setup_mac_env.sh"
  say "Packaging MedTagger.zip and MedTaggerForBackbone.zip with ant..."
  ant -q dist
fi

# --- 3. Run -----------------------------------------------------------------
RES="$REPO/src/main/resources/medtaggerieresources"
IN="${ARGS[0]:-$REPO/testdata/medtaggerietest/pasc/input}"
OUT="${ARGS[1]:-$REPO/quickstart_output}"
RULES="${ARGS[2]:-$RES/pasc}"
SECTION="${ARGS[3]:-$RES/pad/Radiology_Section}"

[[ -d "$IN" ]]    || die "Input folder not found: $IN"
[[ -d "$RULES" ]] || die "Rule folder not found: $RULES"
mkdir -p "$OUT"

say "Running MedTagger IE"
echo "    input : $IN"
echo "    output: $OUT"
echo "    rules : $RULES"
java -Xmx4g -cp "$JAR" org.ohnlp.medtagger.fit.Main "$IN" "$OUT" "$RULES" "$SECTION"

echo
say "Output files:"
ls -l "$OUT"

echo
if command -v python3 >/dev/null 2>&1; then
  say "Found concepts (also saved as $OUT/results.csv):"
  python3 "$REPO/scripts/xml_to_table.py" "$OUT"
else
  FIRST="$(find "$OUT" -name '*.xml' -type f | head -1)"
  [[ -n "$FIRST" ]] && { say "Preview of $(basename "$FIRST"):"; head -c 2000 "$FIRST"; echo; }
fi
