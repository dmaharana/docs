Below is a **complete minimal Atlassian SDK Java plugin** that provides both:

- a **Pre-receive / PreRepositoryHook** (blocks direct pushes containing secrets)
- a **RepositoryMergeCheck** (blocks pull-request merges containing secrets)

Both share the same scanning logic and report **file name + line number**.

---

## Project structure

```text
secrets-guard/
├── pom.xml
├── src/
│   └── main/
│       ├── java/
│       │   └── com/
│       │       └── example/
│       │           └── secretsguard/
│       │               ├── SecretsGuardPlugin.java          (optional activator)
│       │               ├── scan/
│       │               │   ├── SecretFinding.java
│       │               │   └── GitleaksScanner.java
│       │               ├── hook/
│       │               │   └── SecretsPreRepositoryHook.java
│       │               └── merge/
│       │                   └── SecretsMergeCheck.java
│       └── resources/
│           ├── atlassian-plugin.xml
│           └── gitleaks.toml                 (optional, can also live on disk)
└── README.md
```

---

## 1. `pom.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
                             http://maven.apache.org/maven-v4_0_0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.example.bitbucket</groupId>
    <artifactId>secrets-guard</artifactId>
    <version>1.0.0-SNAPSHOT</version>
    <packaging>atlassian-plugin</packaging>

    <name>Secrets Guard for Bitbucket</name>
    <description>Blocks pushes and PR merges that contain secrets (gitleaks)</description>

    <properties>
        <bitbucket.version>10.0.0</bitbucket.version>
        <bitbucket.data.version>${bitbucket.version}</bitbucket.data.version>
        <amps.version>9.1.1</amps.version>
        <plugin.testrunner.version>2.0.2</plugin.testrunner.version>
        <atlassian.spring.scanner.version>2.1.7</atlassian.spring.scanner.version>
        <java.version>17</java.version>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>

    <dependencies>
        <dependency>
            <groupId>com.atlassian.bitbucket.server</groupId>
            <artifactId>bitbucket-api</artifactId>
            <version>${bitbucket.version}</version>
            <scope>provided</scope>
        </dependency>
        <dependency>
            <groupId>com.atlassian.sal</groupId>
            <artifactId>sal-api</artifactId>
            <scope>provided</scope>
        </dependency>
        <dependency>
            <groupId>com.atlassian.plugin</groupId>
            <artifactId>atlassian-spring-scanner-annotation</artifactId>
            <version>${atlassian.spring.scanner.version}</version>
            <scope>provided</scope>
        </dependency>
        <dependency>
            <groupId>javax.inject</groupId>
            <artifactId>javax.inject</artifactId>
            <version>1</version>
            <scope>provided</scope>
        </dependency>
        <dependency>
            <groupId>org.slf4j</groupId>
            <artifactId>slf4j-api</artifactId>
            <scope>provided</scope>
        </dependency>
        <!-- JSON parsing for gitleaks report -->
        <dependency>
            <groupId>com.google.code.gson</groupId>
            <artifactId>gson</artifactId>
            <version>2.11.0</version>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>com.atlassian.maven.plugins</groupId>
                <artifactId>bitbucket-maven-plugin</artifactId>
                <version>${amps.version}</version>
                <extensions>true</extensions>
                <configuration>
                    <products>
                        <product>
                            <id>bitbucket</id>
                            <instanceId>bitbucket</instanceId>
                            <version>${bitbucket.version}</version>
                            <dataVersion>${bitbucket.data.version}</dataVersion>
                        </product>
                    </products>
                    <instructions>
                        <Atlassian-Plugin-Key>${project.groupId}.${project.artifactId}</Atlassian-Plugin-Key>
                        <Spring-Context>*</Spring-Context>
                    </instructions>
                </configuration>
            </plugin>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>3.13.0</version>
                <configuration>
                    <source>${java.version}</source>
                    <target>${java.version}</target>
                </configuration>
            </plugin>
        </plugins>
    </build>

    <repositories>
        <repository>
            <id>atlassian-public</id>
            <url>https://packages.atlassian.com/maven/repository/public</url>
        </repository>
    </repositories>
    <pluginRepositories>
        <pluginRepository>
            <id>atlassian-public</id>
            <url>https://packages.atlassian.com/maven/repository/public</url>
        </pluginRepository>
    </pluginRepositories>
