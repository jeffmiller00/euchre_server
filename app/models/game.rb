class Game < ActiveRecord::Base
  include AASM

  RANKS = { 'Jack' => 11, 'Queen' => 12, 'King' => 13, 'Ace' => 14 }
  SUITS = [:hearts, :diamonds, :spades, :clubs]
  SUIT_INVERSE = { hearts: :diamonds, diamonds: :hearts, clubs: :spades, spades: :clubs }

  has_many :players
  validates :players, length: { in: 0..4 }
  validates :trump_suit, inclusion: { in: [:hearts, :diamonds, :spades, :clubs] }

  attr_reader :up_card, :trump_suit, :trump_declaring_team, :first_card,
              :cards_in_play, :cards_in_discard, :team_scores,
              :tricks_won, :whose_turn, :whose_deal, :first_turn

  attr_accessor :deck

  after_initialize do |game|
    game.deck = RubyCards::Deck.new({number_decks: 1, exclude_rank: [2,3,4,5,6,7,8]})
    game.deck.shuffle!

    @whose_deal   = (0..3).to_a.sample
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

    deal if enough_players?
  end

  def player_pick_it_up(player_code)
    return unless self.declaring_trump?

    @trump_declaring_team = team(player_code)
    pick_it_up
  end

  def player_declare_trump(player_code, suit)
    return unless state == 'trump_suit_undeclared' ||
                  ( code_to_turn(player_code) == @whose_deal &&
                    state == 'dealer_declaring_trump')

    # Todo: We shouldn't allow the trump suit to be the same suit as the up card suit
    @trump_suit = suit.downcase.to_sym
    @trump_declaring_team = team(player_code)
    declare_trump
  end

  def player_pass(player_code)
    return unless player_turn?(code_to_turn(player_code))

    pass
  end

  def player_play(player_code, card)
    return "It's not your turn" unless player_turn?(code_to_turn(player_code))

    @current_suit             = suitify(card) if @cards_in_play.cards.size == 0
    @cards_in_play            = RubyCards::Hand.new(@cards_in_play.cards + [card])
  end

  def rake_card_pile!
    @first_turn = winner_of_this_trick
    @tricks_won[@first_turn % 2] += 1

    @whose_turn       = @first_turn
    @current_suit     = nil

    @cards_in_discard = RubyCards::Hand.new(@cards_in_play.cards + @cards_in_discard.cards)
    @cards_in_play    = RubyCards::Hand.new
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

  def dealer_turn?
    @whose_turn == @whose_deal
  end

  def state
    aasm_state
  end

  def screw_the_dealer?
    dealer_turn? && state == 'trump_suit_undeclared'
  end

  aasm :whiny_transitions => false do
    state :need_players, initial: true
    state :scoring, :declaring_trump, :trump_suit_undeclared, :dealer_declaring_trump
    state :raking_cards, :laying_cards, :game_over, :dealer_discarding

    event :deal do
      transitions from: :need_players, to: :declaring_trump, guard: :enough_players?, after: :game_deal
      # transitions from: :scoring, to: :declaring_trump
    end

    event :pass do
      transitions from: :declaring_trump, to: :declaring_trump, guard: -> { !dealer_turn? }, after: :next_turn!
      transitions from: :declaring_trump, to: :trump_suit_undeclared, guard: :dealer_turn?, after: :next_turn!
      transitions from: :trump_suit_undeclared, to: :trump_suit_undeclared, guard: -> { !screw_the_dealer? }, after: :next_turn!
      transitions from: :trump_suit_undeclared, to: :dealer_declaring_trump, guard: :screw_the_dealer?, after: :next_turn!
    end

    event :pick_it_up do
      transitions from: :declaring_trump, to: :dealer_discarding, after: :lead_turn!
    end

    event :declare_trump do
      transitions from: :dealer_declaring_trump, to: :dealer_discarding
      transitions from: :trump_suit_undeclared, to: :laying_cards
    end

    event :dealer_discard do
      transitions from: :dealer_discarding, to: :laying_cards
    end

    event :play do
      transitions from: :laying_cards, to: :laying_cards, guard: -> { !end_of_trick? }, after: :next_turn!
      transitions from: :laying_cards, to: :raking_cards, guard: :end_of_trick?, after: :next_turn!
    end

    event :rake do
      transitions from: :raking_cards, to: :scoring, guard: :end_of_round?
      transitions from: :raking_cards, to: :laying_cards, guard: -> { !end_of_round? }, after: :rake_card_pile!
    end

    # event :rake_cards do
    #   transition :raking_cards  => :player0_playing, if: lambda { |g| g.player_turn?(0) }
    #   transition :raking_cards  => :player1_playing, if: lambda { |g| g.player_turn?(1) }
    #   transition :raking_cards  => :player2_playing, if: lambda { |g| g.player_turn?(2) }
    #   transition :raking_cards  => :player3_playing, if: lambda { |g| g.player_turn?(3) }
    #   transition :raking_cards  => :scoring, if: -> { end_of_round? }
    # end

    # event :end_game do
    #   transition :scoring => :game_over
    # end
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
    (@first_turn + max_in_play[1]) % 4
  end

  def player_turn?(player_number)
    player_number == @whose_turn && !end_of_round?
  end

  def max_in_play
    trump = @trump_suit.downcase.to_sym
    @cards_in_play.each_with_index.max_by do |card, idx|
      card_suit = card.suit.downcase.to_sym
      rank      = card.rank.to_i
      rank      = rank == 0 ? RANKS[card.rank] : rank

      if card_suit == trump
        rank += 100 
        rank += 100 if card.rank == 'Jack'
      elsif SUIT_INVERSE[card_suit] == trump
        rank += 199 if card.rank == 'Jack' && SUIT_INVERSE[card_suit] == trump
      elsif card_suit == @current_suit
        rank += 50
      end

      rank
    end
  end

  def code_to_turn(player_code)
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

  def enough_players?
    return false if players.size < 4

    self.players.each do |player|
      return false unless player.ready?
    end
  end
end
