#!/usr/bin/env bash
# Deep Ink: adapts the upstream Android launcher (a git submodule we don't own)
# before building: application id, icons. Idempotent, safe to run twice.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LAUNCHER="${ROOT}/platform/android/luajit-launcher"
RES="${LAUNCHER}/app/src/main/res"
GRADLE="${LAUNCHER}/app/build.gradle"

[[ -f "${GRADLE}" ]] || { echo "Deep Ink: launcher not checked out, skipping"; exit 0; }

# Own application id, so Deep Ink installs side by side with KOReader.
sed -i 's/applicationId "org.koreader.launcher"/applicationId "io.github.retroaria.deepink"/' "${GRADLE}"
sed -i "/applicationIdSuffix = '.fdroid'/d" "${GRADLE}"

# Icons: main resources, plus the flavor folders that override them
# (the fdroid flavor ships its own mipmap icons).
cp -rv "${ROOT}/deepink/android/res/." "${RES}/"
for flavor_res in "${LAUNCHER}"/app/src/{fdroid,rocks}/res; do
    [[ -d "${flavor_res}" ]] || continue
    for dir in "${ROOT}"/deepink/android/res/mipmap-*dpi; do
        mkdir -p "${flavor_res}/$(basename "${dir}")"
        cp -v "${dir}/icon.png" "${flavor_res}/$(basename "${dir}")/icon.png"
    done
done

echo "Deep Ink: launcher patched"
grep -n 'applicationId' "${GRADLE}"