</project>
```

---

## 2. `src/main/resources/atlassian-plugin.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<atlassian-plugin key="com.example.bitbucket.secrets-guard"
                  name="Secrets Guard"
                  plugins-version="2">

    <plugin-info>
        <description>Blocks pushes and pull-request merges that contain secrets</description>
        <version>1.0.0</version>
        <vendor name="Example" url="https://example.com"/>
        <param name="plugin-icon">images/pluginIcon.png</param>
        <param name="plugin-logo">images/pluginLogo.png</param>
        <param name="atlassian-data-center-status">compatible</param>
        <param name="atlassian-data-center-compatible">true</param>
    </plugin-info>

    <!-- Pre-receive style hook (blocks direct pushes) -->
    <repository-hook key="secrets-pre-receive"
                     name="Block Secrets on Push"
                     class="com.example.secretsguard.hook.SecretsPreRepositoryHook">
        <description>
            Scans pushed commits with gitleaks and rejects the push when secrets are found.
            Reports file name and line number.
        </description>
        <icon>icons/secrets.png</icon>
        <!-- optional: configuration form later -->
    </repository-hook>

    <!-- Merge check (blocks PR merges) -->
    <repository-merge-check key="secrets-merge-check"
                            name="Block Secrets on Merge"
                            class="com.example.secretsguard.merge.SecretsMergeCheck">
        <description>
            Prevents merging a pull request when the commits being introduced contain secrets.
        </description>
        <icon>icons/secrets.png</icon>
    </repository-merge-check>

</atlassian-plugin>
```

---

## 3. Domain object – `SecretFinding.java`

```java
package com.example.secretsguard.scan;

public class SecretFinding {
    private final String file;
    private final int startLine;
    private final int endLine;
    private final String ruleId;
    private final String description;
    private final String commit;
    private final String secret; // already redacted by gitleaks when possible

    public SecretFinding(String file, int startLine, int endLine,
                         String ruleId, String description,
                         String commit, String secret) {
        this.file = file;
        this.startLine = startLine;
        this.endLine = endLine;
        this.ruleId = ruleId;
        this.description = description;
        this.commit = commit;
        this.secret = secret;
    }

    public String getFile() { return file; }
    public int getStartLine() { return startLine; }
    public int getEndLine() { return endLine; }
    public String getRuleId() { return ruleId; }
    public String getDescription() { return description; }
    public String getCommit() { return commit; }
    public String getSecret() { return secret; }

    public String toDisplayString() {
        String line = (startLine == endLine)
                ? String.valueOf(startLine)
                : startLine + "-" + endLine;
        return String.format("File: %s  Line: %s  Rule: %s  Commit: %s  Secret: %s",
                file, line, ruleId,
                commit != null && commit.length() > 12 ? commit.substring(0, 12) : commit,
                secret);
    }
}
```

---

## 4. Scanner – `GitleaksScanner.java`

```java
package com.example.secretsguard.scan;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.inject.Named;
import javax.inject.Singleton;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.TimeUnit;

/**
 * Thin wrapper around the gitleaks binary.
 * Expects gitleaks to be installed on every Bitbucket node.
 */
@Named
@Singleton
public class GitleaksScanner {

    private static final Logger log = LoggerFactory.getLogger(GitleaksScanner.class);

    // Adjust these paths for your environment
    private static final String GITLEAKS_BIN =
            System.getenv().getOrDefault("GITLEAKS_BIN", "/usr/local/bin/gitleaks");
    private static final String CONFIG_FILE =
            System.getenv().getOrDefault("GITLEAKS_CONFIG",
                    "/var/atlassian/application-data/bitbucket/shared/gitleaks/gitleaks.toml");

