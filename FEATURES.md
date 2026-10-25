# MulePost — Features

## Routing rules (v0.1.0)
- Up to 8 rules: item category → character name, stored in SavedVariables, managed by `/mp rule add|del` and `/mp rules`.
- Categories: cloth, herb, ore ("Metal & Stone"), leather, enchanting materials, consumables, junk (poor quality), other. First matching rule wins; the `other` rule is the fall-through.
- Classification reads the item's own type/subtype names via `C_Item.GetItemInfoInstant` — the same words the client prints on the tooltip — instead of numeric subclass tables that vary by class and build.

## The plan (pure function — building it sends nothing)
- Bag scan over bags 0..NUM_BAG_SLOTS via `C_Container`; stacks grouped by recipient in rule order; chunked into mails of at most **12 stacks** (the game's attachment limit).
- Postage **estimate** at 30c/stack, always labelled an estimate; plan totals (mails / stacks / postage) computed live as you edit.
- Honest accounting in chat and window: unrouted stacks, excluded quest items, and not-yet-cached items are each counted and reported — never silently dropped.
- **Quest-class items are never routed** — the classifier returns nil for them before quality or subtype are even considered (a grey quest item is excluded too; the gate tests both).

## Review window (mandatory)
- Every mail is a row: recipient, stack count, estimated postage, first item names — with a per-mail **remove/restore** toggle.
- The Send button states its mail count and updates as you edit. The postage guard warns in red when the plan's total estimate exceeds your cap (`/mp cap`, default 1g).

## Send executor (event-driven, fail-stopped)
- Runs only at a mailbox (`MAIL_SHOW` state) and only on your Send press.
- One mail at a time: attach its stacks, `SendMail`, then **wait for `MAIL_SEND_SUCCESS`** before touching the next. `MAIL_FAILED` stops the pass instantly — the rest stay in your bags and in the plan. `MAIL_CLOSED` mid-pass aborts. No timers, no blind retries.
- Successfully sent mails are marked in the plan; removed mails are skipped.

## The gold guarantee (structural)
- There is no money-attach or COD call **anywhere in the source**, and `SendMail` is callable only from `Send.lua`. The gate fails the build if either invariant breaks. Gold cannot be attached because the code to do it does not exist.

## Deliberately not features
- No inbox reading/sorting, no auto-send, no send-on-open, no auction house anything, no cross-account mail, no money handling of any kind.
