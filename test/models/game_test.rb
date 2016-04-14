require 'test_helper'

class GameTest < ActiveSupport::TestCase
  test 'the deck is the right size' do
    euchre = Game.new
    assert_equal [9,10,'J','Q','K','A'].size * ['♣','♠','♥','♦'].size, euchre.deck.cards.size
  end

  test 'there can only be 4 players' do
    euchre = Game.new
    5.times do |i|
      euchre.join_game i
    end
    assert_equal 4, euchre.players.size
  end

  test 'allow people to join and verify state' do
    euchre = Game.new
    assert_equal 'need_players', euchre.state
    4.times { euchre.join_game Faker::Name.name }
    assert_equal 'declaring_trump', euchre.state
  end

  test 'after the deal, each player has five cards' do
    euchre = Game.new
    4.times { euchre.join_game Faker::Name.name }
    euchre.players.each do |player|
      assert_equal 5, player.hand.cards.size
    end
  end
end
