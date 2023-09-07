class Session

  def initialize(session)
    @session = session

    @url = session[:url] || "/home"
    @logged_in = session[:logged_in] || false
    @username = session[:username] 

    @page_number = session[:page_number]
    @seed = session[:seed] || false
    @player = session[:player]
    @team = session[:team]
    @pregame_teams = session[:pregame_teams]

    @matchup = session[:matchup] || [{played?: false}]
    @winner = session[:winner]
    @loser = session[:loser]
  end

  def set_url(url)
    @session[:url] = url unless url == "/signin"
  end

  def url
    @session[:url]
  end

  def valid_credentials?(username, password)
    username == "binghamton" && password == "2011champs"
  end

  def username
    @session[:username]
  end

  def set_username(input)
    @session[:username] = input
  end

  def delete_username
    @session[:username] = nil
  end

  def set_logged_in
    @session[:logged_in] = true
  end

  def set_logged_out
    @session[:logged_in] = false
  end

  def logged_in?
    @session[:logged_in].nil?
  end

  def logged_out?
    @session[:logged_in].nil? || @session[:logged_in] == false
  end

  def logged_out_not_signin_page?(url)
    logged_out? && url != "/signin"
  end

  def page
    @session[:page_number]
  end

  def set_page(page_number)
    @session[:page_number] = page_number
  end

  def player
    @session[:player] || {}
  end

  def set_player(name, height, position, attribute, role, mmr)
    @session[:player] = {
      name: name, height: height, position: position,
      attribute: attribute, role: role, mmr: mmr
    }
  end

  def delete_player
    @session[:player] = {}
  end

  def team
    @session[:team] || {}
  end
  
  def set_team(team_name, player1, player2, player3)
    @session[:team] = {
      team_name: team_name, player1: player1, 
      player2: player2, player3: player3
    }
  end

  def delete_team
    @session[:team] = {}
  end

  def pregame_teams
    @session[:pregame_teams] || {}
  end

  def set_pregame_teams(team1_name, team2_name)
    @session[:pregame_teams] = {team1_name: team1_name, team2_name: team2_name}
  end

  def delete_pregame_teams
    @session[:pregame_teams] = {}
  end

  def session_matchup
    @session[:matchup]
  end

  def reset_matchup
    @session[:matchup] = [{played?: false}]
  end

  def add_teams_to_matchup(team1, team2)
    @session[:matchup].unshift(team1)
    @session[:matchup].unshift(team2)
  end

  def put_favorite_first
    team1 = @session[:matchup][0]
    team2 = @session[:matchup][1]
    team1_mmr = team1[:team_mmr]
    team2_mmr = team2[:team_mmr]
    return [team1, team2] if team1_mmr >= team2_mmr
    [team2, team1]
  end

  def calculate_mmr(winner, loser)
    winner_mmr = winner[:team_mmr]
    loser_mmr = loser[:team_mmr]
    diff = winner_mmr - loser_mmr
    if (-50..50).cover?(diff)
      return 25
    elsif (51..150).cover?(diff)
      return 20
    elsif (151..250).cover?(diff)
      return 13
    elsif diff > 250
      return 5
    elsif (-150..-51).cover?(diff)
      return 30
    elsif (-250..-151).cover?(diff)
      return 40
    elsif diff < -251
      return 50
    end
  end

  def set_winner(team_name)
    winner = @session[:matchup].find { |team| team[:name] == team_name }
    @session[:winner] = winner
  end
  
  def set_loser(winner)
    matchup_slice = @session[:matchup].slice(0..1)
    @session[:loser] = matchup_slice.find { |team| team != winner}
  end

  def winner
    @session[:winner]
  end

  def loser
    @session[:loser]
  end

  def matchup_data
    @session[:matchup][2]
  end

  def set_matchup_mmr_gain(mmr)
    @session[:matchup][2][:mmr_gain] = mmr
  end

  def update_matchup_session_full
    flip_played
    update_matchup_team_mmr
    update_matchup_player_mmr
  end

  private

  def flip_played
    @session[:matchup][2][:played?] = true
  end

  def update_matchup_team_mmr
    @winner[:team_mmr] += matchup_data[:mmr_gain]
    @loser[:team_mmr] -= matchup_data[:mmr_gain]
  end

  def update_matchup_player_mmr
    @winner[:roster].each { |player| player[:mmr] += matchup_data[:mmr_gain]}
    @loser[:roster].each { |player| player[:mmr] -= matchup_data[:mmr_gain]}
  end

end