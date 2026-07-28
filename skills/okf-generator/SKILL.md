---
name: okf-generator
description: Generate, update, or validate Google Open Knowledge Format (OKF) markdown bundles from project docs, codebases, or user input. Use when asked to create an OKF file, convert docs to OKF, produce a knowledge bundle, or add curated knowledge for agents.
metadata:
  version: "1.0.0"
---

# OKF Knowledge Bundle Generator

Produce or revise OKF v0.2 bundles — directories of UTF-8 Markdown files with YAML frontmatter. One concept per file. Only the `type` field is required for conformance.

## Core rules

- Every concept file starts with a YAML frontmatter block delimited by `---` lines.
- Required frontmatter key: `type` (free-form string, e.g. `BigQuery Table`, `Metric`, `Playbook`, `API Endpoint`, `Reference`, `Attested Computation`).
- Recommended keys: `title`, `description`, `resource` (singular URI), `tags` (list), `generated` (object with `by` and `at`).
- Optional advanced families (use when data exists): `sources`, `verified`, `status`, `stale_after`, and Attested Computation fields.
- Body is free-form Markdown. Prefer headings, tables, lists, and fenced code. Conventional headings when applicable: `# Schema`, `# Examples`, `# Computation`.
- No placeholders. Fill every field from available context or omit the key.
- One concept = one file. Split multi-topic sources into separate files.
- Link related concepts with ordinary relative Markdown links, e.g. `[customers](../tables/customers.md)`.
- Reserved filenames at any level: `index.md` (directory listing), `log.md` (history). Do not use them for concepts.
- Bundle = directory tree. Organize by domain (tables/, metrics/, playbooks/, …) as needed.

## Frontmatter skeleton (minimal valid)

```yaml
---
type: <descriptive type string>
title: <human-readable name>
description: <one-sentence summary>
resource: <canonical URI if the concept describes a concrete asset>
tags: [tag1, tag2]
generated:
  by: <producer>/<version or human:id>
  at: <ISO-8601 datetime>
---
