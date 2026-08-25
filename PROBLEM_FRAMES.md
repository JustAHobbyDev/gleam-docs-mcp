# PROBLEM_FRAMES.md

Numbered, dated Problem Frames analyses for `gleam-docs-mcp`. Method: see
`PROBLEM_FRAMES_METHOD.md` in this repo. Entries are self-contained and meant to be
diffed against each other; earlier entries are never edited silently — corrections
go in a dated addendum or a new entry.

**Reassessment trigger:** any change that adds/removes a domain, splits or merges a
frame, or changes what crosses the machine boundary (new tool, new external call, new
persisted state). Code changes inside an unchanged frame do not trigger a pass.

---

## Entry #1 — 2026-08-25 — Vendored-dependency API lookup (`get_dependency_api` / `list_module_signatures`)

**Source:** GitHub issue #3 (`JustAHobbyDev/gleam-docs-mcp`), "Field notes from a real
build", and the focused handoff derived from it. The incident: during a live mist 6 +
Elm build, the server could tell the agent *which* version of `mist` to use (6.0.3) but
nothing about its API; the human fell back to `gleam add mist` and reading
`build/packages/mist/src/mist.gleam` by hand. The proposal is a tool that does that
read on the agent's behalf.

**Framing already established, carried in rather than re-litigated:** the incident is
evidence for a *lookup* of a known, version-pinned local artifact — the agent already
had the exact package name and exact version; nothing was being searched for. It is
not evidence for reviving Gloogle-style structural search. The Hex ranking bug and the
Gloogle self-hosting question are tracked separately and are out of scope here.

### Context: the machine as it stands (not re-analysed)

The safe-core release (commit `3fcc71a`) exposes six read-only tools over three kinds of
ground: the Hex registry over HTTPS (`search_hex_packages`, `get_package_releases`),
the user's own local project (`get_compiler_diagnostics`, `list_dependencies`,
`list_local_modules`), and the third-party Gloogle service (`gloogle_search`, currently
non-functional). No cache, no writes, no shell. The proposed tool must fit inside that
posture; where it can't, that is a finding, not a detail.

### Domains

1. **The vendored dependency source tree** — `build/packages/<pkg>/src/**/*.gleam`
   for each package the project depends on.
   *Nature:* **lexical.** It is authored upstream by package maintainers (biddable,
   remote, not in view here) and frozen onto local disk by the Gleam build tool
   (domain 3) acting on the manifest (domain 2). Once on disk it is data.
   *Read-only from the machine's perspective:* yes, unconditionally — the machine
   never writes under `build/`.
   *Can it change underneath the tool:* yes, but only in a specific way. Hex releases
   are immutable per version (the manifest records an `outer_checksum`), so the
   content of `build/packages/mist/` is a pure function of `(mist, 6.0.3)`. It never
   *drifts*; it is only ever *replaced wholesale* by another `(name, version)` when the
   build tool re-resolves — after `gleam add/remove/update`, after a branch switch
   changes `manifest.toml`, or after a manual `gleam deps download`. This is the key
   contrast with the user's own `src/`: that domain is edited continuously by a human
   and has no identity to pin a result to; this one has an observable identity
   (domain 2) and changes only at identity boundaries.
   *Whose responsibility is fetching:* the user's (via the build tool). This matters:
   fetching touches the network and writes to disk, both of which the safe-core
   posture excludes. The machine therefore treats presence as a **precondition it
   observes and reports on, never one it establishes** (see requirement R2).
   *Edge cases inside this domain:*
   - Git-sourced dependencies are also checked out under `build/packages/`; their
     identity is a commit ref, not a semver version. Same shape, different identity
     label. (Verify the on-disk layout for git deps during implementation.)
   - Path/local dependencies (`source = "local"`) are *not* copied under
     `build/packages/`; Gleam references them in place. They are therefore not in
     this domain at all — they are part of the live, human-edited world, and this
     frame does not cover them (see scope boundaries).
   - Modules that exist only as FFI (`.erl`/`.mjs` with no `.gleam`) have no Gleam
     public surface and are simply absent from this domain's view.

