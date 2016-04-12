class Game < ActiveRecord::Base
  has_many :players
  validates :players, length: { in: 0..4 }
  validates :trump_suit, inclusion: { in: [:hearts, :diamonds, :spades, :clubs] }

  attr_reader :dealer, :up_card, :trump_suit, :trump_declarer :first_card,
              :card_played, :cards_in_play, :cards_in_discard
  attr_accessor :deck, :pass_count

  after_initialize do |game|
    game.deck = RubyCards::Deck.new({number_decks: 1, exclude_rank: [2,3,4,5,6,7,8]})
    game.deck.shuffle!
    @whose_deal   = (0..3).to_a.sample
    @card_played  = {}
    @up_card          = RubyCards::Hand.new
    @cards_in_play    = RubyCards::Hand.new
    @cards_in_discard = RubyCards::Hand.new
    true
  end

  def status
    case state
    when :need_players
      "Need #{4 - self.players.size} more players."
    when :undealt
      "It's #{dealer.name}'s deal."
    when :dealt
      "It's #{at_bat.name}'s turn to call trump."
    when :trump_suit_undeclared
      if @whose_turn == @whose_deal
        "#{dealer.name} is forced to declare trump."
      else
        "It's #{at_bat.name}'s turn to call trump."
      end
    when :trump_suit_declared
      "Waiting on #{dealer.name} to discard."
    end
  end

  def join_game(player_name)
    return false if self.players.size >= 4

    new_player = self.players.new
    new_player.name = player_name
    new_player.save!
    new_player.code

    deal if self.players.size == 4
  end

  def pick_it_up!(player_code)
    return unless state == :declaring_trump
    @trump_declarer = player_code
    pick_it_up
  end

  def call_trump(player_code, suit)
    return unless state == :trump_suit_undeclared
    @trump_suit     = suit.downcase.to_sym
    @trump_declarer = player_code
    declare_trump
  end

  def pass(player_code)
    return unless player_turn?(player_code)
    pass
  end

  def play(player_code, card)
    return "It's not your turn" unless player_turn?(player_code)
    @current_suit             = suitify(card) if @cards_in_play.cards.size == 0
    @cards_in_play            = RubyCards::Hand.new(@cards_in_play.cards + [card])
    @card_played[@whose_turn] = card
    play_card
  end

  def is_dealer?(player)
    !!(player == self.players[@whose_deal])
  end

  state_machine :state, :initial => :need_players do

    after_transition on: :deal do
      @whose_deal = (@whose_deal + 1) % 4
      @first_turn = (@whose_deal + 1) % 4
      @whose_turn = @first_turn
    end

    after_transition any => :rake_cards do
      @first_turn       = winner
      @whose_turn       = @first_turn
      @current_suit     = nil
      @card_played      = {}

      @cards_in_discard = RubyCards::Hand.new(@cards_in_play.cards + @cards_in_discard.cards)
      @cards_in_play    = RubyCards::Hand.new
    end

    event :deal do
      transition :need_players, :undealt => :declaring_trump

      @up_card.draw(@deck, 1)
    end

    event :pass do
      transition :declaring_trump => :trump_suit_undeclared, if: -> { @whose_turn == @whose_deal }
      @whose_turn = (@whose_turn + 1) % 4
    end

    event :declare_trump do
      transition :trump_suit_undeclared => :trump_suit_declared
      @first_turn = (@whose_deal + 1) % 4
      @whose_turn = @first_turn
    end

    event :pick_it_up do
      transition :declaring_trump => :trump_suit_declared
      @trump_suit = suitify(@up_card.cards.first)
      @first_turn = (@whose_deal + 1) % 4
      @whose_turn = @first_turn
    end

    event :dealer_discard do
      transition :trump_suit_declared  => :player0_playing, if: -> { @whose_turn == 0 }
      transition :trump_suit_declared  => :player1_playing, if: -> { @whose_turn == 1 }
      transition :trump_suit_declared  => :player2_playing, if: -> { @whose_turn == 2 }
      transition :trump_suit_declared  => :player3_playing, if: -> { @whose_turn == 3 }
    end

    event :play_card do
      transition :player0_playing  => :player1_playing, if: -> { @whose_turn == 0 }
      transition :player1_playing  => :player2_playing, if: -> { @whose_turn == 1 }
      transition :player2_playing  => :player3_playing, if: -> { @whose_turn == 2 }
      transition :player3_playing  => :player0_playing, if: -> { @whose_turn == 3 }
      @whose_turn = (@whose_turn + 1) % 4

      transition [
        :player0_playing,
        :player1_playing,
        :player2_playing,
        :player3_playing
      ] => :rake_cards, if: -> { @whose_turn == @first_turn && @cards_in_play.cards.size == 4 }
    end
  end

  protected

  def max_in_play
    trump_suit = trump_suit.downcase.to_sym
    @cards_in_play.sort_by do |card|
      card_suit = card.suit.downcase.to_sym
      rank      = card.rank.to_i
      rank      = rank == 0 ? RANKS[card.rank] : rank

      if card_suit == trump_suit
        rank += 20 
        rank += 20 if card.rank == 'Jack'
      else
        rank += 35 if card.rank == 'Jack' && SUIT_INVERSE[card_suit] == trump_suit
      end

      rank
    end[-1]
  end

  def code_to_turn
    self.players.index { |p| p.code == player_code }
  end

  def suitify(card)
    card.suit.downcase.to_sym
  end

  def dealer
    self.players[@whose_deal]
  end

  def at_bat
    self.players[@whose_turn]
  end

  def player_with_next_turn
    case state
    when :trump_suit_declared
      pnum = (@whose_deal + 1) % 4
      "p#{pnum}_turn".to_sym
    when :declaring_trump
      @pass_count
  end

  def player_turn?(player_code)
    code_to_turn(player_code) == @whose_turn
  end

  def players_ready?
    self.players.each do |player|
      return false unless player.ready?
    end
  end
end
