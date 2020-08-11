------------------------------------------------------------------------
-- Load the 2019 data
------------------------------------------------------------------------
DROP TABLE IF EXISTS pga2019;

CREATE EXTERNAL TABLE IF NOT EXISTS pga2019 (PlayerName STRING, Date_ DATE, StatGroup STRING, Stat STRING, Value STRING) ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' LOCATION '/user/maria_dev/final/pga/2019' tblproperties ("skip.header.line.count"="1");

------------------------------------------------------------------------
-- Load the 2010 - 2018 data
------------------------------------------------------------------------
DROP TABLE IF EXISTS pgahist;

CREATE EXTERNAL TABLE IF NOT EXISTS pgahist (PlayerName STRING, Season STRING, StatGroup STRING, Stat STRING, Value STRING) ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' LOCATION '/user/maria_dev/final/pga/hist' tblproperties ("skip.header.line.count"="1");

------------------------------------------------------------------------
-- Combine the 2019 and historical data
------------------------------------------------------------------------
DROP VIEW IF EXISTS pgastats;

CREATE VIEW pgastats AS
SELECT
      PlayerName
    , '2019' AS Season
    , CASE Stat WHEN "Driving Distance - (ROUNDS)" THEN "Rounds Played" ELSE Stat END AS Stat
    , CAST(Value AS DOUBLE) AS Value
FROM 
    pga2019
WHERE
        Date_ = '2019-08-25' -- Stats are cummulative, this is the last day of 2019 season
    AND Stat IN ("Driving Distance - (ROUNDS)","Driving Distance - (AVG.)","Driving Accuracy Percentage - (%)","Greens in Regulation Percentage - (%)","Putting Average - (AVG)","Scoring Average (Actual) - (AVG)","Official Money - (YTD VICTORIES)","Sand Save Percentage - (%)","Scoring Average - (AVG)","Scrambling - (%)","Top 10 Finishes - (TOP 10)","Top 10 Finishes - (1ST)","Putting from Inside 5' - (%)","Putting from 5-10' - (%)","Putting from - 10-15' - (% MADE)","Putting from - 15-20' - (% MADE)","Putting from - 20-25' - (% MADE)","Putting from - > 25' - (% MADE)","Club Head Speed - (AVG.)","Ball Speed - (AVG.)")

UNION ALL

SELECT
      PlayerName
    , Season
    , CASE Stat WHEN "Driving Distance - (ROUNDS)" THEN "Rounds Played" ELSE Stat END AS Stat
    , CAST(Value AS DOUBLE) AS Value
FROM
    pgahist
WHERE
    Stat IN ("Driving Distance - (ROUNDS)","Driving Distance - (AVG.)","Driving Accuracy Percentage - (%)","Greens in Regulation Percentage - (%)","Putting Average - (AVG)","Scoring Average (Actual) - (AVG)","Official Money - (YTD VICTORIES)","Sand Save Percentage - (%)","Scoring Average - (AVG)","Scrambling - (%)","Top 10 Finishes - (TOP 10)","Top 10 Finishes - (1ST)","Putting from Inside 5' - (%)","Putting from 5-10' - (%)","Putting from - 10-15' - (% MADE)","Putting from - 15-20' - (% MADE)","Putting from - 20-25' - (% MADE)","Putting from - > 25' - (% MADE)","Club Head Speed - (AVG.)","Ball Speed - (AVG.)");

------------------------------------------------------------------------
-- Q1 Who was the worst scrambler (scramble = score of par or better 
-- without a green in regulation = ball on green in two strokes less
-- than par) who won a tournament in each season?
------------------------------------------------------------------------

SELECT
	  sq.playername
	, sq.scrambling
	, sq.season
FROM (
	SELECT
	  	  x.season
	    , x.value AS scrambling
	    , x.playername
	    , RANK() OVER(PARTITION BY x.season ORDER BY x.value ASC) AS ranked
	FROM
		pgastats x,
		pgastats y
	WHERE
		    x.stat = "Scrambling - (%)"
		AND x.playername = y.playername
		AND x.season = y.season
		AND y.stat = "Top 10 Finishes - (1ST)"
		AND y.value > 0
		AND y.value IS NOT NULL) sq
WHERE
	sq.ranked = 1
ORDER BY
	sq.season DESC;

------------------------------------------------------------------------
-- Q2. Which player had the biggest difference between percent of putts
-- made outside 25 feet minus percent of putts made inside 5 feet in the
-- same season?
------------------------------------------------------------------------

SELECT
	  sq.playername
	, sq.season
FROM (
	SELECT
		  x.playername
		, x.value AS LongPuttPct
		, y.value AS ShortPuttPct
		, RANK() OVER(ORDER BY x.value - y.value DESC) AS ranked
		, x.season
	FROM
		  pgastats x
		, pgastats y
	WHERE
			x.playername = y.playername
		AND x.season = y.season
		AND x.stat = "Putting from - > 25' - (% MADE)"
		AND y.stat = "Putting from Inside 5' - (%)") sq
WHERE
	sq.ranked = 1;

------------------------------------------------------------------------
-- Q3. Who are the top five players with at least 10 wins with the 
-- highest percentage of their top 10 finishes are tournament wins?
------------------------------------------------------------------------
SELECT
	  sq.playername
	, ROUND(sq.pcttop10wins, 2) AS pcttop10wins
	, sq.ranked
FROM (
	SELECT
		  SUM(x.value) AS TotalTop10s
		, SUM(y.value) AS TotalWins
		, SUM(y.value)/SUM(x.value) AS PctTop10Wins
		, x.playername
		, DENSE_RANK() OVER(ORDER BY SUM(y.value)/SUM(x.value) DESC) AS ranked
	FROM
		  pgastats x
		, pgastats y
	WHERE
		x.playername = y.playername
		AND x.stat = "Top 10 Finishes - (TOP 10)"
		AND y.stat = "Top 10 Finishes - (1ST)"
		AND x.value IS NOT NULL
		AND y.value IS NOT NULL
	GROUP BY
		x.playername
	HAVING
		SUM(y.value) >= 10) sq
WHERE
	sq.ranked <= 5;

------------------------------------------------------------------------
-- Q4. Which of the following statistics is most negatively correlated
-- to Scoring Avg across all players and seasons? Avg. Driving Distance,
-- Driving Accuracy Percentage, Greens in Regulation Percentage, or
-- Scrambling Percentage?
------------------------------------------------------------------------
SELECT
	  corr(score.value, ddist.value) AS ddist
	, corr(score.value, dacc.value) AS dacc
	, corr(score.value, gir.value) AS gir
	, corr(score.value, scrmb.value) AS scrmb
FROM
	  pgastats score
	, pgastats ddist
	, pgastats dacc
	, pgastats gir
	, pgastats scrmb
WHERE
	    score.playername = ddist.playername
	AND score.playername = dacc.playername
	AND score.playername = gir.playername
	AND score.playername = scrmb.playername
	AND score.stat = "Scoring Average (Actual) - (AVG)"
	AND ddist.stat = "Driving Distance - (AVG.)"
	AND dacc.stat = "Driving Accuracy Percentage - (%)"
	AND gir.stat = "Greens in Regulation Percentage - (%)"
	AND scrmb.stat = "Scrambling - (%)"