2. **The dependency lock record** — `manifest.toml` (all resolved packages, direct and
   transitive, with version and checksum) and `build/packages/packages.toml` (what
   has actually been fetched).
   *Nature:* **lexical**, machine-written by the Gleam build tool ("Do not manually
   edit this file"). Read-only for us. This is the domain that makes domain 1's
   identity *observable*: it lets the machine say "I read mist **6.0.3**" rather than
   "I read whatever was in that directory". It is also the authority on whether a
   package is *declared* (in the manifest) versus *present* (in `packages.toml` and on
   disk), which are distinct states with distinct failure messages.

3. **The Gleam build tool** — `gleam` CLI.
   *Nature:* **causal**, deterministic. Not invoked by this frame at all; it is the
   off-stage actor whose prior behaviour produced domains 1 and 2. Named so the
   boundary is explicit: this frame reads the *results* of the build tool and does not
   drive it.

4. **The Gleam declaration syntax** — the surface form through which the machine reads
   domain 1: `pub fn`, `pub type`, `pub opaque type`, `pub const`, `///` doc comments,
   `//// ` module docs, and attributes (`@deprecated`, `@internal`, `@external`).
   Not a "thing in the world" in the physical sense, but it is the interface contract
   the machine leans on, so it gets the invariance test below. Note that compiled
   artefacts (`build/dev/erlang/<pkg>/_gleam_artefacts/*.cache_meta`) are a second,
   machine-readable form of the same public interface — but they are a compiler-
   internal format with no stability promise, and they only exist after a build. They
   are explicitly *not* ground for this frame.

5. **The requesting agent** — the stakeholder. Stateless per call, as in the
   elm-docs-mcp analysis. In this incident the agent's state at the moment of need was
   "I know the package and the version; I need its surface" — a lookup stakeholder,
   not a discovery stakeholder. For an MCP client that can read files itself (Claude
   Code), the agent *could* have read `mist.gleam` directly; the tool's marginal value
   for such clients is **location** (module name → file path across `build/packages`,
   without knowing the layout), **condensation** (public signatures + docs are a small
   fraction of a large source file), and **identity** (stating D@V alongside the
   result). For clients without filesystem access, it is the only access at all. This
   is stated honestly so the tool isn't oversold: it is `go doc` for Gleam, not a new
   capability.

6. **The user's own project** — `gleam.toml` and `src/`.
   *Nature:* biddable/live. Touched by this frame **only as a locator**: `project_path`
   → `manifest.toml` → `build/packages`. Its own modules are not read. Its
   `gleam.toml` is consulted for one fact only — whether a package is a *direct*
   dependency (see R3) — because that fact has a real-world consequence for the agent.

No machine-owned domain is introduced: no cache, no index, no derived state. Every call
re-reads domains 1 and 2 fresh, consistent with the existing no-cache posture. Because
domain 1 only changes at identity boundaries, the no-cache decision costs nothing here
(reads are local and cheap) and buys the guarantee that a re-resolve between calls is
always reflected.

### Frame

**Frame V — Vendored dependency API lookup.**
Domains: 1, 2, 5 (6 as locator only).
Shape: **Information Display** — read a lexical domain, present what it says. This is
the lowest-risk shape in the catalogue and the one the incident actually asked for.

Two candidate decompositions were considered:

- *V0 "resolve presence/identity" as a separate frame from V1 "read signatures".*
  Rejected as a split, kept as a stated precondition. V0 on its own is a lookup into
  domain 2 ("is mist in the manifest, at what version, is it fetched?") — but
  `list_dependencies` already reports declared deps, and V0's only stakeholder value
  is in service of V1. Splitting would create a frame with no independent
  requirement. Instead, V0's *output* — the resolved `(name, version-or-ref)` — is
  made a mandatory part of every V result (R1), which is where its value actually
  lives.
- *Two granularities: list a dependency's modules vs. read one module's public
  surface.* The issue's two suggested names hint at both. Both are Information
  Display over the same domain with the same precondition; they are one frame
  served at two zoom levels (a dep-with-no-module argument lists modules; a
  dep-plus-module argument reads signatures). One frame, possibly one or two tools —
  the tool count is a specification decision, not a frame decision.

Confirmed: **one frame.** It is not Workpieces (nothing here is being worked on; the
domain is inert between identity changes) and not Transformation (no new lexical
domain is produced; output is served, not persisted).

### Requirements (world-level)

- **R1 — Fidelity and identity.** Whenever the agent asks for the public API of module
  `M` in dependency `D` of project `P`, and `D` is recorded in `P`'s manifest at
  version `V` and is present under `build/packages`, the answer shall reflect exactly
  the public, documented declarations of `M` as they exist on disk in `D@V` at the
  moment of the request — and shall state `D` and `V` (or the git ref) so the agent
  knows what it read. When no module is given, the answer shall list `D@V`'s modules.

- **R2 — Precondition is observed, not established.** If `D` is not in the manifest,
  or is in the manifest but not fetched, the call is a **tool-level error** that says
  which of the two cases applies and names the user action that would resolve it
  (`gleam add D` / `gleam deps download`). The machine shall not fetch. *Reasoning:*
  fetching is a world-mutating act (network + disk writes) that the safe-core release
  deliberately excludes, and it belongs to the user's build tool; silently fetching
  would also change domain 1 under the agent's feet mid-session.

- **R3 — Transitive dependencies are in scope; directness is reported.** The
  manifest (domain 2), not `gleam.toml`, is the authority on what may be read: an
  agent reading `mist`'s signatures will immediately need `gleam_http`'s types, and
  the lexical domain is identical whether the user chose the package or the resolver
  did. But the result shall say whether `D` is a *direct* dependency of `P`, because
  the Gleam compiler rejects imports from packages not declared in `gleam.toml` —
  an agent that reads a transitive dep's API and then imports it will hit a compiler
  error it cannot explain without this fact.

- **R4 — Success vs. error semantics.** A module with no public declarations is a
  *successful* call with an empty-surface answer. A `.gleam` file the machine cannot
  parse is a *tool-level error* naming the file — never a silently truncated or
  partial listing. *Reasoning:* Information Display's one real hazard is a partial
  read presented as complete, which turns "uninformed" into "confidently wrong". Fail
  loud, per file, so the invariance risk in domain 4 (below) is observable when it
  bites.

- **R5 — Explicit scope boundaries.** This frame does **not** cover:
  - private declarations, function bodies, or FFI implementations;
  - the user's own modules under `src/` (that is the existing local-project ground
    and a candidate future frame, not this one);
  - path/local dependencies (`source = "local"`) — live, human-edited, outside
    domain 1;
  - published documentation from hexdocs.pm or any network source — this frame is
    offline by construction;
  - any form of search, ranking, or fuzzy matching across packages — the agent
    supplies `D` (and optionally `M`) exactly;
  - versions other than the one pinned in the manifest — "what did 5.x look like" is
    a registry question, not a vendored-artifact question.

