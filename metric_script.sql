
-- Filter out mid-at-bat events
create view non_duplicates as (
select * from mlb_games m1 where not exists (select * from mlb_games where game_id = m1.game_id and event_id - 1 = m1.event_id and batter = m1.batter) order by game_id
);

-- View to combine before and after at-bat game states - materialized to speed up later queries
create materialized view event_dataset as (
	select * from (
	select d1.game_id, d1.event_id, d1.inning, d1.team, d1.batter, d1.pitcher, d1.batting_runs, coalesce(d2.batting_runs, d1.batting_runs) as new_batting_runs, d1.outs, coalesce(d2.outs, 0) as new_outs, d1.rob, coalesce(d2.rob, '---') as new_rob, row_number() over (partition by d1.game_id, d1.event_id order by d2.event_id nulls last) as r
	from non_duplicates d1
	left join non_duplicates d2 on d1.game_id = d2.game_id and d1.inning = d2.inning and d1.event_id < d2.event_id
	) tt where r = 1
);

-- Expected runs added for each outs/runners on base combination
create view expected_runs_added as (
	select outs, rob, avg(new_batting_runs - batting_runs) as expected_runs_added, count(*) as tot
	from event_dataset
	group by outs, rob
);

-- Average batter increase of expected runs (min 100 at bats)
select * from (
	select substring(game_id, 4, 4) as _year, team, batter, round(avg((new_batting_runs - batting_runs) + (exp2.expected_runs_added - exp1.expected_runs_added)), 5) as avg_increase_of_expected_runs, count(*) as at_bats
	from event_dataset ed
	left join expected_runs_added exp1 using (outs, rob)
	left join expected_runs_added exp2 on exp2.outs = ed.new_outs and exp2.rob = ed.new_rob
	group by substring(game_id, 4, 4), team, batter
) stats
where at_bats >= 100
order by avg_increase_of_expected_runs desc;

-- Average pitcher increase of expected runs (min 100 batters faced)
select * from (
	select substring(game_id, 4, 4) as _year, case when ed.team = game_teams.team then opposing_team else game_teams.team end as team, pitcher, round(avg((new_batting_runs - batting_runs) + (exp2.expected_runs_added - exp1.expected_runs_added)), 5) as avg_increase_of_expected_runs, count(*) as batters_faced
	from event_dataset ed
	left join (select distinct game_id, team, substring(game_id, 1, 3) as opposing_team from mlb_games where substring(game_id, 1, 3) != team) game_teams using (game_id)
	left join expected_runs_added exp1 using (outs, rob)
	left join expected_runs_added exp2 on exp2.outs = ed.new_outs and exp2.rob = ed.new_rob
	group by substring(game_id, 4, 4), case when ed.team = game_teams.team then opposing_team else game_teams.team end, pitcher
) stats
where batters_faced >= 100
order by avg_increase_of_expected_runs;

-- Average team batting increase of expected runs
select * from (
	select substring(game_id, 4, 4) as _year, team, round(avg((new_batting_runs - batting_runs) + (exp2.expected_runs_added - exp1.expected_runs_added)), 5) as avg_increase_of_expected_runs, count(*) as at_bats
	from event_dataset ed
	left join expected_runs_added exp1 using (outs, rob)
	left join expected_runs_added exp2 on exp2.outs = ed.new_outs and exp2.rob = ed.new_rob
	group by substring(game_id, 4, 4), team
) stats
order by avg_increase_of_expected_runs desc;

-- Average team pitching increase of expected runs
select * from (
	select substring(game_id, 4, 4) as _year, case when ed.team = game_teams.team then opposing_team else game_teams.team end as team, round(avg((new_batting_runs - batting_runs) + (exp2.expected_runs_added - exp1.expected_runs_added)), 5) as avg_increase_of_expected_runs, count(*) as batters_faced
	from event_dataset ed
	left join (select distinct game_id, team, substring(game_id, 1, 3) as opposing_team from mlb_games where substring(game_id, 1, 3) != team) game_teams using (game_id)
	left join expected_runs_added exp1 using (outs, rob)
	left join expected_runs_added exp2 on exp2.outs = ed.new_outs and exp2.rob = ed.new_rob
	group by substring(game_id, 4, 4), case when ed.team = game_teams.team then opposing_team else game_teams.team end
) stats
order by avg_increase_of_expected_runs;

