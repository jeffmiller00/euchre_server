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

  private

  def game_status
    {status: @game.status}
  end
end
