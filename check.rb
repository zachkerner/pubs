require "pg"
require_relative "db"

class InputValidation

  def initialize
    @db_access = PG.connect(dbname: "pubs")
    @db_methods = DatabasePersistence.new
  end

  def param_just_number?(qs_param)
    return true if qs_param.nil?
    qs_param.scan(/\D/).empty?
  end

  def page_error(page_number, collection_size)
    if collection_size % 5 == 0 && collection_size != 0
      return "Page does not exist" if collection_size / 5 <= page_number - 1
    else
      return "Page does not exist" if collection_size / 5 < page_number - 1
    end
  end

  def player_create_error(name, height, position, attribute, role, mmr)
    name_error = player_create_update_name_error(name)
    height_error = height_error(height)
    if name_error
      return name_error
    elsif height_error
      return height_error
    elsif position.nil?
      return "Please select a position."
    elsif attribute.nil?
      return "Please select an attribute."
    elsif role.nil?
      return "Please select a role."
    elsif mmr.nil?
      return "Please select an mmr."
    end
    nil
  end

  def valid_player_id?()
  end

  def player_update_error(original_name, name, height, position, attribute, role)
    original_name == name ? name_error = nil : name_error = player_create_update_name_error(name)
    height_error = height_error(height)
    
    if name_error
      return name_error
    elsif height_error
      return height_error
    elsif position.nil?
      return "Please select a position."
    elsif attribute.nil?
      return "Please select an attribute."
    elsif role.nil?
      return "Please select a role."
    end
    nil
  end

  def team_create_error(name, roster, collection_input_size)
    name_error = team_create_name_error(name)
    roster_error = team_create_roster_error(roster, collection_input_size)

    if name_error
      return name_error
    elsif roster_error
      return roster_error
    end
    nil
  end

  def add_player_roster_error(player_name, player_id, team_id)
    roster = @db_methods.roster_from_team_id(team_id)
    return "Please enter a player name." if player_name.nil? || player_name.empty?
    return "Player not found." unless player_exist?(player_id)
    return "Player already on roster." if player_on_roster?(player_id, team_id)
    return "Team already full." if team_size_too_big?(roster)
    return not_free_agent?(roster, team_id) if not_free_agent?(roster, team_id)
    nil
  end

  def team_update_name_error(original_name, name)
    return nil if original_name == name
    team_create_name_error(name)
  end

  def play_error(team1_name, team2_name)
    return "Please enter two teams." if teams?(team1_name, team2_name)
    return "Please enter two distinct teams." unless different_teams?(team1_name, team2_name)
    return "One or more teams do not exist in our record." unless valid_teams?(team1_name, team2_name)
    return "Both teams must have full rosters (3 players)." unless full_roster?(team1_name, team2_name)
    nil
  end

  private

  def first_row(result)
    result.values.first.first
  end

  def player_create_update_name_error(name)
    player_name_max_size = 25
    return "Please enter a name." if name.nil? || name.empty?
    return "Please enter a name up to 25 characters." if name.size > player_name_max_size
    return "Player name already in use." if player_name_unique?(name)
    nil
  end

  def height_error(height)
    return "Please enter height." if height.nil?
    height = height.to_i
    return "Please enter height in cm between 121 (4 feet) and 218 (7 foot 2)." unless (121..218).cover?(height)
    nil
  end

  def player_name_unique?(name)
    sql = "SELECT COUNT(*) FROM players WHERE name=$1"
    result = @db_access.exec_params(sql, [name])
    first_row(result).to_i > 0
  end

  def player_exist?(player_id)
    sql = "SELECT COUNT(*) FROM players WHERE id=$1"
    result = @db_access.exec_params(sql, [player_id])
    first_row(result).to_i != 0
  end

  def team_create_name_error(name)
    return "Please enter a name." if name.nil? || name.empty?
    return "Please enter a name up to 25 characters." if name.size > 24
    return "Team name already in use." if team_name_unique?(name)
    nil
  end

  def team_name_unique?(name)
    sql = "SELECT COUNT(*) FROM teams WHERE name=$1"
    result = @db_access.exec_params(sql, [name])
    first_row(result).to_i > 0
  end
  
  def team_create_roster_error(roster, collection_input_size)
    return "Registering teams must have at least one valid player." if team_size_too_small?(roster)
    return "The same player may only be registered once."  if players_unique?(roster)
    return "You can only register valid players." if one_player_invalid?(roster, collection_input_size)
    return "A player is already registered for another team." if already_registered?(roster)
    nil
  end

  def team_size_too_small?(roster)
    roster.size < 1
  end

  def team_size_too_big?(roster)
    roster.size == 3
  end
  
  def players_unique?(roster)
    hash = roster.each_with_object({}) { |i, hsh| hsh[i] ? hsh[i] += 1 : hsh[i] = 1 }
    return true if hash.any? { |k, v| hash[k] > 1 }
    nil
  end
  
  def already_registered?(roster)
    roster.each do |player|
      return true unless player[:team_id] == nil
    end
    nil
  end

  def one_player_invalid?(roster, collection_input_size)
    roster.size != collection_input_size
  end

  def not_free_agent?(roster, team_id)
    roster.each do |player|
      next if player[:team_id].nil?
      return [team_id, player[:team_id]] if player[:team_id].to_i != team_id
    end
    nil
  end
  
  def player_on_roster?(player_id, team_id)
    sql = "SELECT COUNT(*) FROM players WHERE id=$1 AND team_id=$2"
    result = @db_access.exec_params(sql, [player_id, team_id])
    first_row(result).to_i == 1
  end

  def teams?(team1, team2)
    team1.nil? || team2.nil?
  end
  
  def different_teams?(team1_name, team2_name)
    team1_name != team2_name
  end

  def valid_teams?(team1_name, team2_name)
    sql = "SELECT COUNT(*) FROM teams WHERE name=$1 OR name=$2"
    result = @db_access.exec_params(sql, [team1_name, team2_name])
    first_row(result).to_i == 2
  end

  def full_roster?(team1_name, team2_name)
    expected_player_number = 6
    sql = "SELECT COUNT(*) FROM players WHERE team_name=$1 OR team_name=$2"
    result = @db_access.exec_params(sql, [team1_name, team2_name])
    first_row(result).to_i == expected_player_number
  end

end
