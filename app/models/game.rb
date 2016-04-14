class Game < ActiveRecord::Base
  RANKS = { 'Jack' => 11, 'Queen' => 12, 'King' => 13, 'Ace' => 14 }
  SUIT_INVERSE = { hearts: :diamonds, diamonds: :hearts, clubs: :spades, spades: :clubs }

  has_many :players
  validates :players, length: { in: 0..4 }
  validates :trump_suit, inclusion: { in: [:hearts, :diamonds, :spades, :clubs] }

  attr_reader :up_card, :trump_suit, :trump_declaring_team, :first_card,
              :card_played, :cards_in_play, :cards_in_discard, :team_scores,
              :tricks_won

  attr_accessor :deck, :state

  after_initialize do |game|
    game.deck = RubyCards::Deck.new({number_decks: 1, exclude_rank: [2,3,4,5,6,7,8]})
    game.deck.shuffle!

    @whose_deal   = (0..3).to_a.sample
    @card_played  = {}
    @team_scores  = { 0 => 0, 1 => 0 }
    @tricks_won   = { 0 => 0, 1 => 0 }
    @up_card          = RubyCards::Hand.new
    @cards_in_play    = RubyCards::Hand.new
    @cards_in_discard = RubyCards::Hand.new
    true
  end

  def status
    case state
    when :need_players
      "Need #{4 - self.players.size} more players."
    when :declaring_trump
      "It's #{at_bat.name}'s turn to call trump."
    when :trump_suit_undeclared
      if @whose_turn == @whose_deal
        "#{dealer.name} is forced to declare trump."
      else
        "It's #{at_bat.name}'s turn to call trump."
      end
    when :dealer_discarding
      "Waiting on #{dealer.name} to discard."
    end
  end

  def join_game(player_name)
    return false if self.players.size >= 4

    new_player      = self.players.new
    new_player.name = player_name
    new_player.save!
    new_player.code

    deal if self.players.size == 4
  end

  def pick_it_up!(player_code)
    return unless state == :declaring_trump

    @trump_declaring_team = team(player_code)
    pick_it_up
  end

  def call_trump(player_code, suit)
    return unless state == :trump_suit_undeclared ||
      code_to_turn(player_code) == @whose_deal && 
        state == :dealer_declaring_trump

    @trump_suit     = suit.downcase.to_sym
    @trump_declaring_team = team(player_code)
    declare_trump
  end

  def pass(player_code)
    return unless player_turn?(code_to_turn(player_code))

    pass
  end

  def play(player_code, card)
    return "It's not your turn" unless player_turn?(code_to_turn(player_code))

    @current_suit             = suitify(card) if @cards_in_play.cards.size == 0
    @cards_in_play            = RubyCards::Hand.new(@cards_in_play.cards + [card])
    @card_played[@whose_turn] = card
    play
  end

  def rake_card_pile
    @first_turn       = winner_of_this_trick
    @tricks_won[@first_turn % 2] += 1

    @whose_turn       = @first_turn
    @current_suit     = nil
    @card_played      = {}

    @cards_in_discard = RubyCards::Hand.new(@cards_in_play.cards + @cards_in_discard.cards)
    @cards_in_play    = RubyCards::Hand.new

    rake_cards
  end

  def calculate_scores
    team0 = @tricks_won[0]
    team1 = @tricks_won[1]
    winning_team = team0 > team1 ? 0 : 1

    if @trump_declaring_team == winning_team
      if @tricks_won[winning_team] == 5
        @team_scores[winning_team] += 2
      else
        @team_scores[winning_team] += 1
      end
    else
      @team_scores[1 - winning_team] += 2
    end

    end_game if end_of_game?
  end

  def game_deal
    num_to_draw = [2, 3, 2, 3, 2]
    2.times do |j|
      4.times do |p|
        players[p].hand.draw(@deck, num_to_draw[p + j])
      end
    end

    @whose_deal = (@whose_deal + 1) % 4
    @first_turn = (@whose_deal + 1) % 4
    @whose_turn = @first_turn
    @up_card.draw(@deck, 1)
  end

  def dealer_take_top_card
    @trump_suit = suitify(@up_card.cards.first)
    @whose_turn = @whose_deal
  end

  def is_dealer?(player)
    !!(player == self.players[@whose_deal])
  end

  state_machine :state, initial: :need_players do

    after_transition any => :raking_cards, do: :rake_card_pile
    after_transition :raking_cards => :scoring, do: :calculate_scores
    before_transition on: :deal, do: :game_deal

    event :deal do
      transition :need_players => :declaring_trump, if: lambda { |g| g.players.size == 4 }
      transition :scoring => :declaring_trump
    end

    event :pass do
      transition :trump_suit_undeclared => :dealer_declaring_trump, if: -> { @whose_turn == @whose_deal && state == :trump_suit_undeclared }
      transition :declaring_trump => :trump_suit_undeclared, if: -> { @whose_turn == @whose_deal }
    end
    after_transition on: [:pass, :play] , do: :next_turn!
    before_transition on: [:declare_trump, :dealer_discard], do: :lead_turn!

    event :declare_trump do
      transition [:trump_suit_undeclared, :dealer_declaring_trump]  => :player0_playing, if: lambda{ |g| g.player_turn?(0) }
      transition [:trump_suit_undeclared, :dealer_declaring_trump]  => :player1_playing, if: lambda{ |g| g.player_turn?(1) }
      transition [:trump_suit_undeclared, :dealer_declaring_trump]  => :player2_playing, if: lambda{ |g| g.player_turn?(2) }
      transition [:trump_suit_undeclared, :dealer_declaring_trump]  => :player3_playing, if: lambda{ |g| g.player_turn?(3) }
    end

    event :pick_it_up do
      transition :declaring_trump => :dealer_discarding
    end
    after_transition on: :pick_it_up, do: :dealer_take_top_card

    event :dealer_discard do
      transition :dealer_discarding  => :player0_playing, if: lambda { |g| g.player_turn?(0) }
      transition :dealer_discarding  => :player1_playing, if: lambda { |g| g.player_turn?(1) }
      transition :dealer_discarding  => :player2_playing, if: lambda { |g| g.player_turn?(2) }
      transition :dealer_discarding  => :player3_playing, if: lambda { |g| g.player_turn?(3) }
    end

    event :play do
      transition [
        :player0_playing,
        :player1_playing,
        :player2_playing,
        :player3_playing
      ] => :raking_cards, if: lambda { |g| g.player_turn?(@first_turn) }
      transition :player0_playing  => :player1_playing, if: lambda { |g| g.player_turn?(0) }
      transition :player1_playing  => :player2_playing, if: lambda { |g| g.player_turn?(1) }
      transition :player2_playing  => :player3_playing, if: lambda { |g| g.player_turn?(2) }
      transition :player3_playing  => :player0_playing, if: lambda { |g| g.player_turn?(3) }
    end

    event :rake_cards do
      transition :raking_cards  => :player0_playing, if: lambda { |g| g.player_turn?(0) }
      transition :raking_cards  => :player1_playing, if: lambda { |g| g.player_turn?(1) }
      transition :raking_cards  => :player2_playing, if: lambda { |g| g.player_turn?(2) }
      transition :raking_cards  => :player3_playing, if: lambda { |g| g.player_turn?(3) }
      transition :raking_cards  => :scoring, if: -> { end_of_round? }
    end

    event :end_game do
      transition :scoring => :game_over
    end
  end

  protected

  def team0
    [0, 2]
  end

  def team1
    [1, 3]
  end

  def end_of_game?
    @team_scores.any? { |_, score| score >= 10 }
  end

  def end_of_round?
    @cards_in_discard.cards.size == 20
  end

  def end_of_trick?
    @cards_in_play.cards.size == 4
  end

  def next_turn!
    @whose_turn = (@whose_turn + 1) % 4
  end

  def lead_turn!
    @whose_turn = @first_turn
  end

  def winner_of_this_trick
    max_in_play[1]
  end

  def player_turn?(player_number)
    player_number == @whose_turn && !end_of_round?
  end

  def max_in_play
    trump = @trump_suit.downcase.to_sym
    @cards_in_play.each_with_index.sort_by do |card, idx|
      card_suit = card.suit.downcase.to_sym
      rank      = card.rank.to_i
      rank      = rank == 0 ? RANKS[card.rank] : rank

      if card_suit == trump
        rank += 100 
        rank += 100 if card.rank == 'Jack'
      elsif SUIT_INVERSE[card_suit] == trump
        rank += 95 if card.rank == 'Jack' && SUIT_INVERSE[card_suit] == trump
      elsif card_suit == @current_suit
        rank += 50
      end

      rank
    end[-1]
  end

  def code_to_turn
    self.players.index { |p| p.code == player_code }
  end

  def team(player_code)
    code_to_turn(player_code) % 2
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

  def players_ready?
    self.players.each do |player|
      return false unless player.ready?
    end
  end
end
