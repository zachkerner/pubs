Basic information and specs:

Ruby version: 2.6.3

Browser: Chrome v. 109.0.5414.119

Postgres SQL: v. 15.1 (through homebrew)

-------------

Pubs is an application that enables basketball players to play rated games without a league.

Almost every competitive video game (Dota 2, Halo, Fortnite, etc.) has added a rating system to make games more enjoyable and to leave players with a sense of 'state' as they go from game to game.

The application is from the point of the view of an administrator rather than a player. The administrator creates players and slots them into teams. Each player receives a rating or MMR, a metric of player skill and past performance. Team MMR is determined by taking the average MMR of the players on that team's roster. MMR can only be set in the player creation stage.

Full teams of three players face off in real-world competition. The app records the winner and loser. Winning players gain MMR. Losing players lose MMR. The app reports the updated stats for teams and players.

MMR is weighted, meaning that it takes into account the relative strength of players. When stronger teams defeat weaker teams, players gain or lose only a few MMR points. If a weaker team defeats a stronger team, players gain or lose many points.

Pubs introduces RPG (role playing game) elements to its player creation screen. Inspired by DoTA 2, players can customize their profile around their play type. Large players are 'bigs', medium players are 'wings' and small players are 'guards'. Players with great scoring skill are 'carries', players who rebound, pass and play defense are 'supports'. Players who use strength to win are 'strength' type. Players who use smarts and tricks are 'intelligence'. Players who exploit their quickness are 'agility'. This is aesthetic more than functional and aims to bring a 'cool' factor to the game.

--------------------

To start, head over to the terminal and input `bundle install`. Next, create the pubs data base by typing `createdb pubs` into the terminal. Make sure that you're running version 2.6.3 of Ruby and 15.1 of Postgres SQL. I used google chrome with the most updated version (as of Feb. 4 2023).

Import the schema with `psql -d pubs < schema.sql` from outside of psql but within the pubs directory.

Run the app by entering `ruby pubs.rb` in the terminal and open a chrome brower with the url set to `localhost:4567` (port number may vary).

Login with username binghamton and password 2011champs

Navigate from the home screen to players and click the 'seed basic data' button to generate a list of players. 

Players can be on a team or can be free agents. Players can shift teams but cannot be on more than one team. To switch player team, players must be removed from their current team. (Please refresh the player page after every roster move.)

Use the teams page to create two teams of 3 players. Teams can register with 1, 2 or 3 players. If all players are removed from a team, the team persists without players.

Then head over to the play page and enter the two team names. Pick a winner and see the result.

--------------------

I followed the LS185 model of app production, starting with a naive session-based implementation then separating the session logic into an independent class. From there I migrated the session logic to a database class. At this time I came to the realization that my database class was responsible for handling two distinct functions: storing data and checking data. I decided to move the checks into an input validation class represented in the top level file by `@check`.

There was the additional problem of where to store the data for the play and matchup functionality. At first I implemented this via SQL queries but became unhappy at the sheer number of queries that needed to be issued. I elected instead to store the relevant teams inside of the session so as to not overburden the data base. Only at the end of the match was it necessary to update the data in SQL.

I decided to allow players to be 'free agents' (i.e. not part of any team) unlike the todo app which mandated that todos belong to a list. Players are created without a team and persist after being removed from the team (though players are deleted if their team is deleted). Teams can also be 'free agents' by removing all players from the edit team page or simply deleting the players that makeup their roster. 

The app is from the perspective of a single administrator who creates player profiles based on their perceived play profiles and abilities. Some day I would like to recreate this app from the perspective of a user who would create their own profile and link up with other users before playing their own live 3 on 3 basketball games. In that version all users will start with the same MMR.



