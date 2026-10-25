# MulePost — Build Spec (v0.1.0)

The full five-addon spec bundle lives with the project records as
`wow-forever-addon-specs-all-five.md`. Summary of what shipped:

**Client:** Forever only, Interface 16001. Bag + mail-send surfaces
only; no inbox access at all.

**As built:** rules engine (8 categories, first-match, `other`
fall-through); pure plan builder (12-stack chunking, labelled
postage estimates, unrouted/excluded/uncached accounting); mandatory
review window with per-mail remove/restore and a postage guard;
event-driven executor that sends one mail per `MAIL_SEND_SUCCESS`
and halts on any failure; the gold guarantee enforced structurally
and audited by the gate on every build.

**Design choices worth knowing:** classification keys off the
client's displayed type *names* via `GetItemInfoInstant`, not
numeric subclass IDs — the numeric tables differ per item class and
are a spike item, while the names are what players see and what a
review screen can show. The executor assumes sending removes only
the attached stacks and bag slots do not compact mid-pass.

**Spike list (live build, in order):** (1) confirm the send surface
on 16001 — global `SendMail` vs a namespaced equivalent, and
`PickupContainerItem` + `ClickSendMailItemButton` behaviour;
(2) real postage from the send frame (`GetSendMailPrice`) vs the
30c/stack estimate — replace the estimate with the real price if the
frame exposes it per-mail; (3) bag-slot stability across a multi-mail
pass; (4) `MAIL_FAILED` semantics (does a partial attach roll back?);
(5) `GetItemInfoInstant` return order on this build.

**Kill criterion:** if the live build restricts mail automation
beyond one confirmed mail at a time (e.g. hardware-event-per-send),
the executor degrades to "prepare the send frame for the next mail"
(one click per mail, still planned and reviewed) — it never works
around a client restriction.
