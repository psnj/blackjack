q# frozen_string_literal: true

require 'pp'

#========================================================================
# Entities
#========================================================================
#
# A Card is what it sounds like it is.
#
# A Session is the entire game, played with a single shoe and with the
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

DECKS_IN_SHOE = 500

def log(*args)
#  LOG.debug(*args)
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
    SUITS = %w(C S H D).freeze

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

    def inspect
      "<Hand #{@cards.to_s}>"
    end

    def take_card(card)
      @cards << card
    end

    # The possible values of the hand
    def values
      Blackjack::combine(@cards.map(&:point_values)).map(&:sum)
    end

    # Max non-busted value
    def max_value
      values.select { |v| v <= 21 }.max
    end

    # Kinda weird: we ask the hand how it wants to be played, but
    # of course it's actually the player strategy that determines
    # this.
    def decide
      @player.decide(self)
    end

    def blackjack?
      @cards.size == 2 && max_value == 21
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
    attr_reader :dealer, :rubes, :shoe

    def initialize(rube_qty: 1)
      @shoe = DECKS_IN_SHOE.times.flat_map { Card.deck }
      @dealer = Player.new(self, "Dealer")
      @rubes = rube_qty.times.map do |ix|
        Player.new(self, "Rube #{ix}")
      end
    end

    def deal_card(hand)
      next_card = @shoe.pop
      raise BlackjackError.new("Game over") if next_card.nil?
      hand.take_card(next_card)
    end

    def game
      Game.new(self)
    end

    # Play until the shoe is exhausted
    def play_until_end
      begin
        results = []
        loop do
          result = game.play
          results << result.values
        end
      rescue BlackjackError
        puts "game over"
      end
      agg = results.group_by {|v| v}.map { |k, v| "#{k}: #{v.size}" }
      puts agg
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
      @session.dealer.new_hand
      @session.rubes.each { |rube| rube.new_hand }

      2.times { @session.deal_card(@session.dealer.hand) }

      rube_hands.each do |hand|
        2.times { @session.deal_card(hand) }
      end
    end

    # Return the winners
    def play
      deal
      result = {}
      if @session.dealer.hand.blackjack?
        log "dealer backjack: wins!"
        rube_hands.each { |h| result[h] = :lose }
        return result
      end

      rube_hands.each do |hand|
        run_hand(hand)
      end

      log "running dealer hand: #{@session.dealer.hand}"
      if run_hand(@session.dealer.hand) == :busted
        log "dealer busted, non-busted rubes win"
        dealer_value = 0
      else
        dealer_value = @session.dealer.hand.max_value
      end

      log "dealer value: #{dealer_value}"
      result = {}
      rube_hands.each do |hand|
        rube_value = hand.max_value
        log " rube hand: #{hand} -> #{rube_value}"
        if !rube_value
          rube_result = :lose
        elsif rube_value == dealer_value
          rube_result = :push
        elsif rube_value > dealer_value
          rube_result = :win
        else
          rube_result = :lose
        end
        log "  result: #{rube_result}"
        result[hand] = rube_result
      end
      result
    end

    def run_hand(hand)
      loop do
        decision = hand.decide
        case decision
        when :stand
          return :stand
        when :hit
          @session.deal_card(hand)
          if hand.busted?
            log "busted: #{hand}"
            return :busted
          end
        else
          raise BlackjackError.new("Unknown decision: #{decision}")
        end
      end
    end
  end
end
