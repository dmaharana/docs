Here is a complete, production-ready package for **Bitbucket Data Center 10**.

---

### 1. Prerequisites on every Bitbucket node

```bash
# Install gitleaks binary (example for Linux x86_64)
curl -sSL https://github.com/gitleaks/gitleaks/releases/latest/download/gitleaks_8.24.3_linux_x64.tar.gz | tar xz
sudo mv gitleaks /usr/local/bin/
sudo chmod +x /usr/local/bin/gitleaks

# Create shared config directory (use shared home in Data Center)
sudo mkdir -p /var/atlassian/application-data/bitbucket/shared/gitleaks
sudo chown atlbitbucket:atlbitbucket /var/atlassian/application-data/bitbucket/shared/gitleaks
```

Place the config file (next section) at:

```
/var/atlassian/application-data/bitbucket/shared/gitleaks/gitleaks.toml
```

---

### 2. Custom gitleaks config (`gitleaks.toml`)

```toml
title = "Bitbucket Data Center Secret Scanning"

[extend]
useDefault = true

# ---------------------------------------------------------------------------
# Global allowlists
# ---------------------------------------------------------------------------
[[allowlists]]
description = "Common false positives and documentation placeholders"
paths = [
  '''(?i)\.gitleaks\.toml$''',
  '''(?i)(package-lock\.json|yarn\.lock|go\.sum|go\.mod)$''',
  '''(?i)\.(png|jpe?g|gif|svg|ico|woff2?|ttf|eot|pdf|zip|tar\.gz|tgz)$''',
  '''(?i)(node_modules|vendor|\.venv|__pycache__)/''',
  '''(?i)(test|tests|spec|fixture|fixtures|mock|mocks)/''',
  '''(?i)\.(env\.sample|env\.example|env\.template)$''',
]

regexes = [
  '''(?i)(example|sample|dummy|placeholder|changeme|your[_-]?api[_-]?key|your[_-]?secret|xxx+|TODO)''',
  '''AKIAIOSFODNN7EXAMPLE''',
  '''wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY''',
  '''gitleaks:allow''',          # inline suppression comment
]

# ---------------------------------------------------------------------------
# Extra rules for internal / company tokens (customize these)
# ---------------------------------------------------------------------------
[[rules]]
id = "company-internal-api-key"
description = "Company internal API key pattern"
regex = '''(?i)(?:company|internal)[_-]?(?:api[_-]?)?(?:key|token|secret)\s*[:=]\s*['"]?([A-Za-z0-9_\-]{32,64})['"]?'''
secretGroup = 1
entropy = 3.5
keywords = ["company", "internal", "api", "token", "secret"]
tags = ["company", "internal"]

[[rules]]
id = "company-service-account-token"
description = "Company service-account style token"
regex = '''sat_[A-Za-z0-9]{40,80}'''
entropy = 4.0
keywords = ["sat_"]
tags = ["company", "service-account"]

[[rules]]
id = "private-key-block"
description = "PEM private key"
regex = '''(?s)-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----.+?-----END (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----'''
tags = ["key", "private-key"]

# Rule-level allowlist example (ignore known test keys)
[[rules]]
id = "aws-access-key"
[rules.allowlists]
description = "Ignore AWS documentation example keys"
regexes = [
  '''AKIAIOSFODNN7EXAMPLE''',
  '''ASIAIOSFODNN7EXAMPLE''',
]
```

---

### 3. Full pre-receive hook script

Save as `block-secrets-pre-receive.sh`:

```bash
#!/bin/bash
# =============================================================================
# Bitbucket Data Center – Pre-receive hook: block pushes containing secrets
# Uses gitleaks. Reports file name + line number of every finding.
# =============================================================================

set -euo pipefail

GITLEAKS_BIN="${GITLEAKS_BIN:-/usr/local/bin/gitleaks}"
CONFIG_FILE="${GITLEAKS_CONFIG:-/var/atlassian/application-data/bitbucket/shared/gitleaks/gitleaks.toml}"
ZERO_OID="0000000000000000000000000000000000000000"
REPORT_DIR=$(mktemp -d)
trap 'rm -rf "$REPORT_DIR"' EXIT

# Fail closed if gitleaks is missing
if [[ ! -x "$GITLEAKS_BIN" ]]; then
  echo "ERROR: gitleaks binary not found at $GITLEAKS_BIN" >&2
  exit 1
fi

FOUND_SECRETS=0

while read -r oldrev newrev refname; do
  # Skip deletions
  if [[ "$newrev" == "$ZERO_OID" ]]; then
    continue
  fi

  if [[ "$oldrev" == "$ZERO_OID" ]]; then
    # New branch / tag – scan all commits reachable from newrev that are not
    # already in any other ref (best-effort for performance)
    range="$newrev"
  else
    range="${oldrev}..${newrev}"
  fi

  REPORT_FILE="${REPORT_DIR}/report.json"

  # Run gitleaks and capture JSON report
  set +e
  "$GITLEAKS_BIN" git \
    --log-opts="$range" \
    --config="$CONFIG_FILE" \
    --report-path="$REPORT_FILE" \
    --report-format=json \
    --redact \
    --no-banner \
    --verbose 2>"${REPORT_DIR}/gitleaks.err"
  RC=$?
  set -e

  if [[ $RC -eq 1 ]]; then
    FOUND_SECRETS=1
    echo ""
    echo "============================================================"
    echo "  SECRETS DETECTED – PUSH REJECTED"
    echo "  Repository : ${BB_PROJECT_KEY:-unknown}/${BB_REPO_SLUG:-unknown}"
    echo "  Ref        : $refname"
    echo "  User       : ${BB_USER_NAME:-unknown}"
    echo "============================================================"
    echo ""

    if [[ -f "$REPORT_FILE" ]]; then
      # Pretty-print findings with file + line number
      # gitleaks JSON fields: File, StartLine, EndLine, RuleID, Description, Secret (redacted), Commit
      python3 - "$REPORT_FILE" <<'PY' 2>/dev/null || cat "$REPORT_FILE"
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
findings = data if isinstance(data, list) else data.get("Findings", data.get("findings", []))
if not findings:
    print("(raw report)")
    print(open(sys.argv[1]).read())
    sys.exit(0)
for i, f in enumerate(findings, 1):
    file    = f.get("File") or f.get("file") or "?"
    line    = f.get("StartLine") or f.get("start_line") or f.get("Line") or "?"
    endline = f.get("EndLine") or f.get("end_line") or line
    rule    = f.get("RuleID") or f.get("rule_id") or f.get("Rule") or "?"
    desc    = f.get("Description") or f.get("description") or ""
    commit  = (f.get("Commit") or f.get("commit") or "")[:12]
    secret  = f.get("Secret") or f.get("secret") or "(redacted)"
    print(f"[{i}] File      : {file}")
    print(f"    Line      : {line}" + (f"-{endline}" if str(endline) != str(line) else ""))
    print(f"    Rule      : {rule}")
    print(f"    Description: {desc}")
    print(f"    Commit    : {commit}")
    print(f"    Secret    : {secret}")
    print()
PY
    else
      # Fallback if JSON report missing
      cat "${REPORT_DIR}/gitleaks.err" || true
    fi

    echo "------------------------------------------------------------"
    echo "Remove the secrets, then push again."
    echo "To suppress a known false-positive add a comment:"
    echo "  // gitleaks:allow"
    echo "or update the allowlist in the shared gitleaks.toml."
    echo "============================================================"
  elif [[ $RC -ne 0 ]]; then
    echo "ERROR: gitleaks failed with exit code $RC" >&2
    cat "${REPORT_DIR}/gitleaks.err" >&2 || true
    exit 1
  fi
done

if [[ $FOUND_SECRETS -eq 1 ]]; then
  exit 1
fi

exit 0
```

Make it executable locally before upload:

```bash
chmod +x block-secrets-pre-receive.sh
```

---

### 4. Exact curl commands for Bitbucket 10

Replace the placeholders:

- `https://bitbucket.example.com`
- `admin` / `password` (or better: personal access token)
- `PROJ` / `my-repo`

