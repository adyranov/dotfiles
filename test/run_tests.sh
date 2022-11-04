#!/usr/bin/env bash
set -eo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}"  )" >/dev/null 2>&1 && pwd  )"

git clone https://github.com/bats-core/bats-core.git "$DIR"/bats 2>/dev/null || true
git clone https://github.com/bats-core/bats-assert.git "$DIR"/bats-assert 2>/dev/null || true
git clone https://github.com/bats-core/bats-support.git "$DIR"/bats-support 2>/dev/null || true
git clone https://github.com/bats-core/bats-file.git "$DIR"/bats-file 2>/dev/null || true

"${DIR}"/bats/bin/bats "${DIR}"/*.bats

rm -rf "$DIR"/bats*
