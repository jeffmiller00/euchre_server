include RubyCards

class Player < ActiveRecord::Base
  attr_reader :uuid
  attr_accessor :hand, :name

  after_initialize do |player|
    player.hand = Hand.new
  end

  def in!
    @uuid = SecureRandom.uuid unless @uuid
    self.save!
    @uuid
  end

  def ready?
    !@uuid.nil?
  end

  def code
    @uuid
  end

  def self.get_authorized_player id, code
    player = Player.find id
    player.uuid == uuid ? player : nil
  end
end
