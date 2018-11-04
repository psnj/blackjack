# Blackjack

This is a simple program that plays Blackjack with itself. The idea is
that this will be a tool to do Monte Carlo simulations with various
pluggable playing strategies. None of this is new, really.

## Entities

 * A Card is what it sounds like it is.

 * A Session is the entire game, played with a single shoe and with the
   same set of players and dealer.

 * A Player is a person who plays the Games in a Session. The Dealer
   is a special Player, but is a Player nonetheless. To distinguish
   the non-Dealer Players from the Dealer, we will also call them
   rubes.

 * A Game is a hand in the sense of "I lost this hand" way, not in a
   "these are my three cards" sense. All the players and dealers play
   separate Hands in each Game.

 * A Hand is a hand in the sense of "these are my three cards";
   i.e. just a collectin of Cards. A Player usually just has one Hand,
   but may have more if she splits.

 * A Strategy is an algorithm that any Player (i.e. dealer and rubes)
   uses to make game-time decisions; i.e. hit or stand, split,
   surrender etc. A Player uses the same Strategy throughout the
   Session.
