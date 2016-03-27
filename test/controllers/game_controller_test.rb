require 'test_helper'

class GameControllerTest < ActionController::TestCase
  test 'you can create a new game' do
    response = post :new
    assert_equal "{\"status\":\"Need 4 more players.\"}", response.body
  end

  test 'you can join a game' do
    game = Game.create
    response = post :join_game, id: game.id, name: 'Jeff'
    #assert_match /\"\{\"id\":d*,\"code\":[\w]\}\"/, response.body
    assert_match /\".*code\":.[\w].*\"/, response.body
    refute_match /\".*code\":.nil.*\"/, response.body
  end
end
