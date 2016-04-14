require 'test_helper'

class GameControllerTest < ActionController::TestCase
  test 'you can create a new game' do
    skip 'Rewriting the controller.'
    response = post :new
    assert_equal "{\"status\":\"Need 4 more players.\"}", response.body
  end

  test 'that only the dealer can deal' do
    skip 'Rewriting the controller.'
    game = Game.create
    player_codes = []
    ('A'..'D').to_a.each do |player|
      response = post :join_game, id: game.id, name: player
      player_codes << JSON.parse(response.body)['code']
    end
    response = post :deal, id: game.id, code: player_codes[0]
    assert_equal "{\"status\":\"Dealer: A, with [CARD] showing.\"}", response.body
  end



  # Moved this test to the bottom because the syntax highlighting is messed up.
  test 'you can join a game' do
    skip 'Rewriting the controller.'
    game = Game.create
    response = post :join_game, id: game.id, name: 'Jeff'
    #assert_match /\"\{\"id\":d*,\"code\":[\w]\}\"/, response.body
    assert_match /\".*code\":.[\w].*\"/, response.body
    refute_match /\".*code\":.nil.*\"/, response.body
  end
end
