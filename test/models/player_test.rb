require 'test_helper'

class PlayerTest < ActiveSupport::TestCase
  test 'you can lookup the player by code' do
    p = Player.create
    code = p.code
    found_player = Player.find_by_code code
    assert_not code.nil?
    assert_equal p, found_player
  end

  test 'you can not change the code' do
    p = Player.create
    assert_raises { p.code='123' }
  end
end
