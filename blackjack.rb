# frozen_string_literal: true

#========================================================================
# Entities
#========================================================================
#
# A Card is what it sounds like it is.
#
# A Session is the entire game, played with a single deck and with the
# same set of players and dealer.
#
# A Player is a person who plays the Games in a Session. The Dealer is
# a special Player, but is a Player nonetheless. To distinguish the
# non-Dealer Players from the Dealer, we will also call them rubes.
#
# A Game is a hand in the sense of "I lost this hand" way, not in a
# "these are my three cards" sense. All the players and dealers play
# separate Hands in each Game.
#
# A Hand is a hand in the sense of "these are my three cards";
# i.e. just a collectin of Cards. A Player usually just has one Hand,
# but may have more if she splits.
#
# A Strategy is an algorithm that any Player (i.e. dealer and rubes)
# uses to make game-time decisions; i.e. hit or stand, split,
# surrender etc. A Player uses the same Strategy throughout the
# Session.

require 'logger'

LOG = Logger.new(STDOUT)
LOG.level = Logger::DEBUG

def log(*args)
  LOG.debug(*args)
end

# Am I doing this right? I feel unclean.
class Array
  def sum
    self.inject(0) { |sum, x| sum + x }
  end
end


module Blackjack

  class BlackjackError < StandardError; end

  def self.combine(seq)
    return [[]] if seq.empty?
    head, *tail = seq
    head.flat_map do |head_val|
      combine(tail).map do |tail_val|
        [head_val] + tail_val
      end
    end
  end


  class Card
    VALUES = %w(A 2 3 4 5 6 7 8 9 10 J Q K).freeze
    FACES = %w(J Q K).freeze
    SUITS = %w(C S A D).freeze

    attr_reader :value, :suit

    class << self
      def deck
        VALUES.map do |v|
          SUITS.map do |s|
            Card.new(v, s)
          end
        end.flatten.shuffle
      end
    end

    def initialize(value, suit)
      @value = value
      @suit = suit
    end

    def inspect
      "#{@value}#{@suit}"
    end

    def ace?
      @value == 'A'
    end

    def face?
      FACES.include? @value
    end

    def point_values
      if ace?
        [1, 11]
      elsif face?
        [10]
      else
        [value.to_i]
      end
    end
  end


  # Hand like this is "a collection of cards", not "I fold this hand".
  class Hand
    attr_reader :player, :cards

    def initialize(player)
      @player = player
      @cards = []
    end

    def to_s
      "<Hand #{@cards.to_s}>"
    end

    def take_card(card)
      @cards << card
    end

    # The possible values of the hand
    def values
      Blackjack::combine(@cards.map(&:point_values)).map(&:sum)
    end

    # Kinda weird: we ask the hand how it wants to be played, but
    # of course it's actually the player strategy that determines
    # this.
    def decide
      @player.decide(self)
    end

    def blackjack?
      @cards.size == 2 && values.max == 21
    end

    def busted?
      values.all? { |v| v > 21 }
    end
  end


  class Strategy
    # Strategies have a hook to the session so they
    # can see other players' cards, can card count, etc.a
    def initialize(session)
      @session = session
    end

    def decide(hand)
      raise NotImplementedError.new("Strategy#decide")
    end
  end


  class BasicStrategy < Strategy
    def decide(hand)
      log("bs decide: #{hand}")
      values = hand.values
      log(" values: #{values}")
      if values.detect { |v| v >= 16 }
        log(" standing >= 16")
        :stand
      else
        log(" hitting on < 16")
        :hit
      end
    end
  end


  class Player
    attr_reader :session, :name, :hands

    def initialize(session, name)
      @session = session
      @name = name
      @strategy = BasicStrategy.new(session)
      new_hand
      log "pi: ch:#{@cardhand}"
    end

    def new_hand
      @hands = [Hand.new(self)]
    end

    def hand
      return @hands.first if @hands.size == 1
      raise BlackjackError.new(
              "Player#hand can only be called when there's one hand, size was #{@hands.size}")
    end

    # Decide how to play a particular hand
    def decide(hand)
      @strategy.decide(hand)
    end

  end


  class Session
    attr_reader :dealer, :rubes, :deck

    def initialize(rube_qty: 1)
      @deck = Card.deck
      @dealer = Player.new(self, "Dealer")
      @rubes = rube_qty.times.map do |ix|
        Player.new(self, "Rube #{ix}")
      end
    end

    def deal_card(hand)
      log "deal_card: h:#{hand}"
      hand.take_card(@deck.pop)
    end

    def game
      Game.new(self)
    end
  end


  # "Hand" like "I won this hand", not "My collection
  # of cards at the moment."
  class Game
    def initialize(session)
      @session = session
    end

    # All the rubes' hands in the session
    def rube_hands
      @session.rubes.flat_map(&:hands)
    end

    def deal
      log('deal')
      2.times do |_|
        @session.deal_card(@session.dealer.hand)
      end
      rube_hands.each do |hand|
        2.times do |_|
          @session.deal_card(hand)
        end
      end
    end

    def play
      log("psj: Blackjack.deck::Game.play play: play")
      deal
      return wins(@session.dealer) if @session.dealer.hand.blackjack?
      rube_hands.each do |hand|
        run_rube_hand(hand)
      end
    end

    def run_rube_hand(hand)
      puts "run_rube_hand: #{hand}"
      loop do
        decision = hand.decide
        case decision
        when :stand
          return :stand
        when :hit
          @session.deal_card(hand)
          return :busted if hand.busted?
        else
          raise BlackjackError.new("Unknown decision: #{decision}")
        end
      end
    end
  end
end
