# Transport Probe Verdict — git-over-HTTPS Credential Injection

Plan group: .compound-engineering/artifacts/plans/2026-11-06-2153-feat-agent-permission-loop-plan.md PR2 <!-- markdownlint-disable-line MD013 -->

Unit: the probe unit (extend and run the u6 probe; record the verdict) of PR2
of that plan group.

Status: PENDING — the extended spike has not been run against the current
probe shape. Every gate below is unfilled; a reviewer must be able to
re-derive the branch choice from the filled table alone.

`nono --version`: <record the exact version line the run prints, verbatim>

## Gate results

Paste each gate's raw block (label, command, exit code, full output including
raw failure text) from `.slim/deepwork/u6-results.txt` into the Evidence
column and mark the Result pass/fail/skip.

| Gate | Probe | Result | Evidence |
| --- | --- | --- | --- |
| G1 | git TLS through the proxy, house CA bundle (baseline) | | |
| G2 | same probe with `--trust-proxy-ca` | | |
| G3a | built-in api route active, git transport on `github.com` | | |
| G3b | transport route: `ls-remote` private repo (ref-advertisement GET) | | |
| G3c | transport route: full clone (upload-pack POST) | | |
| G4 | transport route: push the probe branch (receive-pack POST) | | |
| G5 | GET-only endpoint policy: push refused before egress (negative) | | |
| G5a | `connect_intercept` audit line for the G5 refusal (>= 1) | | |
| G6 | scrub invariant: real token absent from env, phantom set | | |
| G7 | coexistence: `gh api /user` returns the account with the transport row active | | |

## Branch decision

- Pass with coexistence — G3b/G3c/G4 inject and complete, G5/G5a deny as an
  audited policy intercept, and G7 shows `gh api` auth survived the transport
  row → build the transport arm: the credential route on the git-transport
  host, injected at egress, zero real values in the sandbox.
- Any other outcome — injection fails on any leg, the G5 refusal is a server
  reply rather than an audited intercept, or G7 shows the transport row
  dropped api auth (the route map keys one service name, so a passing render
  can silently drop `gh` auth) → build the scoped-token pass-through fallback
  arm, and report the transport gap upstream.

Decision: PENDING — record one line here after the run, naming the gates that
decided it.

## How to run

Run the spike in your normal terminal:

```sh
sh .slim/deepwork/u6-spike.sh
```

Never from inside an agent sandbox: a nested `nono run` from inside a sandbox
is invalid, so this run is user-terminal-only. Export the env gates the script
header documents — `GITHUB_TOKEN` (unset skips all authed probes, including
the coexistence gate), `U6_PRIVATE_URL` (unlocks the G3 legs), `GIT_PUSH_URL`
(unlocks the G4/G5 legs). The script records the exact `nono --version` line
and every gate G1–G7 verbatim (exit code plus raw failure text) to
`.slim/deepwork/u6-results.txt` next to it. Copy the version line and the gate
blocks into this document, then set the branch-decision line above. The spike
scratch lives under gitignored `.slim/` — this tracked document is the durable
verdict record.
