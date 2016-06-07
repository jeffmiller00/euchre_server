class Game < ActiveRecord::Base
  include AASM

  RANKS = { 'Jack' => 11, 'Queen' => 12, 'King' => 13, 'Ace' => 14 }
  SUITS = [:hearts, :diamonds, :spades, :clubs]
  SUIT_INVERSE = { hearts: :diamonds, diamonds: :hearts, clubs: :spades, spades: :clubs }

  has_many :players
  validates :players, length: { in: 0..4 }
  validates :trump_suit, inclusion: { in: [:hearts, :diamonds, :spades, :clubs] }

  attr_reader :up_card, :trump_suit, :trump_declaring_team, :first_card,
              :play_pile, :discard_pile, :team_scores, :top_card_trump,
              :tricks_won, :whose_turn, :whose_deal, :first_turn

  attr_accessor :deck

  after_initialize do |game|
    @whose_deal   = (0..3).to_a.sample
    @team_scores  = { 0 => 0, 1 => 0 }
    true
  end

  def status
    case state
    when :need_players
      "Need #{4 - self.players.size} more players."
    when :declaring_trump
      "It's #{player.name}'s turn to call trump."
    when :trump_suit_undeclared
      if @whose_turn == @whose_deal
        "#{dealer.name} is forced to declare trump."
      else
        "It's #{player.name}'s turn to call trump."
      end
    when :dealer_discarding
      "Waiting on #{dealer.name} to discard."
    end
  end

  def join_game(player_name)
    return Msg::GAME_FULL if self.players.size >= 4

    new_player      = self.players.new
    new_player.name = player_name
    new_player.save!

    deal if enough_players?
    new_player.code
  end

  def player_pick_it_up(player_code)
    return Msg.invalid_action(:pick_it_up) unless self.may_pick_it_up?
    return Msg::NOT_YOUR_TURN  unless player_turn?(code_to_turn(player_code))

    @trump_declaring_team = team(player_code)
    @trump_suit           = suitify(@up_card.cards.first)
    dealer.hand = RubyCards::Hand.new(dealer.hand.cards + @up_card.cards)
    @up_card    = RubyCards::Hand.new

    pick_it_up
  end

  def player_declare_trump(player_code, suit)
    return Msg.invalid_action(:declare_trump) unless self.may_declare_trump?

    suit = suit.downcase.to_sym
    return Msg::INVALID_SUIT                  unless SUITS.include?(suit)
    return Msg::INVALID_TRUMP_SUIT            if self.trump_suit_undeclared? && suit == @top_card_trump

    @trump_suit           = suit
    @trump_declaring_team = team(player_code)
    declare_trump
  end

  def player_pass(player_code)
    return Msg.invalid_action(:pass) unless self.may_pass?
    return Msg::NOT_YOUR_TURN unless player_turn?(code_to_turn(player_code))
    pass
  end

  def player_discard(player_code, card)
    return Msg.invalid_action(:dealer_discard) unless self.may_dealer_discard?
    return Msg::NOT_YOUR_TURN   unless player_turn?(code_to_turn(player_code))
    return Msg::NOT_IN_HAND     unless card_in_player_hand?(player_code, card)

    @discard_pile = RubyCards::Hand.new(@discard_pile.cards + [card])
    dealer.hand   = RubyCards::Hand.new(dealer.hand.cards - [card])

    dealer_discard
  end

  def player_play(player_code, card)
    return Msg.invalid_action(:play) unless self.may_play?
    return Msg::NOT_YOUR_TURN unless player_turn?(code_to_turn(player_code))
    return Msg::NOT_IN_HAND   unless card_in_player_hand?(player_code, card)

    @current_suit = suitify(card) if game_first_turn?
    @play_pile    = RubyCards::Hand.new(@play_pile.cards + [card])
    player.hand   = RubyCards::Hand.new(player.hand.cards - [card])

    play
  end

  def game_discard_top_card!
    @discard_pile = RubyCards::Hand.new(@discard_pile.cards + @up_card.cards)
    @up_card      = RubyCards::Hand.new
  end

  def game_rake_cards!
    @first_turn = winner_of_this_trick
    @tricks_won[@first_turn % 2] += 1

    @discard_pile = RubyCards::Hand.new(@play_pile.cards + @discard_pile.cards)
    @play_pile    = RubyCards::Hand.new
    @current_suit = nil

    # Todo: This transition fails
    rake
  end

  def game_calculate_scores!
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

    if end_of_game?
      end_game
    else
      deal
    end
  end

  def game_deal!
    @deck = RubyCards::Deck.new({number_decks: 1, exclude_rank: [2,3,4,5,6,7,8]})
    @deck.shuffle!
    @tricks_won   = { 0 => 0, 1 => 0 }
    @up_card        = RubyCards::Hand.new
    @play_pile      = RubyCards::Hand.new
    @discard_pile   = RubyCards::Hand.new

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
    @discard_pile.draw(@deck, 3)
    @top_card_trump = suitify(@up_card.cards.first)
  end

  def is_dealer?(player_code)
    @whose_deal == code_to_turn(player_code)
  end

  def game_first_turn?
    @whose_turn == @first_turn
  end

  def game_dealer_turn?
    @whose_turn == @whose_deal
  end

  def game_screw_the_dealer?
    game_next_turn_dealer? && self.trump_suit_undeclared?
  end

  def game_next_turn_dealer?
    @whose_turn == (@whose_deal-1)%4
  end

  def card_in_player_hand?(player_code, card)
    self.players.select { |p| p.code == player_code }[0].hand.cards.any? do |c|
      c.rank == card.rank && c.suit == card.suit
    end
  end

  def state
    aasm_state
  end

  aasm :whiny_transitions => true do
    state :need_players, initial: true
    state :scoring, :declaring_trump, :trump_suit_undeclared, :dealer_declaring_trump
    state :raking_cards, :laying_cards, :game_over, :dealer_discarding

    event :deal do
      transitions from: :need_players, to: :declaring_trump, guard: :enough_players?, after: :game_deal!
      transitions from: :scoring, to: :declaring_trump, guard: :end_of_round?, after: :game_deal!
    end

    event :pass do
      transitions from: :declaring_trump, to: :declaring_trump, guard: -> { !game_dealer_turn? }, after: :next_turn!
      transitions from: :declaring_trump, to: :trump_suit_undeclared, guard: :game_dealer_turn?, after: -> {
          game_discard_top_card!
          next_turn!
        }
      transitions from: :trump_suit_undeclared, to: :trump_suit_undeclared, guard: -> { !game_screw_the_dealer? }, after: :next_turn!
      transitions from: :trump_suit_undeclared, to: :dealer_declaring_trump, guard: :game_screw_the_dealer?, after: :next_turn!
    end

    event :pick_it_up do
      transitions from: :declaring_trump, to: :dealer_discarding, after: :dealer_turn!
    end

    event :declare_trump do
      transitions from: :dealer_declaring_trump, to: :laying_cards, guard: :game_dealer_turn?
      transitions from: :trump_suit_undeclared, to: :laying_cards, guard: -> { !game_dealer_turn? }
    end

    event :dealer_discard do
      transitions from: :dealer_discarding, to: :laying_cards, guard: :game_dealer_turn?, after: :lead_turn!
    end

    event :play do
      transitions from: :laying_cards, to: :laying_cards, guard: -> { !end_of_trick? }, after: :next_turn!
      # This transition never appears to happen.
      transitions from: :laying_cards, to: :raking_cards, guard: :end_of_trick?, after: :game_rake_cards!
    end

    event :rake do
      transitions from: :raking_cards, to: :scoring, guard: :end_of_round?, after: :game_calculate_scores!
      transitions from: :raking_cards, to: :laying_cards, guard: -> { !end_of_round? }
    end

    event :end_game do
      transitions :scoring => :game_over, guard: :end_of_game?
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
    @discard_pile.cards.size == 24
  end

  def end_of_trick?
    @play_pile.cards.size == 4
  end

  def next_turn!
    @whose_turn = (@whose_turn + 1) % 4
  end

  def lead_turn!
    @whose_turn = @first_turn
  end

  def dealer_turn!
    @whose_turn = @whose_deal
  end

  def winner_of_this_trick
    (@first_turn + max_in_play[1]) % 4
  end

  def player_turn?(player_number)
    player_number == @whose_turn && !end_of_round?
  end

  def max_in_play
    trump = @trump_suit.downcase.to_sym
    @play_pile.each_with_index.max_by do |card, idx|
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

  def player
    self.players[@whose_turn]
  end

  def enough_players?
    return false if players.size < 4

    self.players.each do |player|
      return false unless player.ready?
    end
  end
end
