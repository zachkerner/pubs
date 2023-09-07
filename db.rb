require "pg"

class DatabasePersistence

  def initialize
    @db = PG.connect(dbname: "pubs")
  end

  def seed_basic
    sql = <<-SQL
    INSERT INTO players (name, height, position, attribute, role, mmr)
    VALUES ('Korner', 181, 'big', 'strength', 'support', 1000),
    ('Sean', 179, 'guard', 'agility', 'carry', 1200),
    ('Max', 174, 'guard', 'strength', 'support', 800),
    ('G', 174, 'guard', 'agility', 'carry', 1000),
    ('Kevin', 178, 'guard', 'agility', 'support', 1000),
    ('JP', 180, 'guard', 'agility', 'carry', 1200),
    ('Twin 1', 182, 'big', 'strength', 'carry', 1000),
    ('Twin 2', 182, 'big', 'strength', 'carry', 1000),
    ('Levi', 191, 'big', 'strength', 'carry', 1200),
    ('Brianna', 174, 'guard', 'intelligence', 'support', 1000),
    ('Michelle', 178, 'wing', 'agility', 'carry', 1200),
    ('David L', 180, 'guard', 'agility', 'support', 1000),
    ('Big Doof', 195, 'big', 'strength', 'support', 600),
    ('TJ', 184, 'wing', 'agility', 'carry', 1000),
    ('Dong Lu', 171, 'guard', 'intelligence', 'support', 1000),
    ('Jalal', 175, 'wing', 'agility', 'carry', 800),
    ('Maiss', 174, 'wing', 'intelligence', 'carry', 1200),
    ('Chaim', 183, 'big', 'strength', 'support', 600),
    ('Barack Obama', 182, 'wing', 'agility', 'carry', 1200),
    ('Hercules', 191, 'big', 'strength', 'carry', 1400)
    SQL
    @db.exec_params(sql)
  end

  def players
    sql = "SELECT * FROM players"
    result = @db.exec_params(sql)
    result.map do |tuple|
      player_hash_from_db_row(tuple)
    end
  end

  def player_from_id(player_id)
    sql = "SELECT * FROM players WHERE id=$1"
    result = @db.exec_params(sql, [player_id])
    return nil if result.values.empty?
    player_hash_from_db_row(result.tuple(0))
  end

  def player_from_name(player_name)
    return nil if player_name.nil?
    sql = "SELECT * FROM players WHERE name=$1"
    result = @db.exec_params(sql, [player_name])
    return nil if result.nil? || empty?(result)
    player_hash_from_db_row(result.tuple(0))
  end

  def player_from_roster(team, roster_id)
    #team[:roster][roster_id]
  end

  def player_id_from_name(name)
    return nil if name.nil? || name.empty?
    sql = "SELECT id FROM players WHERE name=$1"
    result = @db.exec_params(sql, [name])
    return nil if result.values.empty?
    first_entry(result)
  end

  def assemble_player(name, height, position, attribute, role, mmr)
    {
        name: name, height: height, position: position, 
        attribute: attribute, role: role, mmr: mmr.to_i, 
        team: default_null_team
        }
  end

  def add_player(player)
    sql = "INSERT INTO players (name, height, position, attribute, role, mmr)
    VALUES ($1, $2, $3, $4, $5, $6)"
    @db.exec_params(sql, [player[:name], player[:height], player[:position], player[:attribute], player[:role], player[:mmr]])
  end

  def update_player(id, name, height, position, attribute, role)
    sql = <<-SQL
      UPDATE players
      SET name=$1, height=$2, position=$3, attribute=$4, role=$5
      WHERE id=$6
    SQL
    @db.exec_params(sql, [name, height, position, attribute, role, id])
  end

  def delete_player_full(player, team)
    # delete_player(player)
    #update_team_mmr(team)
  end

  def delete_player(player_id)
    sql = "DELETE FROM players WHERE id=$1"
    @db.exec_params(sql, [player_id])
  end

  def delete_all_players_full
    delete_all_players
    #wipe_team_rosters
    #reset_mmr_all_teams
  end

  def teams
    sql = "SELECT * FROM teams"
    result = @db.exec_params(sql)
    result.map do |tuple|
      roster = roster_from_team_id(tuple["id"])
      roster_mmr = average_mmr(roster)
      {id: tuple["id"], name: tuple["name"], roster: roster, roster_size: roster.size, team_mmr: roster_mmr}
    end
  end

  def team_from_id(team_id)
    sql = "SELECT * FROM teams WHERE id=$1"
    result = @db.exec_params(sql, [team_id])
    return nil if result.values.empty?
    result.map do |tuple|
      {id: tuple["id"], name: tuple["name"]}
    end[0]
  end

  def team_from_name(team_name)
    sql = "SELECT id FROM teams WHERE name=$1"
    result = @db.exec_params(sql, [team_name])
    team_id = first_entry(result).to_i
    roster = roster_from_team_id(team_id)
    {id: team_id, name: team_name, roster: roster, team_mmr: average_mmr(roster) }
  end

  def team_id_from_team_name(name)
    sql = "SELECT id FROM teams WHERE name=$1"
    result = @db.exec_params(sql, [name])
    first_entry(result).to_i
  end

  def team_name_from_id(team_id)
    sql = "SELECT name FROM teams WHERE id=$1"
    result = @db.exec_params(sql, [team_id])
    first_entry(result)
  end

  def team_mmr(team_id, roster_size)
    # return 0 if roster_size == 0
    # sql_sum = "SELECT SUM(mmr) FROM players WHERE team_id=$1"
    # result_sum = @db.exec_params(sql, [team_id])
    # result_sum.values[0][0]/to_i / roster_size
  end

  def assemble_roster(player1, player2, player3)
    [player1, player2, player3].compact
  end

  def roster_from_team_id(team_id)
    sql = "SELECT * FROM players WHERE team_id=$1"
    result = @db.exec_params(sql, [team_id])
    result.map do |tuple|
      player_hash_from_db_row(tuple)
    end
  end

  def add_team_full(name, roster)
    add_team(name)
    id = team_id_from_team_name(name)
    update_player_team(roster, name, id)
  end

  def remove_player_from_team(player_id)
    sql = "UPDATE players SET team_id = NULL, team_name = 'no team' WHERE id = #{player_id}"
    @db.exec_params(sql)
  end

  def add_team_to_player(team_id, team_name, player_id)
    sql = "UPDATE players SET team_id=$1, team_name=$2 WHERE id=$3"
    @db.exec_params(sql, [team_id, team_name,player_id])
  end

  def team_update_name_full(team_id, name)
    team_update_name(team_id, name)
    update_player_team_edit(team_id)
  end

  def delete_team_full(team_id)
    delete_players_on_team(team_id)
    delete_team(team_id)
  end

  def delete_all_teams_full
    delete_players_from_all_teams
    delete_all_teams
  end

  def delete_all_teams
    sql = "DELETE FROM teams"
    @db.exec_params(sql)
  end

  def delete_players_from_all_teams
    sql = "DELETE FROM players WHERE team_id IS NOT NULL"
    @db.exec_params(sql)
  end

  def update_matchup_db_full(winner, loser, mmr_gain)
    update_both_rosters_mmr(winner, loser, mmr_gain)
  end

  private

  def first_entry(result)
    result.values.first.first
  end

  def first_row(result)
    result.values.first
  end

  def empty?(result)
    result.values.empty?
  end

  def player_hash_from_db_row(tuple)
    {id: tuple["id"], name: tuple["name"], height: tuple["height"], position: tuple["position"], 
      attribute: tuple["attribute"], role: tuple["role"], mmr: tuple["mmr"].to_i, team_name: tuple["team_name"],
    team_id: tuple["team_id"] }
  end
  
  def delete_all_players
    sql = "DELETE FROM players"
    @db.exec_params(sql)
  end

  def add_team(name)
   sql = "INSERT INTO teams (name) VALUES ($1)"
   @db.exec_params(sql, [name])
  end

  def update_player_team(roster, name_of_team, id)
    sql = "UPDATE players SET team_id=$1, team_name=$2 WHERE name=$3"

    roster.each do |player|
      @db.exec_params(sql, [id, name_of_team, player[:name]])
    end
  end

  def update_player_team_edit(team_id)
    name_of_team = team_name_from_id(team_id)
    sql = "UPDATE players SET team_name=$1 WHERE team_id=$2"
    @db.exec_params(sql, [name_of_team, team_id])
  end

  def default_null_team
    "no team"
  end

  def team_update_name(team_id, name)
    sql = "UPDATE teams SET name=$1 WHERE id=$2"
    @db.exec_params(sql, [name, team_id])
  end

  def delete_players_on_team(team_id)
    sql = "DELETE FROM players WHERE team_id=$1"
    @db.exec_params(sql, [team_id])
  end
  
  def delete_team(team_id)
    sql = "DELETE FROM teams WHERE id=$1"
    @db.exec_params(sql, [team_id])
  end

  def average_mmr(roster)
    return 0 if roster.nil? || roster.empty?
    total = 0
    roster.each do |player|
      total += player[:mmr]
    end
    total / roster.size
  end

  def update_both_rosters_mmr(winner, loser, mmr_gain)
    update_single_roster(winner[:roster], mmr_gain)
    update_single_roster(loser[:roster], -mmr_gain)
  end

  def update_single_roster(roster, mmr_gain)
    player1_id = roster[0][:id]
    player2_id = roster[1][:id]
    player3_id = roster[2][:id]
    sql = "UPDATE players SET mmr=mmr + $1 WHERE id=$2 OR id=$3 OR id=$4"
    @db.exec_params(sql, [mmr_gain, player1_id, player2_id, player3_id])
  end
end