### Invariance test

Run against what the frame actually leans on:

| Ground | Verdict | Notes |
|---|---|---|
| Hex release immutability + manifest checksum | **Invariant.** | This is what makes "D@V" a stable identity. Strongest ground in the frame. |
| `manifest.toml` / `packages.toml` schema | **Stable, machine-written.** | Owned by the Gleam build tool, which has a 1.0 backward-compatibility commitment (2024). Observable: a schema change would show as a parse failure of a local file, not a silent wrong answer. |
| `build/packages/<pkg>/src` layout | **Stable in practice, not a documented contract.** | Implementation detail of the build tool, unchanged through 1.x. Moderate-low risk, and *observable*: if it moves, the directory is simply absent and R2 reports it. Compare Gloogle: a third-party host whose state we could neither control nor observe. Different class of risk. |
| Gleam declaration syntax (domain 4) | **Stable core, slowly growing edge.** | `pub fn`/`pub type`/`///` have been stable since 1.0. New attributes or syntax (e.g. `@internal` arrived during 1.x) will appear over time — a moving target, but one that moves slowly, publicly, and *observably*, and R4 makes any miss fail loud rather than silently drop items. |
| Compiler cache formats (`*.cache_meta`) | **Not invariant — excluded.** | Internal, unversioned, build-dependent. Deliberately not used as ground. |
| The agent's prior knowledge of the API | **Not a target of this frame.** | Worth stating because it was the disqualifier for structural search in the elm-docs-mcp analysis. Here the requirement is stated against the on-disk artifact (R1), which is correct and useful *regardless* of what any model knows; the tool is no more "aimed at hallucination" than `cat mist.gleam` was. The model-knowledge gap is the *occasion* for the incident, not the *specification* of the fix. |

**Result: passes.** Every ground the frame stands on is either invariant, or moves
slowly and observably in a way that surfaces as a loud local error rather than a
plausible wrong answer.

### Stakeholder test

The proposal is not an analogy transfer — it is a direct transcription of the
originating stakeholder's own workaround (read the file under `build/packages`). So the
originating stakeholder *is* our stakeholder. To be thorough, the nearest established
pattern is `go doc` (and `cargo doc`, `elm-docs` on local packages): a developer at a
terminal asks for the public surface of a package they already have on disk, reads it,
uses it, and does not need to retain it — a **per-lookup, non-accumulating** stakeholder
shape. That matches a stateless agent well. This is the opposite of the Hoogle case,
whose originating stakeholder was a *learning* human building vocabulary over years,
which is why that analogy failed to transfer and this one does.

