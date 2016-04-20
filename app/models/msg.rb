class Msg
  # Turn related messages
  NOT_YOUR_TURN       = "It's not your turn."
  NOT_THE_DEALER      = "You're not the dealer."
  CANT_PICK_IT_UP     = "Can't pick it up - the dealer already passed."
  CANT_DECLARE_TRUMP  = "Can't declare trump - the dealer hasn't passed yet."
  DEALER_MUST_DECLARE = "Dealer has been screwed and must declare trump."

  # Gameplay related messages
  GAME_FULL           = "This Euchre game is full."
  INVALID_SUIT        = "That is not a valid card suit."
  INVALID_TRUMP_SUIT  = "That suit can't be used for trump."
  NOT_IN_HAND         = "That card isn't in your hand"

  class << self
    def invalid_action(action)
      "You cannot #{action} right now."
    end
  end
end