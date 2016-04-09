class GameController < ApplicationController
  layout nil

  def new
    @game = Game.create
    render json: game_status, content_type: 'application/vnd.api+json'
  end

  def status
    render json: game_status, content_type: 'application/vnd.api+json'
  end

  def join_game
    name = params[:name] || Faker::Name.name.split.first
    @game = Game.find params[:id]
    code = @game.join_game name
    render json: {id: @game.id, code: code}, content_type: 'application/vnd.api+json'
  end

  def deal
    euchre = Game.find params[:id]
    @player = Player.find_by_code params[:code]
    return 'Player not found.' if @player.nil?
    return 'Not your turn to deal' if !euchre.is_dealer?(@player)
    euchre.deal!
    render json: game_status, content_type: 'application/vnd.api+json'
  end

  def top_card
  end

  private

  def game_status
    {status: @game.status}
  end
end