One strain, named rather than papered over: for a filesystem-capable client the tool is
a convenience over `Read`, not a new capability (domain 5). That is fine — `go doc` is
also a convenience over `cat` — but it means the tool's value is measured in *location,
condensation, and identity*, and the requirements above are written to deliver exactly
those three.

**Result: passes.**

### Open questions — decided here, with reasoning

1. **Dependency omitted, module given** (e.g. just `gleam/http/request`)?
   Gleam enforces unique module names across a project's package set, so a
   module-only lookup is well-defined and could be resolved by scanning the manifest.
   *Decision for v1:* dependency name required, module optional. It keeps the identity
   `D@V` explicit in the request, mirrors the incident exactly, and avoids a scan.
   Module-only lookup is carried forward as a possible relaxation, not a requirement.
2. **`@internal` items.** Public to the compiler, hidden from generated docs.
   *Decision:* exclude them by default, matching what `gleam docs` shows the human,
   and state the count excluded so nothing is silently hidden. Carried forward: an
   opt-in to include them, if a real need appears.
3. **`gleam.toml` and `manifest.toml` disagree** (user edited `gleam.toml`, hasn't run
   `gleam` yet). *Decision:* the manifest wins — it is what is actually on disk. The
   result already states `V`, so the agent can see the discrepancy if it matters.
4. **Default `project_path`.** `"."`, consistent with the existing local tools.
5. **Result format (Markdown vs JSON).** Out of scope per the handoff; tracked
   separately as a cross-server consistency question.

### Deferred, not resolved

- Whether the user's *own* modules should get the same public-surface treatment (a
  `list_local_modules` upgrade). Different domain (live, human-edited, no identity),
  therefore a different frame; not decided here.
- Parser choice (hand-parse vs. shell out to `gleam` tooling). Specification-level;
  the only requirement-level constraint on it is R4 (fail loud per file) and the
  invariance note on domain 4.

### Field observations recorded in passing (out of scope, logged for accuracy)

Verified 2026-08-25 while gathering ground truth; neither changes this frame:

- **Hex search:** `GET /api/packages?search=mist` *does* return `mist` — at position
  11 of 21 in Hex's alphabetical ordering; `hex.gleam` keeps the first 10. So the
  package is dropped by the tool's cap, not omitted by Hex. `search=name:mist`
  returns exactly `[mist]`. Hex does not filter by build tool via search (`build_tools`
  is per-release, not indexed). Tracked separately.
- **Gloogle:** `api.gloogle.run` resolves today (Render/Cloudflare edge) but the TLS
  handshake fails at that edge; `gloogle.run` itself serves 200. So the failure is at
  the service, not DNS — the issue's `nxdomain` was one of two errors httpc reported.
  Tracked separately; not reopened here.

### Open items carried to next pass

- Verify on-disk layout for git-sourced dependencies under `build/packages` and how
  their ref is recorded in the manifest (domain 1 edge case).
- Module-only lookup (open question 1) and `@internal` opt-in (open question 2) —
  revisit only on demonstrated need.
- Next reassessment trigger: adding the tool (a new machine boundary — a new local
  read path) is itself the trigger; the entry after implementation should record
  whether R2/R4 held up in a real session.

## Addendum to Entry #1 — 2026-08-25 — Post-implementation

`get_dependency_api` landed in commit `7031a78`. This is the reassessment the entry
named as its own trigger: a new machine boundary (a local read path into
`build/packages` and `manifest.toml`). Checked against the shape test — did the
*problem* change, or just the code? — the answer is: no domain, frame, or requirement
changed. What follows is evidence and three refinements the implementation forced
into the open.

### What held

- **Domains as characterised.** The manifest was sufficient as the sole identity
  authority; `packages.toml` was not needed (directory presence under
  `build/packages` answered "fetched?" directly). Hex entries carry `version`, git
  entries carry `commit`; path entries carry `source = "local"` and are refused as
  designed. No case arose where domain 1 and domain 2 disagreed.
- **R2 (never fetch)** is structural: the module imports no HTTP client and no
  command runner. The three precondition failures (absent / unfetched / path dep)
  are distinct errors naming the user's `gleam` command.