    /**
     * Scan the commits in the given range (e.g. "abc123..def456" or a single SHA).
     * Working directory must be the bare repository directory.
     */
    public List<SecretFinding> scan(Path repoDir, String revRange) {
        Path reportFile = null;
        try {
            reportFile = Files.createTempFile("gitleaks-report-", ".json");

            List<String> cmd = new ArrayList<>();
            cmd.add(GITLEAKS_BIN);
            cmd.add("git");
            cmd.add("--log-opts=" + revRange);
            cmd.add("--config=" + CONFIG_FILE);
            cmd.add("--report-path=" + reportFile.toAbsolutePath());
            cmd.add("--report-format=json");
            cmd.add("--redact");
            cmd.add("--no-banner");

            ProcessBuilder pb = new ProcessBuilder(cmd);
            pb.directory(repoDir.toFile());
            pb.redirectErrorStream(true);

            Process process = pb.start();
            // Drain stdout so the process cannot block
            try (BufferedReader reader = new BufferedReader(
                    new InputStreamReader(process.getInputStream(), StandardCharsets.UTF_8))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    log.debug("[gitleaks] {}", line);
                }
            }

            boolean finished = process.waitFor(5, TimeUnit.MINUTES);
            if (!finished) {
                process.destroyForcibly();
                throw new RuntimeException("gitleaks timed out after 5 minutes");
            }

            int exit = process.exitValue();
            // gitleaks exit codes: 0 = clean, 1 = leaks found, >1 = error
            if (exit > 1) {
                throw new RuntimeException("gitleaks failed with exit code " + exit);
            }
            if (exit == 0) {
                return Collections.emptyList();
            }

            return parseReport(reportFile);

        } catch (Exception e) {
            log.error("Secret scan failed", e);
            // Fail closed – treat scanner failure as a finding so the push/merge is blocked
            return List.of(new SecretFinding(
                    "(scanner-error)", 0, 0,
                    "scanner-error",
                    "gitleaks execution failed: " + e.getMessage(),
                    null, null));
        } finally {
            if (reportFile != null) {
                try { Files.deleteIfExists(reportFile); } catch (Exception ignored) {}
            }
        }
    }

    private List<SecretFinding> parseReport(Path reportFile) throws Exception {
        String json = Files.readString(reportFile);
        if (json == null || json.isBlank()) {
            return Collections.emptyList();
        }

        JsonElement root = JsonParser.parseString(json);
        JsonArray findingsArray;

        if (root.isJsonArray()) {
            findingsArray = root.getAsJsonArray();
        } else {
            JsonObject obj = root.getAsJsonObject();
            if (obj.has("Findings")) {
                findingsArray = obj.getAsJsonArray("Findings");
            } else if (obj.has("findings")) {
                findingsArray = obj.getAsJsonArray("findings");
            } else {
                return Collections.emptyList();
            }
        }

        List<SecretFinding> result = new ArrayList<>();
        for (JsonElement el : findingsArray) {
            JsonObject f = el.getAsJsonObject();
            String file = getString(f, "File", "file");
            int start = getInt(f, "StartLine", "start_line", "Line");
            int end   = getInt(f, "EndLine", "end_line", start);
            String rule = getString(f, "RuleID", "rule_id", "Rule");
            String desc = getString(f, "Description", "description");
            String commit = getString(f, "Commit", "commit");
            String secret = getString(f, "Secret", "secret");

            result.add(new SecretFinding(file, start, end, rule, desc, commit, secret));
        }
        return result;
    }

    private static String getString(JsonObject o, String... keys) {
        for (String k : keys) {
            if (o.has(k) && !o.get(k).isJsonNull()) {
                return o.get(k).getAsString();
            }
        }
        return "?";
    }

    private static int getInt(JsonObject o, String key1, String key2, int defaultValue) {
        if (o.has(key1) && !o.get(key1).isJsonNull()) return o.get(key1).getAsInt();
        if (o.has(key2) && !o.get(key2).isJsonNull()) return o.get(key2).getAsInt();
        return defaultValue;
    }

    private static int getInt(JsonObject o, String key1, String key2, String key3) {
        if (o.has(key1) && !o.get(key1).isJsonNull()) return o.get(key1).getAsInt();
        if (o.has(key2) && !o.get(key2).isJsonNull()) return o.get(key2).getAsInt();
        if (o.has(key3) && !o.get(key3).isJsonNull()) return o.get(key3).getAsInt();
        return 0;
    }
}
```

---

## 5. Pre-receive hook – `SecretsPreRepositoryHook.java`

```java
package com.example.secretsguard.hook;

