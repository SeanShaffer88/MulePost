# Screenshot + field-test list — real runs only

From SEAN's machine on the live WoW: Forever client (after Nov 4,
2026). Use a throwaway character and low-value items for the first
live pass — this addon moves real items.

1. `review-plan.png` — the review window at a real mailbox with a
   multi-recipient plan showing, one mail marked removed.
2. Field check (no screenshot): send a 2-mail plan to your own alt
   and confirm both arrive intact, correct items, and that postage
   charged matches the estimate — note any difference; the estimate
   gets replaced by the real price if the send frame exposes it.
3. Field check: `/mp debug` shows `atMailbox=true` at the mailbox
   and `false` away from it; StartSend away from a mailbox refuses.
4. Field check: send to a deliberately wrong/full recipient if the
   game offers a failure case — confirm the pass stops and the
   remaining mail is still in your bags.
