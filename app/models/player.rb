class Player < ActiveRecord::Base
  belongs_to :game
  attr_accessor :hand

  CRYPT_PW = 'We will move this into ENV later'

  after_initialize :initialize_hand
  def initialize_hand
    self.hand = RubyCards::Hand.new
  end
  protected :initialize_hand

  def ready?
    !self.game.nil?
  end

  def code
    @code ||= AESCrypt.encrypt(self.id, CRYPT_PW)
  end

  def self.find_by_code code
    player_id = AESCrypt.decrypt(code, CRYPT_PW)
    Player.find player_id
  end
end
