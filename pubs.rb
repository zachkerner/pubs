require "sinatra"
require "sinatra/reloader"
require "sinatra/content_for"
require "tilt/erubis"

require_relative "session"
require_relative "check"
require_relative "db"

configure do
  enable :sessions
  set :session_secret, "super_secret"
  set :erb, :escape_html => true
  also_reload "db.rb", "check.rb", "session.rb"
end

before do
  @db = DatabasePersistence.new
  @check = InputValidation.new
  @temp = Session.new(session)

  @url = request.path_info
  @temp.set_url(@url)
  invalid_login if @temp.logged_out_not_signin_page?(@url)

  qs = request.env['rack.request.query_hash']
  parse_extra_params(@url, qs)
end

helpers do

  def parse_extra_params(url, qs)
    return if sign_in_page?(url)
    if players_or_teams?(url)
      invalid_query_parameters(url) if player_teams_extra_qs?(qs)
    else
      invalid_query_parameters(url) if extra_qs?(qs)
    end
  end

  def invalid_query_parameters(url)
    session[:error] = "Invalid query parameters."
    redirect "#{url}"
  end

  def extra_qs?(qs)
    return true if qs.size > 0
    nil
  end

  def player_teams_extra_qs?(qs)
    return true if qs.size > 1
    return true if qs.size > 0 && params[:page].nil?
    return true unless @check.param_just_number?(params[:page])
    nil
  end

  def players_or_teams?(url)
    ["/players", "/teams"].include?(url)
  end

  def sign_in_page?(url)
    url == "/signin"
  end
  
  def invalid_login
    session[:error] = "Please log in."
    redirect "/signin"
  end

  def no_data(collection)
    return "*** no data to report *** " if collection.empty?
    nil
  end

  def number_of_pages(size)
    return size / 5 if size % 5 == 0
    size / 5 + 1
  end

  def return_valid_name(name)
    return nil if name.nil? || name.empty? || name.size > 24
    name
  end

  def return_valid_height(height)
    return nil if height.nil? || height < 121 || height > 218
    height
  end

  def return_valid_player(player)
    player[:name] if player
  end

  def strip_data(data)
    return nil if data.nil? || data.empty?
    data.strip
  end

  def sort_by_id(collection)
    collection.sort_by { |elem| elem[:id].to_i }
  end

  def sort_alphabetically(collection)
    collection.sort_by { |elem| elem[:name].downcase }
  end

  def player_team(player)
    return "no team" if player.nil? || player[:team_name].nil? || player.is_a?(Array)
    player[:team_name]
  end

  def collect_inputs(input1, input2, input3)
    [input1, input2, input3].select {|i| !i.empty? }
  end

end

not_found do
  session[:error] = "Sorry, page not found."
  redirect "/home"
end

get "/" do
  redirect "/home"
end

get "/signin" do
  @username = @temp.username
  erb :signin
end

post "/signin" do
  username = strip_data(params[:username])
  password = strip_data(params[:password])
  if @temp.valid_credentials?(username, password)
    @temp.set_logged_in
    redirect "#{@temp.url}"
  else
    @temp.set_username(username)
    session[:error] = "Invalid username or password."
    redirect "/signin"
  end
end

post "/signout" do
  @temp.set_logged_out
  @temp.set_url("/home")
  @temp.delete_username
  session[:success] = "User signed out."
  redirect "/signin"
end

get "/home" do
  erb :home
end

get "/explainer" do
  erb :explainer
end

get "/sorry" do
  erb :sorry
end

get "/players" do
  @page_number = params[:page].to_i
  redirect "/players?page=1" if @page_number == 0

  @temp.delete_player
  @players = @db.players
  @players_sorted = sort_alphabetically(@players)
  @temp.set_page(@page_number)
  
  error = @check.page_error(@page_number, @players.size)
  if error
    session[:error] = "That page does not exist."
    redirect "/players?page=1"
  end
  erb :players
end

post "/players/seed" do
  @db.seed_basic
  redirect "/players?page=1"
end

get "/new_player" do
  @player = @temp.player
  erb :new_player
end

