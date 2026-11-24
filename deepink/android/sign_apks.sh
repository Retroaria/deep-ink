#!/usr/bin/env bash
# Deep Ink: signs the built APKs with the project key, so they can be
# installed and updated in place. Usage: sign_apks.sh [apk...]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
KEYSTORE="${DEEPINK_KEYSTORE:-${ROOT}/deepink/android/deepink.keystore}"
PASS="${DEEPINK_KEYSTORE_PASS:-deepink}"

apks=("$@")
if [[ ${#apks[@]} -eq 0 ]]; then
    shopt -s nullglob
    apks=("${ROOT}"/koreader-android-*.apk)
fi
[[ ${#apks[@]} -gt 0 ]] || { echo "Deep Ink: no APK to sign"; exit 0; }

apksigner="$(command -v apksigner || true)"
if [[ -z "${apksigner}" ]]; then
    for sdk in "${ANDROID_SDK_ROOT:-}" "${ANDROID_HOME:-}" /opt/android-sdk* "${HOME}"/android-sdk* "${HOME}"/.local/share/android-sdk*; do
        [[ -n "${sdk}" && -d "${sdk}/build-tools" ]] || continue
        apksigner="$(find "${sdk}/build-tools" -name apksigner -type f | sort -V | tail -n1)"
        [[ -n "${apksigner}" ]] && break
    done
fi
if [[ -z "${apksigner}" ]]; then
    apksigner="$(find / -name apksigner -type f -path '*build-tools*' 2>/dev/null | sort -V | tail -n1 || true)"
fi
[[ -n "${apksigner}" ]] || { echo "Deep Ink: apksigner not found!" >&2; exit 1; }
echo "Deep Ink: using ${apksigner}"

for apk in "${apks[@]}"; do
    out="${apk%.apk}"
    out="${out/koreader-android/deep-ink-android}-signed.apk"
    "${apksigner}" sign --ks "${KEYSTORE}" --ks-pass "pass:${PASS}" --key-pass "pass:${PASS}" \
        --ks-key-alias deepink --out "${out}" "${apk}"
    "${apksigner}" verify --print-certs "${out}" | head -n 3
    echo "Deep Ink: signed ${out}"
done
