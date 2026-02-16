import json
import logging
import os
import urllib.request
import urllib.error
from datetime import datetime, timedelta, timezone

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

S3_BUCKET_NAME = os.environ["S3_BUCKET_NAME"]
SSM_PARAM_NAME = os.environ["SSM_PARAM_NAME"]

s3_client = boto3.client("s3")
ssm_client = boto3.client("ssm")


def get_api_key():
    """Retrieve the BallDontLie API key from SSM Parameter Store."""
    response = ssm_client.get_parameter(Name=SSM_PARAM_NAME, WithDecryption=True)
    return response["Parameter"]["Value"]


def fetch_games(api_key, date_str):
    """Fetch NBA games for a given date from the BallDontLie API."""
    url = f"https://api.balldontlie.io/v1/games?dates[]={date_str}"
    request = urllib.request.Request(url)
    request.add_header("Authorization", api_key)

    try:
        with urllib.request.urlopen(request) as response:
            data = json.loads(response.read().decode("utf-8"))
            logger.info("API returned %d games for %s", len(data.get("data", [])), date_str)
            return data
    except urllib.error.HTTPError as e:
        logger.error("HTTP error %d fetching games: %s", e.code, e.reason)
        raise
    except urllib.error.URLError as e:
        logger.error("URL error fetching games: %s", e.reason)
        raise


def upload_to_s3(data, date_obj):
    """Upload game data as JSON to S3 with date-partitioned key."""
    s3_key = f"games/{date_obj.strftime('%Y/%m/%d')}/games.json"
    s3_client.put_object(
        Bucket=S3_BUCKET_NAME,
        Key=s3_key,
        Body=json.dumps(data, indent=2),
        ContentType="application/json",
    )
    logger.info("Uploaded data to s3://%s/%s", S3_BUCKET_NAME, s3_key)
    return s3_key


def lambda_handler(event, context):
    """Main Lambda entry point — fetch yesterday's NBA games and store in S3."""
    logger.info("Lambda invoked with event: %s", json.dumps(event))

    yesterday = datetime.now(timezone.utc) - timedelta(days=1)
    date_str = yesterday.strftime("%Y-%m-%d")
    logger.info("Fetching games for date: %s", date_str)

    api_key = get_api_key()
    game_data = fetch_games(api_key, date_str)
    s3_key = upload_to_s3(game_data, yesterday)

    games = game_data.get("data", [])
    game_summaries = []
    for game in games:
        home = game.get("home_team", {})
        visitor = game.get("visitor_team", {})
        matchup = f"{visitor.get('full_name', 'Unknown')} @ {home.get('full_name', 'Unknown')}"
        score = f"{game.get('visitor_team_score', 0)} - {game.get('home_team_score', 0)}"
        game_summaries.append({
            "matchup": matchup,
            "score": score,
            "status": game.get("status", "Unknown"),
        })

    result = {
        "date": date_str,
        "games_found": len(games),
        "s3_key": s3_key,
        "games": game_summaries,
    }
    logger.info("Result: %s", json.dumps(result))
    return result