post "/new_player" do
  @temp.delete_player
  name = strip_data(params[:name])
  height = strip_data(params[:height]).to_i
  position = params[:position]
  attribute = params[:attribute]
  role = params[:role]
  mmr = params[:mmr]
  @temp.set_player(name, height, position, attribute, role, mmr)

  player_creation_error = @check.player_create_error(name, height, position, attribute, role, mmr)
  if player_creation_error
    session[:error] = player_creation_error
    redirect "/new_player"
  else
    player = @db.assemble_player(name, height, position, attribute, role, mmr)
    @db.add_player(player)
    session[:success] = "Player added."
    redirect "/players?page=1"
  end
end

get "/players/edit/:id" do
  @player_id = params[:id].to_i

  player = @db.player_from_id(@player_id)
  params_error = @check.param_just_number?(params[:id])
  unless player && params_error
    session[:error] = "Player not found."
    redirect "/players?page=1"
  end

  @player_name = player[:name]
  @player_height = player[:height]
  @player_position = player[:position]
  @player_attribute = player[:attribute]
  @player_role = player[:role]
  @player_mmr = player[:mmr].to_s
  @player_team_id = player[:team_id]

  erb :edit_player
end

post "/players/edit/:id" do
  @player_id = params[:id].to_i
  player = @db.player_from_id(@player_id)

  original_name = player[:name]
  name = params[:name]
  height = params[:height].to_i
  position = params[:position]
  attribute = params[:attribute]
  role = params[:role]

  player_update_error = @check.player_update_error(original_name, name, height, position, attribute, role)
  if player_update_error
    session[:error] = player_update_error
    redirect "/players/edit/#{params[:id]}"
  else
    @db.update_player(@player_id, name, height, position, attribute, role) 
    session[:success] = "Update received."
    redirect "/players"
  end
end

post "/players/delete/:id" do
  player_id = params[:id].to_i

  @db.delete_player(player_id)

  session[:success] = "Player deleted."
  redirect "/players?page=1"
end

get "/players/delete_all" do
  erb :delete_all_players
end

post "/players/delete_all" do
  @db.delete_all_players_full

  session[:success] = "All players deleted."
  redirect "/players"
end

get "/teams" do
  @page_number = params[:page].to_i
  redirect "/teams?page=1" if @page_number == 0
  
  @temp.delete_team
  @teams = @db.teams
  @teams_ordered = sort_alphabetically(@teams)

  @temp.set_page(@page_number)
  error = @check.page_error(@page_number, @teams.size)
  if error
    session[:error] = "That page does not exist."
    redirect "/teams"
  end
  erb :teams
end

get "/new_team" do
  @team = @temp.team
  erb :new_team
end

post "/new_team" do
  @temp.delete_team
  team_name = strip_data(params[:name])

  player1_name = strip_data(params[:player1])
  player2_name = strip_data(params[:player2])
  player3_name = strip_data(params[:player3])
  collection_input = collect_inputs(params[:player1],params[:player2], params[:player3] )
  
  @player1 = @db.player_from_name(player1_name)
  @player2 = @db.player_from_name(player2_name)
  @player3 = @db.player_from_name(player3_name)

  @temp.set_team(team_name, @player1, @player2, @player3)

  name = team_name
  roster = @db.assemble_roster(@player1, @player2, @player3)

  team_create_error = @check.team_create_error(name, roster, collection_input.size)
  if team_create_error
    session[:error] = team_create_error
    redirect "/new_team"
  else
    @db.add_team_full(name, roster)

    session[:success] = "Team added."
    redirect "/teams?page=1"
  end

end

get "/teams/edit/:id" do
  @team_id = params[:id].to_i
  @team = @db.team_from_id(@team_id)
  params_error = @check.param_just_number?(params[:id])
  unless @team && params_error
    session[:error] = "Team not found."
    redirect "/teams?page=1"
  end

  @team_name = @db.team_name_from_id(@team_id)
  @roster = @db.roster_from_team_id(@team_id)
  @roster_sorted = sort_alphabetically(@roster)
  erb :edit_team
end

post "/teams/edit/:id/remove_player/:player_id" do
  team_id = params[:id].to_i
  @player_id = params[:player_id].to_i
  
  @db.remove_player_from_team(@player_id)

  session[:success] = "Player removed."
  redirect "/teams/edit/#{team_id}"
