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
    @dealer = [0..3].sample
    true
  end

  def status
    num_players = @players.map{|p| p.code}.compact.size
    return "Need #{4-num_players} more players." if num_players < 4

    'OK'
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








  def player1_in!
    @players[0].in!
  end
  def player2_in!
    @players[1].in!
  end
  def player3_in!
    @players[2].in!
  end
  def player4_in!
    @players[3].in!
  end

  def deal!
    return unless self.players_ready?
    @players.each do |player|
      player.hand.deal(@deck, 5)
    end
  end

  protected

  def players_ready?
    @players.each do |player|
      return false unless player.ready?
    end
  end
end
