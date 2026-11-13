**For Bitbucket Data Center 10, use the managed Hook Scripts feature (REST API).** Legacy filesystem hooks under `hooks/pre-receive.d` are deprecated/disabled since Bitbucket 8.x and are not the supported path on v10.

Bitbucket also has **built-in secret scanning** (enabled by default). A Gitleaks pre-receive hook is still useful if you need stricter blocking, custom rules, or different allowlisting.

### 1. Prerequisites on the Bitbucket server(s)

- Install **Gitleaks** (binary) where the Bitbucket process can execute it (shared path or on every node + Mesh nodes if used). Example:
  ```bash
  # Download latest release binary for your OS/arch and place it e.g.
  /opt/gitleaks/gitleaks
  chmod +x /opt/gitleaks/gitleaks
  ```
- Ensure the user running Bitbucket can execute it.
- Enable hook scripts (required since ~8.18; disabled by default for security):
  In `bitbucket.properties` (shared home):
  ```properties
  feature.hook.scripts=true
  ```
  Restart Bitbucket (or rolling restart in a cluster).
- Consider increasing the hook timeout if large pushes are common (default is often ~4 minutes / 240s):
  ```properties
  # In bitbucket.properties or mesh.properties depending on architecture
  mesh.hooks.callback.timeout=1200   # or hooks.callback.timeout=1200
  ```

### 2. Pre-receive hook script (Gitleaks)

Create a script (e.g. `gitleaks-pre-receive.sh`). Pre-receive receives lines of `oldrev newrev refname` on stdin. New objects are in a quarantine area, so you must scan only the incoming commits (via `--log-opts`).

```bash
#!/bin/bash
# gitleaks-pre-receive.sh
# Rejects pushes that contain secrets detected by Gitleaks.
# Exit 0 = allow, non-zero = reject.

set -euo pipefail

GITLEAKS_BIN="${GITLEAKS_BIN:-/opt/gitleaks/gitleaks}"
CONFIG_FILE="${GITLEAKS_CONFIG:-}"          # optional global config
ZERO="0000000000000000000000000000000000000000"
EXIT_CODE=0

if [[ ! -x "$GITLEAKS_BIN" ]]; then
  echo "ERROR: gitleaks binary not found or not executable at $GITLEAKS_BIN" >&2
  exit 1
fi

# Optional: load repo-level config if present in the incoming tip
# (advanced; many teams use a central config + .gitleaksignore)

while read -r oldrev newrev refname; do
  # Deletion of a ref
  if [[ "$newrev" == "$ZERO" ]]; then
    continue
  fi

  if [[ "$oldrev" == "$ZERO" ]]; then
    # New branch/tag – scan the new commits that are not already reachable
    log_opts="--not --all $newrev"
  else
    # Update – scan the range of new commits
    log_opts="$oldrev..$newrev"
  fi

  # Build gitleaks command
  cmd=("$GITLEAKS_BIN" git --source=. --log-opts="$log_opts" --verbose --redact --no-banner)

  if [[ -n "$CONFIG_FILE" && -f "$CONFIG_FILE" ]]; then
    cmd+=(--config "$CONFIG_FILE")
  fi

  # Also respect a .gitleaks.toml / .gitleaksignore if present at the tip of the push
  # (gitleaks looks for them automatically in many cases)

  echo "Scanning $refname ($log_opts) with Gitleaks..." >&2
  if ! "${cmd[@]}"; then
    echo "" >&2
    echo "============================================================" >&2
    echo "PUSH REJECTED: Gitleaks detected one or more secrets." >&2
    echo "Ref: $refname" >&2
    echo "Remove the secret(s), rotate any exposed credentials, and push again." >&2
    echo "For known false positives see the allowlist instructions below." >&2
    echo "============================================================" >&2
    EXIT_CODE=1
  fi
done

exit $EXIT_CODE
```

**Notes on the scan range**
- Using `--log-opts` with `oldrev..newrev` (or the `--not --all` pattern for new branches) is the standard way to scan only incoming commits in a pre-receive hook.
- Do **not** scan the entire history on every push (performance killer).

Make the script executable and test it locally against a bare repo if possible.

### 3. Upload and enable the hook (Bitbucket 8+/10)

**Upload** (system admin):

```bash
curl -u ADMIN_USER:PASSWORD \
  -H 'X-Atlassian-Token: no-check' \
  -F "content=@gitleaks-pre-receive.sh" \
  -F "name=gitleaks-secret-scan" \
  -F "description=Reject pushes containing secrets detected by Gitleaks" \
  -F "type=PRE" \
  "https://your-bitbucket.example.com/rest/api/latest/hook-scripts"
```