- **R3 (transitive in scope, directness reported)** — `[dependencies]` and
  `[dev-dependencies]` both count as direct; a transitive package gets an
  `import_note` field.
- **R4 (fail loud, never partial)** is implemented as a per-declaration
  "unterminated" error naming `file:line`. Evidence on real code: sweeping all 43
  `.gleam` files vendored under this repo's own `build/packages` produced zero
  extraction failures, and on every file `items + internal_omitted` equalled the
  `grep -c '^pub '` count. So the loud path exists and is tested against a fixture,
  but has **not yet fired on a real package** — which is the intended steady state,
  not evidence that it never will. The invariance note on domain 4 (syntax grows
  slowly; misses fail loud) stands unchanged.
- **Open questions 1–4** were implemented as decided (dependency required, module
  optional; `@internal` omitted with a count; manifest wins over `gleam.toml`;
  `project_path` defaults to `.`).

### Refinements the implementation surfaced

1. **Open question 5 (format) is resolved for this tool: JSON.** Two reasons, one of
   which is a genuine domain observation. (a) The result is structured data —
   identity fields plus an array of `{kind, name, signature, docs, deprecated}` —
   and the stakeholder (domain 5) is a program. (b) Package doc comments are
   themselves Markdown, and routinely contain headings (`## Examples` in
   `gleam_json`, `gleam_stdlib`). Rendering them verbatim inside a Markdown response
   embeds one document in another and inverts the heading hierarchy. In JSON the
   docs are an opaque string field and cannot collide with the response's own
   structure. This is a property of the lexical domain the entry did not anticipate:
   the doc comments are not plain text, they are a second markup layer. The other
   six tools remain Markdown; cross-server consistency is still the separate item.

2. **An implicit requirement made explicit — R6, containment.** The agent supplies
   `dependency` and `module` as strings, and both become filesystem path components
   under `build/packages`. Without validation, `module = "../../src/secret"` reads
   outside the vendored domain entirely — a read of the user's live project or
   beyond, through a tool whose whole contract is "domain 1 only". The entry's scope
   boundary (R5: not the user's own modules) implied this but never stated it as a
   machine-boundary constraint. Stated now: **the machine shall never read a path
   outside `build/packages/<D>/src` for any input.** Implemented as a strict name
   grammar (lowercase, digits, underscore; `/` permitted in module names only, no
   `..`, no leading/trailing/double slash) with tests for traversal in both
   arguments. This is the same class of concern as the safe-core's "paths are data,
   never shell" rule, and belongs alongside it.

3. **One deliberate, marked elision, in tension with R4's wording.** `pub const`
   values that span lines are cut at the first line and marked with `…`
   (`pub const items = [ …`). R4 says "never partial", but its target is the
   *surface* — names, types, signatures, docs — and a constant's value is not part
   of its interface; its name and type annotation are. The elision is visible in the
   output, not silent, which is the property R4 actually protects. Recorded so a
   later reader doesn't mistake it for a bug or a violation.

### Git dependencies: verified against the real build tool (same day)

A scratch project with `filepath = { git = "…", ref = "v1.1.2" }` was resolved by
`gleam deps download` (Gleam 1.18.1). Confirmed: the manifest entry carries
`source = "git"`, `repo`, and `commit`; the checkout lands at
`build/packages/<name>/` with the same `src/` layout as a Hex package; the tool
reads it and reports the commit as `version`. The git-dep item is closed.

The same check found the **first real crack in a domain characterisation**, in
domain 6 (the user's `gleam.toml`): Gleam accepts two spellings for the
dev-dependency table, `[dev-dependencies]` (older projects, this repo) and
`[dev_dependencies]` (what `gleam new` writes today). The tool, and the
pre-existing `list_dependencies`, only knew the hyphen form — so on any freshly
scaffolded project a dev dependency was reported as *transitive* with a spurious
"run `gleam add`" note. That is a direct R3 failure: the directness fact is the one
thing R3 exists to get right. Both tools now accept both spellings, with tests.
Lesson for the domain list: a lexical domain can encode one fact in more than one
surface form, and a fixture written from memory of one form will not catch the
other. Verification against the real producer of the artifact (here, `gleam new`)
is what surfaced it.

### Still open (unchanged from the entry)

- "Did R2/R4 hold up in a real session" — no real session yet. The next field use of
  the tool by an agent is the evidence this item is waiting for.
- Module-only lookup and an `@internal` opt-in: no demand yet.
