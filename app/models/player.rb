include RubyCards

class Player < ActiveRecord::Base
  attr_reader :code
  attr_accessor :hand, :name

  after_initialize do |player|
    player.hand = Hand.new
  end

  def in!
    @code = ('a'..'z').to_a.sample unless @code
    @code
  end

  def ready?
    !@code.nil?
  end
end