import com.atlassian.bitbucket.hook.repository.*;
import com.atlassian.bitbucket.repository.Repository;
import com.atlassian.bitbucket.scm.ScmService;
import com.example.secretsguard.scan.GitleaksScanner;
import com.example.secretsguard.scan.SecretFinding;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.annotation.Nonnull;
import javax.inject.Inject;
import javax.inject.Named;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;

@Named
public class SecretsPreRepositoryHook implements PreRepositoryHook<RepositoryHookRequest> {

    private static final Logger log = LoggerFactory.getLogger(SecretsPreRepositoryHook.class);
    private static final String ZERO = "0000000000000000000000000000000000000000";

    private final GitleaksScanner scanner;
    private final ScmService scmService;

    @Inject
    public SecretsPreRepositoryHook(GitleaksScanner scanner, ScmService scmService) {
        this.scanner = scanner;
        this.scmService = scmService;
    }

    @Nonnull
    @Override
    public RepositoryHookResult preUpdate(@Nonnull PreRepositoryHookContext context,
                                          @Nonnull RepositoryHookRequest request) {

        Repository repo = request.getRepository();
        Path repoDir = scmService.getScm(repo)
                .getCommandFactoryBuilder()
                .build()
                .getRepositoryDir(repo)
                .toPath();

        List<SecretFinding> allFindings = new ArrayList<>();

        for (RefChange change : request.getRefChanges()) {
            String from = change.getFromHash();
            String to   = change.getToHash();

            // Skip deletes
            if (ZERO.equals(to)) {
                continue;
            }

            String range = ZERO.equals(from) ? to : from + ".." + to;
            log.debug("Scanning range {} on {}", range, repo.getSlug());

            List<SecretFinding> findings = scanner.scan(repoDir, range);
            allFindings.addAll(findings);
        }

        if (allFindings.isEmpty()) {
            return RepositoryHookResult.accepted();
        }

        // Build a clear rejection message that includes file + line
        StringBuilder msg = new StringBuilder();
        msg.append("Secrets detected – push rejected.\n\n");
        int i = 1;
        for (SecretFinding f : allFindings) {
            msg.append("[").append(i++).append("] ").append(f.toDisplayString()).append("\n");
        }
        msg.append("\nRemove the secrets and push again.");

        return RepositoryHookResult.rejected("Secrets detected", msg.toString());
    }
}
```

> Note: Obtaining the bare repository directory via `ScmService` can vary slightly between Bitbucket versions.  
> If the above does not compile on your exact 10.x version, the most reliable alternative is to resolve the path from `BITBUCKET_HOME/shared/data/repositories/<repoId>` using the repository ID. I can adjust that snippet if needed.

---

## 6. Merge check – `SecretsMergeCheck.java`

```java
package com.example.secretsguard.merge;

import com.atlassian.bitbucket.hook.repository.*;
import com.atlassian.bitbucket.pull.PullRequest;
import com.atlassian.bitbucket.repository.Repository;
import com.atlassian.bitbucket.scm.ScmService;
import com.example.secretsguard.scan.GitleaksScanner;
import com.example.secretsguard.scan.SecretFinding;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.annotation.Nonnull;
import javax.inject.Inject;
import javax.inject.Named;
import java.nio.file.Path;
import java.util.List;

