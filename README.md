# MulePost

## TL;DR

MulePost is a World of Warcraft: Forever mailbox addon for anyone with crafting alts and a bank alt. You teach it your routing once — cloth → your tailor, herbs → your alchemist, ore → your miner, greys → your bank alt — and from then on, a mailbox visit is: open the mail, click **Route my bags**, read the plan, click **Send**. The plan groups your bags into mails of up to 12 stacks per recipient with an estimated postage total and a guard that warns when a plan's postage exceeds a cap you set. **Nothing ever sends without the review screen and your Send press** — there is no auto-send mode and there never will be. And the gold promise is structural, not a setting: the addon contains *no code path that can attach money or set a COD* (the build gate greps the source to prove it), quest items are never routed, and items whose data the client hasn't cached yet are skipped and counted out loud instead of guessed at.

See also: `FEATURES.md`, `DESCRIPTION.md`, `CHANGELOG.md`, `docs/SPEC.md`, `docs/VERIFICATION.md`.

## Setup (once)

```
/mp rule add cloth Tailoralt
/mp rule add herb Alchalt
/mp rule add ore Minertalt
/mp rule add junk Bankalt
/mp rule add other Bankalt
```

Up to 8 rules; first match wins, and the `other` rule catches whatever no specific rule claims. Categories: `cloth`, `herb`, `ore` (the client's "Metal & Stone"), `leather`, `enchanting`, `consumable`, `junk` (grey items), `other`.

## Commands

`/mp` review window · `/mp route` scan + plan · `/mp rules` · `/mp rule add <category> <character>` · `/mp rule del <n>` · `/mp cap <copper>` / `/mp cap off` postage guard · `/mp debug`

## Install

Unzip so the `MulePost` folder sits in your WoW: Forever client's `Interface/AddOns/` folder. Forever only (interface 16001).

## Honest limits

- **v0.1.0 is a pre-launch build.** Local gate green, but it has **not run at a live mailbox** — Forever launches Nov 4, 2026, and the mail API surface (namespaced vs legacy send functions, real postage via the send frame, bag-slot stability across a pass) is spike-list item #1 in `docs/SPEC.md`.
- Postage in the plan is an **estimate** (30c per stack, the classic schedule), labelled as such everywhere it appears. The mailbox has the final word.
- Items the client hasn't cached data for yet are skipped and counted ("not-yet-cached: N") — running Route again usually clears them.
- Classification keys off the item type names the client itself displays ("Trade Goods / Cloth / Herb / Metal & Stone / …"). If the live build localizes or renames a subtype, that category falls through to `other` rather than misfiring — visible in the plan, fixable in one data commit.
- Party trick it will never do: touch your inbox, attach gold, send unreviewed, or work away from a mailbox.

## Screenshots

From real runs only, after launch (`docs/screenshots/CAPTURE.md`). No placeholders.

## License

MIT — see `LICENSE`.