end

post "/teams/edit/:id/add_player" do
  team_id = params[:id].to_i
  team_name = @db.team_name_from_id(team_id)
  player_name = params[:add_player]
  player_id = @db.player_id_from_name(player_name)
  
  addition_error = @check.add_player_roster_error(player_name, player_id, team_id)
  if addition_error
    session[:error] = addition_error
    redirect "/teams/edit/#{team_id}"
  else
    @db.add_team_to_player(team_id, team_name, player_id)
    #update_team_mmr(team)
    session[:success] = "Player added."
    redirect "/teams/edit/#{team_id}"
  end
end

post "/players/delete_from_team/:team_id/:player_id" do
  player_id = params[:player_id].to_i
  team_id = params[:team_id]

  @db.delete_player(player_id)

  session[:success] = "Player deleted."
  redirect "/teams/edit/#{team_id}"
end

post "/teams/edit/:id/new_name" do
  name = params[:new_name].strip
  @team_id = params[:id].to_i
  original_name = @db.team_name_from_id(@team_id)

  name_error = @check.team_update_name_error(original_name, name)
  if name_error
    session[:error] = name_error
    redirect "/teams/edit/#{@team_id}"
  else
    @db.team_update_name_full(@team_id, name)

    session[:success] = "Team name updated."
    redirect "/teams/edit/#{@team_id}"
  end
end

post "/teams/delete/:id" do
  team_id = params[:id].to_i
  
  @db.delete_team_full(team_id)

  session[:success] = "Team and players deleted."
  redirect "/teams?page=#{@temp.page}"
end

get "/teams/delete_all" do
  
  erb :delete_all_teams
end

post "/teams/delete_all" do
  @db.delete_all_teams_full
  session[:success] = "All teams and registered players deleted."
  redirect "/teams?page=1"
end

get "/play" do
  @temp.reset_matchup
  @pregame_teams = @temp.pregame_teams
  erb :play
end

post "/play" do
  team1_name = strip_data(params[:team1])
  team2_name = strip_data(params[:team2])

  @temp.set_pregame_teams(team1_name, team2_name)

  play_error = @check.play_error(team1_name, team2_name)
  if play_error
    @temp.reset_matchup
    session[:error] = play_error
    redirect "/play"
  else
    team1 = @db.team_from_name(team1_name)
    team2 = @db.team_from_name(team2_name)
    @temp.add_teams_to_matchup(team1, team2)
    session[:success] = "Get ready to play!"
    redirect "/result"
  end
end

get "/result" do
  #session[:matchup] = session[:matchup].compact
  @team1, @team2 = @temp.put_favorite_first
  @team1_name = @team1[:name]
  @team2_name = @team2[:name]
  @team1_mmr = @team1[:team_mmr]
  @team2_mmr = @team2[:team_mmr]
  @team1_roster = @team1[:roster]
  @team2_roster = @team2[:roster]

  @mmr_test1 = @team1[:team_mmr]
  @mmr_test2 = @team2[:team_mmr]

  @mmr_gain_favorite = @temp.calculate_mmr(@team1, @team2)
  @mmr_gain_underdog = @temp.calculate_mmr(@team2, @team1)
  erb :result
end

post "/result" do
  winner_team_name = params[:winner]

  winner = @temp.set_winner(winner_team_name)
  @temp.set_loser(winner)
  redirect "/mmr_update"
end

get "/mmr_update" do
  @temp.delete_pregame_teams
  @matchup_data = @temp.matchup_data
  @winner = @temp.winner
  @loser = @temp.loser
  @mmr_gain = @temp.calculate_mmr(@winner, @loser) #|| matchup_data[:mmr_gain]
  @temp.set_matchup_mmr_gain(@mmr_gain)
  
  unless @matchup_data[:played?]
    @temp.update_matchup_session_full
    @db.update_matchup_db_full(@winner, @loser, @mmr_gain)
  end

  @winning_players = @winner[:roster]
  @losing_players = @loser[:roster]
  @winning_name = @winner[:name]
  @losing_name = @loser[:name]
  @winning_mmr = @winner[:team_mmr]
  @losing_mmr = @loser[:team_mmr]
  
  erb :mmr_update
end