@Named
public class SecretsMergeCheck implements RepositoryMergeCheck {

    private static final Logger log = LoggerFactory.getLogger(SecretsMergeCheck.class);

    private final GitleaksScanner scanner;
    private final ScmService scmService;

    @Inject
    public SecretsMergeCheck(GitleaksScanner scanner, ScmService scmService) {
        this.scanner = scanner;
        this.scmService = scmService;
    }

    @Nonnull
    @Override
    public RepositoryHookResult preUpdate(@Nonnull PreRepositoryHookContext context,
                                          @Nonnull PullRequestMergeHookRequest request) {

        PullRequest pr = request.getPullRequest();
        Repository repo = pr.getToRef().getRepository();

        // Commits that will be introduced by the merge
        String fromHash = pr.getFromRef().getLatestCommit();
        String toHash   = pr.getToRef().getLatestCommit();
        String range    = toHash + ".." + fromHash;   // commits reachable from source but not target

        Path repoDir = scmService.getScm(repo)
                .getCommandFactoryBuilder()
                .build()
                .getRepositoryDir(repo)
                .toPath();

        log.debug("Merge-check scanning range {} on {}", range, repo.getSlug());

        List<SecretFinding> findings = scanner.scan(repoDir, range);

        if (findings.isEmpty()) {
            return RepositoryHookResult.accepted();
        }

        StringBuilder msg = new StringBuilder();
        msg.append("Secrets detected in the commits being merged. Merge blocked.\n\n");
        int i = 1;
        for (SecretFinding f : findings) {
            msg.append("[").append(i++).append("] ").append(f.toDisplayString()).append("\n");
        }
        msg.append("\nRemove the secrets from the source branch and update the pull request.");

        return RepositoryHookResult.rejected("Secrets detected", msg.toString());
    }
}
```

---

## 7. Build & install

```bash
# From the project root
atlas-package          # or: mvn package

# The JAR will be in target/secrets-guard-1.0.0-SNAPSHOT.jar
```

Install via **Administration → Manage apps → Upload app**.

Then enable the two components:

- Repository / Project settings → **Hooks** → enable **Block Secrets on Push**
- Repository / Project settings → **Merge checks** → enable **Block Secrets on Merge**

---

## 8. Runtime requirements

On every Bitbucket node:

```bash
# gitleaks binary
sudo cp gitleaks /usr/local/bin/
sudo chmod +x /usr/local/bin/gitleaks

# shared config (same file shown in the previous answer)
sudo mkdir -p /var/atlassian/application-data/bitbucket/shared/gitleaks
sudo cp gitleaks.toml /var/atlassian/application-data/bitbucket/shared/gitleaks/
sudo chown -R atlbitbucket:atlbitbucket /var/atlassian/application-data/bitbucket/shared/gitleaks
```

You can override paths with environment variables:

```bash
GITLEAKS_BIN=/usr/local/bin/gitleaks
GITLEAKS_CONFIG=/path/to/gitleaks.toml
```

---

## Notes & next steps

- The scanner currently fails closed (scanner error = treat as secret). Change the catch block in `GitleaksScanner` if you prefer fail-open.
- For very large pushes you may want to raise `mesh.hooks.callback.timeout`.
- Obtaining the bare repo directory can be version-sensitive; if the `getRepositoryDir` call does not compile, tell me your exact Bitbucket 10.x version and I will give the compatible alternative.
- A configuration UI (path to gitleaks, enable/disable per repo, custom allow-list) can be added later with a simple settings form.

Would you like me to also supply:

1. A more robust way to resolve the repository directory that works across 8.x–10.x, or  
2. A simple configuration form so admins can change the gitleaks path / config path from the UI?