#### A. Enable the feature (if not already)

In `bitbucket.properties` (shared home) add / ensure:

```properties
feature.hook.scripts=true
# or the older property still accepted in some versions:
# plugin.hook-scripts.enabled=true
```

Restart Bitbucket (or rolling restart in DC).

#### B. Upload the global hook script (SYS_ADMIN required)

```bash
curl -v -u admin:password \
  -H "X-Atlassian-Token: no-check" \
  -F "content=@block-secrets-pre-receive.sh" \
  -F "name=block-secrets" \
  -F "description=Block pushes that contain secrets (gitleaks)" \
  -F "type=PRE" \
  "https://bitbucket.example.com/rest/api/latest/hook-scripts"
```

Response example:

```json
{
  "id": 12,
  "name": "block-secrets",
  "type": "PRE",
  ...
}
```

Note the `id` (e.g. `12`).

#### C. Enable on a single repository

```bash
curl -v -u admin:password \
  -X PUT \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{}' \
  "https://bitbucket.example.com/rest/api/latest/projects/PROJ/repos/my-repo/hook-scripts/12"
```

#### D. Enable on a whole project (all repos)

```bash
curl -v -u admin:password \
  -X PUT \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{}' \
  "https://bitbucket.example.com/rest/api/latest/projects/PROJ/hook-scripts/12"
```

#### E. Useful management commands

```bash
# List global scripts
curl -u admin:password "https://bitbucket.example.com/rest/api/latest/hook-scripts"

# Download current content of a script
curl -u admin:password \
  "https://bitbucket.example.com/rest/api/latest/hook-scripts/12/content" \
  -o current-script.sh

# Remove from a repository
curl -u admin:password -X DELETE \
  "https://bitbucket.example.com/rest/api/latest/projects/PROJ/repos/my-repo/hook-scripts/12"
```

---

### 5. Merge-check equivalent (PR merges)

**Important:** Hook scripts of type `PRE` do **not** run when a pull request is merged.  
You need a **Repository Merge Check**.

#### Practical options

| Option | Effort | Recommendation |
|--------|--------|----------------|
| **ScriptRunner for Bitbucket** | Low | Fastest if you already own it |
| **Java plugin** (`RepositoryMergeCheck`) | Medium | Most robust long-term |
| **Third-party secret plugin** (Soteri, Spectral, etc.) | Low | Often already includes both pre-receive + merge check |

#### Minimal Java merge-check outline

```java
@Component("secretsMergeCheck")
public class SecretsMergeCheck implements RepositoryMergeCheck {

    @Nonnull
    @Override
    public RepositoryHookResult preUpdate(@Nonnull PreRepositoryHookContext context,
                                          @Nonnull PullRequestMergeHookRequest request) {

        // 1. Obtain the commits that will be added by the merge
        // 2. Run the same gitleaks logic (or call an external service)
        // 3. If secrets found → return RepositoryHookResult.rejected(...)

        // Example skeleton:
        // if (secretsFound) {
        //     return RepositoryHookResult.rejected(
        //         "Secrets detected",
        //         "File: src/config.py  Line: 42  Rule: company-internal-api-key");
        // }
        return RepositoryHookResult.accepted();
    }
}
```

Register it in `atlassian-plugin.xml`:

```xml
<repository-merge-check key="secrets-merge-check"
                        name="Block secrets on merge"
                        class="com.example.SecretsMergeCheck">
    <description>Prevents merging pull requests that introduce secrets</description>
</repository-merge-check>
```

If you want a full working Java plugin skeleton or a ScriptRunner Groovy version, tell me which one you prefer and I will expand it.

---

### 6. Testing checklist

1. Push a clean commit → should succeed.
2. Add a fake AWS key (`AKIAIOSFODNN7EXAMPLE` is allow-listed) → should still succeed.
3. Add a real-looking key that is **not** allow-listed → push must be rejected and the client must show **file name + line number**.
4. Open a PR that contains a secret and try to merge → only the merge-check (or third-party plugin) will block it.

