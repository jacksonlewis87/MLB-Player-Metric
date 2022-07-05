import psycopg2 as psql
import requests

database_connection = conn = psql.connect("dbname=baseball user=postgres password=********")
cur = database_connection.cursor()

cur.execute('create table mlb_games (game_id varchar, event_id integer, inning varchar, batting_runs integer, pitching_runs integer, outs integer, rob varchar, pitch_count varchar, team varchar, batter varchar, pitcher varchar);')

year = '2022'
r = requests.get('https://www.baseball-reference.com/teams/BAL/2022.shtml')
text = r.text
teams = [t.split('/">')[0] for t in text.split('\n<a href="/teams/')[1:]]
teams.remove('FLA')
teams += ['MIA']

games = []

for team in teams:
    r = requests.get('https://www.baseball-reference.com/teams/' + team + '/' + year + '.shtml')
    text = r.text
    results = [t.split('</ul>')[0] for t in text.split('<ul class="timeline" ')[1:]]

    for result in results:
        for splitResult in result.split('<a href="/boxes/')[1:]:
            game = splitResult.split('.shtml"><span class="count notwin"')[0]
            if '.shtml' not in game:
                games += [game[4:]]

for game in games:
    r = requests.get('https://www.baseball-reference.com/boxes/' + game[0:3] + '/' + game + '.shtml')
    text = r.text.split('<div id="all_play_by_play"')[1].split('<h3>Play-by-Play Explanation</h3>')[0]
    eventTexts = text.split('<tr id="event_')[1:]
    for eventText in eventTexts:
        eventId = eventText.split('"')[0]
        inning = eventText.split('data-stat="inning"')[1].split('<')[0].split('>')[1]
        score = eventText.split('data-stat="score_batting_team" >')[1].split('<')[0]
        battingRuns = score.split('-')[0]
        pitchingRuns = score.split('-')[1]
        outs = eventText.split('data-stat="outs" >')[1].split('<')[0]
        rob = eventText.split('data-stat="runners_on_bases_pbp"')[1].split('<')[0].split('>')[1]
        pitchCount = eventText.split('data-stat="pitches_pbp"')[1].split('&nbsp;<')[0].split('>')[1]
        batTeam = eventText.split('"batting_team_id"')[1].split('<')[0].split('>')[1]
        batter = eventText.split('data-stat="batter"')[1].split('<')[0].split('>')[1].replace('&nbsp;', ' ')
        pitcher = eventText.split('data-stat="pitcher"')[1].split('<')[0].split('>')[1].replace('&nbsp;', ' ')

        cur.execute('insert into mlb_games (game_id, event_id, inning, batting_runs, pitching_runs, outs, rob, pitch_count, team, batter, pitcher) values (\'' + game + '\', ' + eventId + ', \'' + inning + '\', ' + battingRuns + ', ' + pitchingRuns + ', ' + outs + ', \'' + rob + '\', \'' + pitchCount + '\', \'' + batTeam + '\', $$' + batter + '$$, $$' + pitcher + '$$)')

database_connection.commit()
database_connection.close()
