# Changelog

## 0.1.0 — 2026-10-24 (pre-launch)

First build, for WoW: Forever (Interface 16001) only.

- Routing rules (max 8, SavedVariables): category → character, first match wins, `other` as fall-through. Categories: cloth, herb, ore (Metal & Stone), leather, enchanting, consumable, junk, other.
- Classifier on the client's own displayed type names (`C_Item.GetItemInfoInstant`), not numeric subclass tables. **Quest-class items classify to nil — never routed — checked before the grey/junk rule**; uncached items are skipped and counted.
- Pure plan builder: stacks grouped by recipient, chunked at the 12-stack attachment limit, postage estimated at 30c/stack and labelled an estimate everywhere (`CopperText` totals; `/mp cap` guard, default 1g, warns on plan totals).
- Review window (BackdropTemplate, opaque WHITE8x8): per-mail rows with remove/restore, live totals, a Send button that states its count. Nothing sends from anywhere else.
- Event-driven send executor: mailbox-gated, one mail in flight, advances only on `MAIL_SEND_SUCCESS`, halts on `MAIL_FAILED` (remaining mails stay in bags + plan) and on `MAIL_CLOSED`; sent mails marked in the plan.
- **Gold guarantee by construction:** no money-attach or COD call exists in the source, and `SendMail` appears only in `Send.lua` — both enforced by the gate's source audit.
- Local gate green (parse + TOC + classifier/plan audit incl. both quest-exclusion cases and 12-stack chunking + money audit + version consistency + mocked-API harness covering rules, routing, review edits, the full send pass, the failure stop, and the away-from-mailbox refusal). **Runtime at a live mailbox is Unverified** — Forever launches Nov 4, 2026; see docs/VERIFICATION.md.
