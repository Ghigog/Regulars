# PRD 2: The critic

**Size:** medium. **Needs:** PRD 1 (recipes and menu) for the quality and variety
ratings. **Touches:** new `sim/critic.gd`, `sim/town.gd`, `game/main.gd`, `game/hud.gd`
(newspaper clipping, town book, guest card), `game/icons.gd`, tests.

## Goal

Every fifth day one townsperson, the same one all run, eats as a critic. They rate four
things, give stars out of 5, and the review is printed in the paper. The review confirms
or contradicts the rumours going round, replaces what the town thinks about the four
things it rated, and moves how many guests come over the next days.

## Decided

- One critic per run, picked at the start, always the same person in that run.
- They visit every fifth day (5, 10, 15 ...). Every day is a working day; there are no
  weekends.
- They are served like anyone else.
- They rate **speed, cleanliness, food quality and variety**, then give stars out of 5.
- The review resets townspeople's opinions on those four things **and only those**:
  someone put off by dirt forgets it if the critic found the place clean.
- A good review brings more guests (which can backfire on a kitchen that is not ready);
  a bad one keeps them away.
- **Delivery:** a newspaper clipping shown with that night's receipt.
- **Identity:** unknown until the first review. The first review names them, so every
  later visit is a known, high-stakes table.

## How it works today

- `sim/town.gd`: each person has one `affinity` (-1 to 1) that sets their chance to
  visit. `record_visit`, `record_walkout`, `record_disgust` and `record_kindness` move
  it, and 40% of a change spreads to friends (`FRIEND_SHARE`). `roll_guests(day, boost)`
  picks who comes; flyers add a boost.
- There is no record of *why* someone's affinity is what it is. The critic needs one.

## Requirements

### 1. Opinions by topic (`sim/town.gd`)

1. Each person keeps a small opinion for each of four topics: `speed`, `clean`,
   `quality`, `variety`, each -0.25 to 0.25 (*tunable*), starting at 0. Everything else
   (kindness, walkouts, regular streaks, friends) stays in a fifth part, `other`.
2. Affinity becomes the clamped sum of the five parts. Existing behaviour and the
   existing tests must not change for a town that has had no review: the split is
   bookkeeping until a review lands.
3. Each existing change is filed under a topic: disgust under `clean`; the patience part
   of a visit under `speed`; the savour part under `quality`; liking or missing things
   on the menu (PRD 1) under `variety`; the rest under `other`. Where a visit moves
   affinity by one number today, split it in proportion to the satisfaction terms.
4. Spreading to friends keeps the topic.

### 2. The critic (`sim/critic.gd`, pure)

5. Chosen from the town with the run's seed. Exposed as `critic_idx`.
6. On a critic day they always come: they skip the visit roll, ignore grudges, and are
   not turned away by the menu (the "nothing I like, walk on" rule in PRD 1 does not
   apply; they order the best match the menu has). They come alone, at a time in the
   middle half of the day, picked with the seed.
7. **Ratings**, each a whole number 1 to 5, from the critic's own visit:
   - *Speed*: their patience when the tray arrives. 5 at 0.85 and up, then 0.7, 0.5, 0.3
     for 4, 3 and 2; below that, 1.
   - *Cleanliness*: their felt disgust when they leave. 5 if they noticed nothing, 4
     below the Ick stage, then one star lost at each of Ick, Disgusted and Revolted.
   - *Quality*: the average quality (0 to 1) of what was on their tray, mapped evenly
     onto 1 to 5.
   - *Variety*: from tonight's menu. One point for each course that has at least one
     item (up to 3), one more if any course has three or more items, one more if the
     menu uses at least eight different ingredients. Minimum 1.

   All thresholds *tunable*, as constants.
8. **Stars** are the mean of the four, rounded to the nearest whole star.
9. **If the critic walks out** (ran out of patience, or left revolted): speed 1, the
   other ratings from what they saw, and stars capped at 2.
10. **If the door is closed early** before they arrive, they come the next day instead.

### 3. What the review does

11. **Resets the four topics for everyone.** Each person's opinion on a topic is
    replaced by `(rating - 3) x 0.1` (*tunable*): 5 stars gives +0.2, 1 star gives -0.2.
    `other` is not touched.
12. **Confirms or contradicts.** Before the reset, compare the town's average opinion on
    each topic with the rating. The clipping uses one written line for the largest gap,
    such as "Whatever you have heard about the washing-up, we found it spotless", or,
    where they agree, "As the town already says, you will wait for your supper."
13. **Moves the crowd.** For the next four days `roll_guests` gets an extra boost by
    stars: 5: +0.25, 4: +0.10, 3: 0, 2: -0.10, 1: -0.25 (*tunable*). It stacks with
    flyers. It ends when the next review lands.
14. **Grudges and "never coming back" stay.** Someone who was revolted and swore off the
    place is not brought back by a clean review. See "Open".

### 4. What the player sees

15. **The clipping** arrives with the receipt at the end of a critic day: a newspaper
    cutting in the paper style, with a headline picked by stars, the four ratings each
    with its own icon and a row of pips (shape, not only colour), the stars, and the
    confirm-or-contradict line. It is dismissed like the receipt.
16. **The byline.** The first review is signed with the critic's name and their peg
    portrait: that is the reveal. Later reviews are signed the same way.
17. **After the reveal**, the critic has a small mark (a quill or a newspaper icon) in
    the town book and on their guest card. Before the reveal nothing marks them, and
    nothing in the interface hints at who it is or that today is a critic day.
18. **Their thoughts.** The critic has a few thoughts of their own in the usual log
    ("Making a note of that sink"). These are visible on the guest card before the
    reveal too: a sharp player can work it out. That is intended.
19. **Past reviews** can be read again from the town book: the last clipping is enough.

## Out of scope

- More than one critic, rival critics, or bribing the critic.
- A stars-based lose condition.
- Any change to the three-walkouts rule.

## Tests (`test/unit/test_sim.gd`)

- With no review, affinities after a scripted set of visits match today's values
  exactly (the topic split changes nothing by itself).
- The critic is the same person for a seed, and comes on days 5 and 10 and not 4 or 6.
- Each rating at its thresholds; stars are the rounded mean; a walkout caps stars at 2.
- After a review, a person with a bad `clean` opinion and a 5 for cleanliness holds
  +0.2 on `clean`; their `other` part is unchanged.
- The visit boost applies for four days and then stops; it stacks with flyers.
- A revolted person who swore off the place still does not come after a clean review.

In `test_game.gd`: the receipt on day 5 carries a clipping; on day 4 it does not; the
critic is unmarked on day 4 and marked on day 6.

## Demo and done

- `REGULARS_DEMO=critic`: the receipt of day 5 with a clipping (one good, one bad:
  `critic` and `critic_bad`); `critic_known` for a marked guest card after the reveal.
- `docs/DESIGN.md`: move "The critic" from section 9 to section 1.
- `docs/STYLE_GUIDE.md`: note the clipping under "As built".

## Open, with defaults

Taken as built, 13 November 2026: all three defaults below (no, no, no effect). Two
more calls the build needed, neither a gameplay rule elsewhere: a critic who walks out
before eating rates food 1; and a critic put off by an early close comes the next day,
after which visits return to the fives (a day-6 visit is followed by day 10).

- **Should a clean review bring back people who swore never to return?** Default: no.
- **Should a critic day get its own music cue or door bell after the reveal?** Default:
  no; the mark on the guest is the only signal.
- **Critic and co-op or deals:** a half price or free meal for the critic works as for
  anyone and does not change the ratings. Default: no effect on the review.
