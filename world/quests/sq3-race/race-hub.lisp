(:name race-hub
 :title "Talk to Catherine to start a race"
 :description NIL
 :invariant T
 :condition NIL
 :on-activate (start-race)
 :on-complete NIL)

;; enemies on this quest will be world NPCs, not spawned for the quest
(quest:interaction :name start-race :title "Race against the clock" :interactable catherine :repeatable T :dialogue "
? (or (active-p 'race-one) (active-p 'race-two) (active-p 'race-three) (active-p 'race-four))
| ~ catherine
| | You're already racing, get goin'!
|?
| ~ catherine
| | Alright, let's do this!
| ? (not (complete-p 'race-one))
| | | So Alex has been back, and I got them to plant some old-world beer cans in devious places for you to find.
| | | Grab the can, bring it back here, and I'll stop the clock.
| | | I've been talking to the guys, and we've decided to start you off with Route 1, which is an easy one.
| | | Get bronze or above on a route, and we'll tell you about the next one!
| | | We've also got some riddles for each place; figuring these out might slow you down at first.
| | | But once you know where they are, you'll be clocking even faster times I'm sure! So...
| | < race-1
| |?
| | | Which route do you wanna do?
| | ~ player
| | - Route 1
| |   < race-1
| | - [(var 'race-1-bronze) Route 2|]
| |   < race-2
| | - [(var 'race-2-bronze) Route 3|]
| |   < race-3
| | - [(var 'race-3-bronze) Route 4|]
| |   < race-4
| | - [(var 'race-4-bronze) Route 5|]
| |   < race-5
| | - Back out for now
# race-1
~ catherine
| Route 1! The can is... at a literal high point of EASTERN civilisation, now long gone.
| The time brackets are: Gold: 0:30 - Silver: 0:50 - Bronze: 1:10.
? (var 'race-1-pb)
| | Your personal best for this route is {(format-relative-time (var 'race-1-pb))}.
? (not (complete-p 'race-one))
| ! eval (activate 'race-one)
|?
| ! eval (setf (quest:status (thing 'race-one)) :inactive)
| ! eval (setf (quest:status (thing 'race-one-return)) :inactive)
| ! eval (activate 'race-one)
< end
# race-2
~ catherine
| Route 2! The can is... where a shallow grave marks the end of the line for the West Crossing.
| The time brackets are: Gold: 1:00 - Silver: 1:30 - Bronze: 2:00.
? (var 'race-2-pb)
| | Your personal best for this route is {(format-relative-time (var 'race-2-pb))}.
? (not (complete-p 'race-two))
| ! eval (activate 'race-two)
|?
| ! eval (setf (quest:status (thing 'race-two)) :inactive)
| ! eval (setf (quest:status (thing 'race-two-return)) :inactive)
| ! eval (activate 'race-two)
< end
# race-3
~ catherine
| Route 3! The can is... where we first ventured together, and got our feet wet.
| The time brackets are: Gold: 1:30 - Silver: 2:00 - Bronze: 2:30.
? (var 'race-3-pb)
| | Your personal best for this route is {(format-relative-time (var 'race-3-pb))}.
? (not (complete-p 'race-three))
| ! eval (activate 'race-three)
|?
| ! eval (setf (quest:status (thing 'race-three)) :inactive)
| ! eval (setf (quest:status (thing 'race-three-return)) :inactive)
| ! eval (activate 'race-three)
< end
# race-4
~ catherine
| Route 4! The can is... deep to the west, where people once dreamed.
| The time brackets are: Gold: 2:00 - Silver: 3:00 - Bronze: 4:00.
? (var 'race-4-pb)
| | Your personal best for this route is {(format-relative-time (var 'race-4-pb))}.
? (not (complete-p 'race-four))
| ! eval (activate 'race-four)
|?
| ! eval (setf (quest:status (thing 'race-four)) :inactive)
| ! eval (setf (quest:status (thing 'race-four-return)) :inactive)
| ! eval (activate 'race-four)
< end
# race-5
~ catherine
| Route 5! The can is at... the furthest edge of the deepest cave in this region - there isn't much-room.
| The time brackets are: Gold: 2:00 - Silver: 3:00 - Bronze: 4:00.
? (var 'race-5-pb)
| | Your personal best for this route is {(format-relative-time (var 'race-5-pb))}.
? (not (complete-p 'race-five))
| ! eval (activate 'race-five)
|?
| ! eval (setf (quest:status (thing 'race-five)) :inactive)
| ! eval (setf (quest:status (thing 'race-five-return)) :inactive)
| ! eval (activate 'race-five)
# end
| ~ catherine
| Remember - the faster you are, the more parts you'll get from the sweepstake.
| [? Time starts... Now! | Ready?... Set... Go! | Three... Two... One... Go Stranger!]
")
;; | [(var 'race-1-pb) Your personal best for this route is {(format-relative-time (var 'race-1-pb))}.]
;; TODO: allow play to opt out of first race encountered, not forced
;; TODO: cancel a race in progress? restart a race that's gone wrong? - not sure; it would have to be done by returning to Catherine, not from the UI, to preserve immersion (death is different, but restarting races from UI is fine in a driving game, not in an RPG?)
;; - in which case if have to return to Catherine anyway, is there much point? Just hand the race in anyway and get the fun poor performance dialogue?
;; TODO: acknowledge in the flow when a new route has unlocked?
;; TODO: have a different item per race, e.g. phone, bottle, etc. Need to render them though?
;; TODO bug - deactivating this task causes it's title to appear as another bullet point in the journal (though not deactivating it anymore)
;; TODO: plant multiple objects, encouraging cheating
;; could explain brackets at the start, or let player figure it out themselves from results? Latter

#|



|#
