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

  test 'any player can order it up' do
    4.times do |pid|
      euchre = Game.new
      4.times { euchre.join_game Faker::Name.name }
      player = euchre.send(:at_bat)
      pid.times { euchre.player_pass player.code }
      euchre.player_pick_it_up player.code
      assert_equal 'dealer_discarding', euchre.state
    end
  end

  test 'if everyone passes the first round, the state changes' do
    euchre = Game.new
    4.times { euchre.join_game Faker::Name.name }
    euchre.players.each { euchre.player_pass euchre.send(:at_bat).code }
    assert_equal 'trump_suit_undeclared', euchre.state
  end

  test 'any player can declare trump after the first round' do
    4.times do |pid|
      euchre = Game.new
      4.times { euchre.join_game Faker::Name.name }
      euchre.players.each { euchre.player_pass euchre.send(:at_bat).code }
      assert_equal 'trump_suit_undeclared', euchre.state

      pid.times { euchre.player_pass euchre.send(:at_bat).code }
      euchre.player_declare_trump(euchre.send(:at_bat).code, Game::SUITS[pid])
      assert_equal 'dealer_discarding', euchre.state
    end
  end
end
