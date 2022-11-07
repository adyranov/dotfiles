#!/usr/bin/env bash
set -eo pipefail

DIR="$(dirname "$(readlink -f "$0")")"

git clone --depth=1 https://github.com/bats-core/bats-core.git "$DIR"/bats 2>/dev/null || true
git clone --depth=1 https://github.com/bats-core/bats-assert.git "$DIR"/bats-assert 2>/dev/null || true
git clone --depth=1 https://github.com/bats-core/bats-support.git "$DIR"/bats-support 2>/dev/null || true
git clone --depth=1 https://github.com/bats-core/bats-file.git "$DIR"/bats-file 2>/dev/null || true

"${DIR}"/bats/bin/bats "${DIR}"/*.bats

rm -rf "$DIR"/bats*
