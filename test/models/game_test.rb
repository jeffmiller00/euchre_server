require 'test_helper'

class GameTest < ActiveSupport::TestCase
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

  describe 'after the players have joined' do
    # Todo: These methods need to be DRY'd up.
    def ready_game
      new_game = Game.new
      4.times { new_game.join_game Faker::Name.name }
      new_game
    end
    let(:euchre) { ready_game }

    it 'after the deal, each player has five cards' do
      euchre.players.each do |player|
        assert_equal 5, player.hand.cards.size
      end
      assert_equal [9,10,'J','Q','K','A'].size * ['♣','♠','♥','♦'].size,
                   (4*5) + euchre.up_card.cards.size + euchre.discard_pile.cards.size
    end

    it 'any player can order it up' do
      4.times do |pid|
        euchre = ready_game
        pid.times { euchre.player_pass euchre.send(:player).code }
        
        player = euchre.send(:player)
        euchre.player_pick_it_up player.code
        assert_equal 'dealer_discarding', euchre.state
      end
    end

    it 'dealer must discard after picking it up' do
      euchre.player_pick_it_up euchre.send(:player).code
      assert_equal 'dealer_discarding', euchre.state
      assert euchre.may_dealer_discard?

      player  = euchre.send(:player)
      card    = player.hand.cards.sample
      euchre.player_discard(player.code, card)
      assert_equal 'laying_cards', euchre.state
      assert_equal 5, player.hand.cards.size
    end

    it 'if everyone passes the first round, the state changes' do
      euchre.players.each { euchre.player_pass euchre.send(:player).code }
      assert_equal 'trump_suit_undeclared', euchre.state
    end

    it 'any player can declare trump after the first round' do
      4.times do |pid|
        euchre = ready_game
        euchre.players.each { euchre.player_pass euchre.send(:player).code }
        assert_equal 'trump_suit_undeclared', euchre.state

        trump_suit = (Game::SUITS - [euchre.send(:top_card_trump)]).sample
        pid.times { euchre.player_pass euchre.send(:player).code }

        euchre.player_declare_trump(euchre.send(:player).code, trump_suit)
        assert_equal 'laying_cards', euchre.state
      end
    end

    it 'if all players pass in both rounds the dealer is stuck' do
      euchre.players.each { euchre.player_pass euchre.send(:player).code }
      assert_equal 'trump_suit_undeclared', euchre.state

      3.times { euchre.player_pass euchre.send(:player).code }
      assert_equal 'dealer_declaring_trump', euchre.state
    end
  end

  describe 'after trump has been declared' do
    # Todo: These methods need to be DRY'd up.
    def ready_game
      new_game = Game.new
      4.times { new_game.join_game Faker::Name.name }
      new_game
    end
    def dealt_game
      euchre = ready_game
      player = euchre.send(:player)
      dealer = euchre.send(:dealer)
      euchre.player_pick_it_up player.code

      card   = dealer.hand.cards.sample
      euchre.player_discard(dealer.code, card)
      euchre
    end
    let(:euchre) { dealt_game }

    it 'each player can lay exactly 1 card per round' do
      5.times do |round|
        4.times do |i|
          player = euchre.send(:player)
          euchre.player_play(player.code, player.hand.cards.first)
          assert_equal (4-round), player.hand.cards.size
        end
        assert_equal 'raking_cards', euchre.state
      end
    end

    it 'another round begins if players have cards remaining' do

    end
  end
end
