# AGENTS.md

Guidance for agents working in this repository.

## Principles

- Read the existing code before changing it.
- Keep changes small, focused, and easy to review.
- Follow the repository's current style and conventions.
- Prefer simple fixes over new abstractions.
- Do not rewrite unrelated code.

## Verification

- Run the most relevant tests or build command after meaningful changes.
- Use `scripts/build-and-launch.sh` when changes need an end-to-end app launch,
  simulator install, or screenshot verification.
- If verification cannot be run, explain why.
- Mention what changed and what was checked in the final response.
