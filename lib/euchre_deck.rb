class EuchreDeck < RubyCards::Deck
  RANKS = { 'Jack' => 11, 'Queen' => 12, 'King' => 13, 'Ace' => 14 }
  SUIT_INVERSE = { hearts: :diamonds, diamonds: :hearts, clubs: :spades, spades: :clubs }

  def initialize
    super(number_decks: 1, exclude_rank: [2,3,4,5,6,7,8])
  end

  class << self
    def max(trump, cards)
      trump_suit = trump_suit.downcase.to_sym
      cards.sort_by do |card|
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
      end
    end
  end
end