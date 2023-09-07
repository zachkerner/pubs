CREATE TABLE teams (
id serial PRIMARY KEY,
name varchar(35) UNIQUE NOT NULL
);

CREATE TABLE players (
id serial PRIMARY KEY,
name varchar(25) UNIQUE NOT NULL,
height int NOT NULL CHECK (height BETWEEN 121 AND 218),
position text NOT NULL,
attribute text NOT NULL,
role text NOT NULL,
mmr int NOT NULL,
team_id int REFERENCES teams(id) DEFAULT NULL,
team_name varchar(35) DEFAULT NULL
);