Note the returned `id` (e.g. `1`).

**Enable on a repository**:

```bash
curl -u ADMIN_USER:PASSWORD \
  -X PUT \
  -H 'Content-Type: application/json' \
  -d '{ "triggerIds": [] }' \
  "https://your-bitbucket.example.com/rest/api/latest/projects/PROJ/repos/my-repo/hook-scripts/1"
```

**Enable on a whole project** (inherits to repos; note that project-level hook scripts cannot be easily disabled per-repo in the same way as UI hooks):

```bash
curl -u ADMIN_USER:PASSWORD \
  -X PUT \
  -H 'Content-Type: application/json' \
  -d '{ "triggerIds": [] }' \
  "https://your-bitbucket.example.com/rest/api/latest/projects/PROJ/hook-scripts/1"
```

Empty `triggerIds` typically means the default set of relevant triggers (pushes, etc.). You can restrict to specific triggers if needed (see Bitbucket hook-scripts docs).

Scripts are stored under `$BITBUCKET_HOME/shared/config/hooks-scripts`.

### 4. Handling false positives

Gitleaks provides several layers (prefer the most specific):

1. **Inline allow (best for one-off true false positives)**  
   Add a comment on the same line:
   ```
   const API_KEY = "example-not-a-real-key"; // gitleaks:allow
   ```

2. **`.gitleaksignore` (fingerprint-based)**  
   After a detection, take the fingerprint from the Gitleaks output and put it in a `.gitleaksignore` file at the repo root. This is precise and does not weaken rules globally.

3. **Repository / central `.gitleaks.toml` allowlists**  
   Example:
   ```toml
   title = "Company Gitleaks config"

   [extend]
   useDefault = true

   [[allowlists]]
   description = "Test fixtures and docs"
   paths = [
     '''(?i)test(s)?/''',
     '''(?i)testdata/''',
     '''(?i)fixtures/''',
     '''\.md$''',
     '''docs/'''
   ]

   [[allowlists]]
   description = "Known placeholder / example values"
   regexTarget = "match"
   regexes = [
     '''EXAMPLE_API_KEY''',
     '''dummy-secret-123''',
     '''your-api-key-here'''
   ]
   ```
   You can keep a global config on the server (`GITLEAKS_CONFIG`) and/or let repos ship their own `.gitleaks.toml`.

4. **Rule-specific allowlists** (narrower than global):
   ```toml
   [[rules]]
   id = "generic-api-key"
   [[rules.allowlists]]
   description = "..."
   regexes = ['''specific-false-positive''']
   ```

Never broadly allowlist real-looking secret patterns. Prefer fingerprints or path/regex scoped allowlists, and require rotation for any real credential that was ever committed.

### 5. Operational recommendations

- **Performance**: Only scan the pushed range. Large binary files or huge pushes can still be slow — consider timeouts and monitoring.
- **Mesh / multi-node**: Gitleaks binary must be available (and executable) on every node that runs hooks, including Mesh nodes.
- **Complementary controls**:
  - Keep Bitbucket’s native secret scanning enabled.
  - Encourage (or enforce via pre-commit) local Gitleaks/pre-commit hooks so developers catch secrets before push.
  - Add CI scanning as a second line of defense.
- **Testing**:
  1. Push a commit with a known test secret → should be rejected with a clear message.
  2. Push the same secret with `// gitleaks:allow` or a fingerprint in `.gitleaksignore` → should be accepted.
  3. Push a branch deletion and a normal clean update → should succeed.
- **Logging**: Redirect or capture stderr if you want centralized audit of rejected pushes.

### 6. Alternatives / stronger options

- **Java plugin** implementing `PreReceiveRepositoryHook` / `PreReceiveHook` — recommended by Atlassian for production-grade hooks (better integration, configuration UI, no shell). More development effort.
- Marketplace apps (e.g. Security for Bitbucket / Soteri) that already provide secret scanning + pre-receive blocking + allowlisting UI.
- External Hooks plugin if you still prefer filesystem-style management (less preferred on modern Bitbucket).

If you need a ready-to-adapt version of the script with extra features (JSON report, Slack notification on rejection, per-repo config lookup via `git show $newrev:.gitleaks.toml`, etc.), say what extra behavior you want and I can refine it.