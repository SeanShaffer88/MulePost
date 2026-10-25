# MulePost — Verification

## v0.1.0 (2026-10-24)

| Check | Result |
|---|---|
| Local gate (`python3 tools/gate.py`): Lua parse (luaparser) for all files | **PASS** (2026-10-24, run by Muse: parse ok ×4, classifier/plan audit 0 problems, money audit clean, version 0.1.0 consistent, harness PASS — all 7 checks) |
| Classifier audit: 5 material subtypes, consumable, junk, other; **Quest → nil at quality 1 AND quality 0** | Gate |
| Plan audit: 13 stacks → 2 mails (12+1), postage 360c/30c | Gate |
| **Money audit: no money-attach/COD call in any source file; `SendMail(` appears only in Send.lua; SetBackdrop only in UI.lua with BackdropTemplate** | Gate |
| Harness: classifier cases incl. both quest exclusions | Harness |
| Harness: rules add/del, bad category refused, 8-rule cap | Harness |
| Harness: route over the mock bag — 7 mails / 8 stacks / 240c, quest item excluded ×1, uncached item skipped ×1, cloth stacks grouped | Harness |
| Harness: review removal updates totals and the Send button count; window renders rows | Harness |
| Harness: send pass — mailbox-gated, exactly one mail in flight, removed mail never sent, sent marks land, pass completes | Harness |
| Harness: MAIL_FAILED stops the pass (next mail never attempted, unsent mail unmarked); away from mailbox, StartSend refuses and nothing leaves | Harness |
| **Live mailbox** | **Unverified** — launches Nov 4, 2026. The mock's mail functions only record calls; real attach/send semantics, postage, and failure behaviour are the spike list in SPEC.md. See CAPTURE.md. |

Labels: Verified / Partially Verified / Unverified. A green gate is
syntax-and-mock proof only, never a runtime claim — doubly so for an
addon that moves items.
