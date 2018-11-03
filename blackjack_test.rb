require 'minitest/autorun'

require_relative 'blackjack'

class ComboTest < Minitest::Test
  def test_single_combo
    assert_equal [[2, 3, 7, 5]],
                 Blackjack::combine([[2], [3], [7], [5]])
  end

  def test_multi_combo
    assert_equal [[2, 3, 1, 5], [2, 3, 11, 5]],
                 Blackjack::combine([[2], [3], [1, 11], [5]])
  end

  def test_empty_combo
    assert_equal [[]], Blackjack::combine([])
  end
end
