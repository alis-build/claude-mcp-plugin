---
description: Send feedback on an Alis Build skill to its owner. Give the skill's id (optional) and your message.
---

The person wants to send feedback on a Skill store skill. Their words: $ARGUMENTS

1. **Which skill:** the id they named; otherwise the skill loaded with `load_skill` most recently
   in this session; otherwise ask which (offer `search_skills` if they don't know the id).
2. **What to send:** their words as `feedback`, kept as they wrote them (fix nothing but obvious
   typos). If they said it helped or didn't, set `rating` to `up` or `down`; if they gave only a
   rating, send that alone. If they gave nothing, ask in one line how the skill did.
3. **Scrub:** no secrets, tokens or customer data in the feedback; mention a step by its heading.
4. Send with `send_skill_feedback`, then confirm in one line that it reached the skill's owner.
