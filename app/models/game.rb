class Game < ActiveRecord::Base
  has_many :players
  validates :players, length: { in: 0..4 }

  attr_reader :dealer, :up_card
  attr_accessor :deck

  after_initialize do |game|
    game.deck = RubyCards::Deck.new({number_decks: 1, exclude_rank: [2,3,4,5,6,7,8]})
    game.deck.shuffle!
    @dealer = (0..3).to_a.sample
    true
  end

  def status
    return "Need #{4-self.players.size} more players." if self.players.size < 4

    "It's #{self.players[@dealer].name}'s deal."
  end

  def join_game player_name
    return false if self.players.size >= 4

    new_player = self.players.new
    new_player.name = player_name
    new_player.save!
    new_player.code
  end

  def deal!
    return unless self.players_ready?
    5.times do
      4.times do
        @dealer = (@dealer + 1) % 4
        self.players[@dealer].hand.draw(@deck, 1)
      end
    end
    # set top card.
  end

  protected

  def players_ready?
    self.players.each do |player|
      return false unless player.ready?
    end
  end
end
