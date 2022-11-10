#!/bin/sh

use_asdf() {
  source_env "$(asdf direnv envrc "$@")"
}
