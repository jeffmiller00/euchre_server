include RubyCards

class Game < ActiveRecord::Base
  #has_many :players

  attr_reader :dealer
  attr_accessor :deck, :players

  after_initialize do |game|
    #return false if @@active_games >= MAX_GAMES
    game.deck = Deck.new({number_decks: 1, exclude_rank: [2,3,4,5,6,7,8]})
    game.deck.shuffle!
    game.players = []
    4.times do
      game.players << Player.create!
    end
    @dealer = (0..3).to_a.sample
    true
  end

  def status
    num_players = @players.map{|p| p.code}.compact.size
    return "Need #{4-num_players} more players." if num_players < 4

    "It's #{@players[dealer].name}'s deal."
  end

  def join_game player_name
    return false if self.players_ready?
    code = nil
    @players.each do |player|
      next if player.ready?
      player.name = player_name
      code = player.in!
      player.save!
      break
    end
    code
  end

  def deal!
    return unless self.players_ready?
    5.times do
      4.times do
        @dealer = (@dealer + 1) % 4
        @players[dealer].hand.draw(@deck, 1)
      end
    end
  end

  protected

  def players_ready?
    @players.each do |player|
      return false unless player.ready?
    end
  end
end
