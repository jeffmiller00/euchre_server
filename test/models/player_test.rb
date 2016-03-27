require 'test_helper'

class PlayerTest < ActiveSupport::TestCase
  test 'you can get the code once' do
    p = Player.new
    code = p.in!
    assert_not code.nil?
    assert_equal code, p.code
  end

  test 'you can not change the code' do
    p = Player.new
    code = p.in!
    assert_raises { p.code='123' }
    assert true
  end
end
