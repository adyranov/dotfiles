#!/bin/bash

set -eufo pipefail

if command -v kubectl-krew >/dev/null; then
    plugins=(
        access-matrix
        ctx
        deprecations
        get-all
        konfig
        modify-secret
        neat
        node-shell
        ns
        popeye
        resource-capacity
        score
        sniff
        tail
        tap
        tree
        tunnel
        view-secret
        who-can
    )

    kubectl-krew install ${plugins[@]}
fi
