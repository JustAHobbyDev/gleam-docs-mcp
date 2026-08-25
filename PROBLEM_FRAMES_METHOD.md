# PROBLEM-FRAMES-METHOD.md

A project-agnostic guide to running a Problem Frames analysis before implementing a new tool, feature, or architectural change. Extracted from practice developed on `elm-docs-mcp` (see that project's `PROBLEM_FRAMES.md` for a fully worked example — useful as precedent, but its domains and frames are specific to that project, not templates to copy directly).

## Why do this before writing code

Requirements live in the world (the domains), not in the machine you're building. Deciding what to build before naming the domains and how they relate tends to smuggle in unexamined assumptions that get expensive to unwind later. This method exists to surface those assumptions while they're still cheap to change.

## Core vocabulary (Jackson's Problem Frames)

- **Domain**: something in the world the machine has to interact with. Characterize each domain by its nature:
  - *Biddable* — can be asked to behave a certain way but might not comply (typically people, or systems people control directly).
  - *Causal* — behaves according to fixed, predictable rules (a compiler, a physical process, deterministic software).
  - *Lexical* — a physical representation of data (a file, a data structure) — often the result of some other domain's causal or biddable behavior, frozen into a readable form.
  - Domains can shift character depending on framing — e.g., a fetched artifact is lexical once fetched, even if the thing that produced it was biddable.
- **The machine**: the thing you're building. It sits between domains, observing and/or controlling them to bring about some required condition in the world.
- **Requirement**: a statement about the world (the domains) the machine should help achieve — not a statement about the machine's internals. "The agent shall receive an answer that correctly reflects X's actual state" is a requirement. "The tool shall use a stateless HTTP client" is a specification (a design decision downstream of a requirement) — useful, but not the same thing, and shouldn't be decided before the requirement is named.
- **Frame**: a recognizable *shape* of problem — a stock configuration of domains and the machine's relationship to them. Common shapes worth knowing:
  - *Information Display* — read a domain, present what it says. Low risk, no side effects.
  - *Workpieces* — a live, mutable domain the machine helps a user work on. Higher risk — staleness or a bad read can actively mislead, not just under-inform.
  - *Transformation* — the machine derives a new (often lexical) domain from an existing one, batch-style.
  - Not every problem fits a named shape cleanly — say so explicitly rather than forcing a fit. Vocabulary built for human users may strain when the actual stakeholder is a program (an agent) rather than a person; name that strain rather than paper over it.

## The actual procedure

1. **List every domain the machine will touch.** For each: what is it, what's its nature (biddable/causal/lexical), who authors or controls it, and — critically — is it read-only from the machine's perspective or can the machine change it. Explicitly separate any domain the *machine itself* creates or owns (a cache, an index, derived state) from domains that exist independently in the world. Conflating these is a common, costly mistake.

2. **Propose a frame split.** Group domains + the machine's relationship to them into recognizable shapes. It's fine, and common, for one proposed feature to actually split into two or more frames once examined — don't force a single frame if the shapes genuinely differ (e.g., "build an index" and "query an index" are usually two different frames, not one, even though they feel like one feature).

3. **State a requirement per frame**, in world-level terms, not machine-level terms. Be precise about what's explicitly *out* of scope — stating what a frame does NOT cover is often as useful as stating what it does, since it prevents scope creep back in through a related-sounding but different frame later.

4. **Run the standing tests before committing to a frame:**
   - **Invariance test**: does this frame lean on an interface, fact, or capability that's genuinely stable — or does it target something that moves independently of you and that you have no reliable way to observe (e.g., a model's current knowledge, a third party's infrastructure uptime, a person's future behavior)? A frame built against a moving, unobservable target is weak ground regardless of how plausible the use case sounds.
   - **Stakeholder test**: if you're borrowing a pattern from an existing tool or analogy, check whether its actual originating stakeholder matches yours. A pattern built for a human who learns and retains discoveries over time doesn't automatically transfer to a stateless, per-call agent stakeholder (or vice versa) — check the analogy's own history/origin rather than assume the shape transfers because the surface problem looks similar.

5. **Surface open questions explicitly rather than deciding them silently.** Small-sounding defaults (what happens if no version is specified; is an error a successful or failed call; how is a corpus curated) are requirement decisions, not implementation details, and deserve a stated answer with reasoning — even one sentence — rather than being left to whatever the first implementation happens to do.

6. **Write it up as a dated, numbered entry** in that project's own `PROBLEM_FRAMES.md` (create the file if it doesn't exist). Entries should be self-contained enough to diff against later ones — domains, frame split, requirements, explicit invariance/stakeholder check results, open items carried forward.

## Reassessment practice

Re-run this analysis after any change that:
- adds or removes a domain,
- splits or merges a frame,
- changes what crosses a machine boundary (a new external call, a new tool, new persisted state).

Routine implementation work *inside* an existing, unchanged frame does not need a re-pass. The test: did the *shape* of the problem change, or just the code that solves it?

Log each reassessment as a new dated entry (or an addendum to an existing one, if nothing about the domains/frames actually changed and you're only recording new evidence). Don't silently edit old entries — the point of dating them is to make the evolving shape of the problem visible over time, including when earlier reasoning turns out to have been based on thinner evidence than assumed.

## A worked precedent

See `elm-docs-mcp`'s `PROBLEM_FRAMES.md`, Entry #1, for a full example applying this method: domain list, a two-frame split (published-registry lookup vs. local-project introspection), a third candidate frame proposed and rejected (structural type search, rejected on both the invariance test and the stakeholder test against its own analogous tool's origin story), stated requirements with explicit scope boundaries, and an addendum recording later field evidence that reinforced — without needing to re-decide — the original rejection.
