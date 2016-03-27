require 'test_helper'

class GameTest < ActiveSupport::TestCase
  test 'the deck is the right size' do
    euchre = Game.new
    assert_equal [9,10,'J','Q','K','A'].size * ['♣','♠','♥','♦'].size, euchre.deck.cards.size
  end

  test 'there are only 4 players' do
    euchre = Game.new
    assert_equal 4, euchre.players.size
  end

  test 'initial game status' do
    euchre = Game.new
    assert_equal 'Need 4 more players.', euchre.status
  end

  test 'allow people to join and verify status' do
    euchre = Game.new
    assert_equal 'Need 4 more players.', euchre.status
    euchre.join_game 'a'
    assert_equal 'Need 3 more players.', euchre.status
    euchre.join_game 'b'
    assert_equal 'Need 2 more players.', euchre.status
    euchre.join_game 'c'
    assert_equal 'Need 1 more players.', euchre.status
    euchre.join_game 'd'
    assert_equal 'OK', euchre.status
  end
end
