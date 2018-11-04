require_relative 'blackjack'

sess = Blackjack::Session.new
game = sess.play_until_end
