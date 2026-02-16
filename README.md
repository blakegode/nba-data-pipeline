# NBA Daily Data Pipeline

A serverless data pipeline on AWS that fetches daily NBA game results and stores them in a secure, cost-optimized S3 data lake — fully deployed with Terraform.

**Skills demonstrated:** AWS Lambda, S3, EventBridge, SSM Parameter Store, IAM, CloudWatch, SNS, Terraform (IaC), Python, API integration, cloud security, cost optimization

## Architecture

```
EventBridge (daily cron)
       │
       ▼
Lambda (Python 3.12)  ──▸  SSM Parameter Store (API key)
       │
       ▼
BallDontLie API (/v1/games)
       │
       ▼
S3 Bucket (SSE-KMS, versioned, lifecycle)
  └── games/YYYY/MM/DD/games.json
```

**How it works:**

1. **EventBridge** fires a cron rule daily at 8:00 AM UTC
2. **Lambda** retrieves the API key from **SSM Parameter Store** (SecureString) and fetches yesterday's NBA game results from the [BallDontLie API](https://www.balldontlie.io/)
3. Game data is written as JSON to **S3** at a date-partitioned key path (`games/YYYY/MM/DD/games.json`)
4. Execution is logged to **CloudWatch Logs** with 30-day retention

## Security

- API key stored in **SSM Parameter Store** (SecureString, KMS-encrypted) — never in source code or environment variables
- Lambda IAM role follows **least-privilege**: can only write to one S3 bucket and read one SSM parameter
- S3 bucket is **encrypted at rest** (SSE-KMS), **versioned**, and **blocks all public access**
- `terraform.tfvars` and state files are excluded via `.gitignore`

## Cost

| Resource | Estimated Monthly Cost |
|---|---|
| Lambda | $0.00 (free tier) |
| S3 | $0.00 (free tier) |
| SSM Parameter Store | $0.00 (free for standard params) |
| CloudWatch Logs | $0.00 (free tier) |
| SNS | $0.00 (free tier) |
| EventBridge | $0.00 (always free) |

Objects transition to **Glacier** after 90 days to reduce long-term storage costs.

## Project Structure

```
├── main.tf                    # Provider config, version constraints, default tags
├── variables.tf               # Input variables with types and defaults
├── outputs.tf                 # Deployment output values
├── s3.tf                      # S3 bucket + encryption + versioning + lifecycle
├── lambda.tf                  # Lambda function + IAM role/policy + CloudWatch logs
├── eventbridge.tf             # Scheduled rule + target + Lambda permission
├── secrets.tf                 # SSM Parameter Store (SecureString) for the API key
├── cloudwatch.tf              # CloudWatch alarm + SNS topic for error alerts
├── terraform.tfvars.example   # Template — copy to terraform.tfvars and add your API key
├── .gitignore                 # Excludes secrets, state files, build artifacts
└── lambda/
    └── handler.py             # Python Lambda function (fetch API + upload to S3)
```

## Setup & Deployment

### Prerequisites

- AWS account with CLI configured (`aws configure`)
- Terraform >= 1.5
- BallDontLie API key ([app.balldontlie.io](https://app.balldontlie.io))

### Deploy

```bash
git clone https://github.com/YOUR_USERNAME/nba-data-pipeline.git
cd nba-data-pipeline

cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — paste in your API key

terraform init
terraform plan
terraform apply
```

### Test

```bash
aws lambda invoke --function-name nba-data-pipeline-fetcher --payload '{}' response.json
cat response.json
```

Example output:
```json
{
  "date": "2026-02-12",
  "games_found": 3,
  "s3_key": "games/2026/02/12/games.json",
  "games": [
    {"matchup": "Milwaukee Bucks @ Oklahoma City Thunder", "score": "110 - 93", "status": "Final"},
    {"matchup": "Portland Trail Blazers @ Utah Jazz", "score": "135 - 119", "status": "Final"},
    {"matchup": "Dallas Mavericks @ Los Angeles Lakers", "score": "104 - 124", "status": "Final"}
  ]
}
```

### Teardown

```bash
aws s3 rm s3://nba-data-lake-YOUR_ACCOUNT_ID --recursive
terraform destroy
```

## Design Decisions

- **Terraform over CloudFormation** — cloud-agnostic, cleaner HCL syntax, widely adopted in industry
- **SSM Parameter Store over env vars** — SecureString encrypted with KMS, free for standard parameters, no secrets in plaintext
- **`urllib` over `requests`** — no external dependencies, no Lambda layer needed, minimal cold start
- **Date-partitioned S3 keys** — enables efficient querying with Athena without full bucket scans
- **KMS with bucket key** — strong encryption with reduced API call costs

## Future Enhancements

- Athena integration for SQL queries on game data
- CI/CD pipeline with GitHub Actions
- Player statistics collection
- Daily score summary via SNS (email/SMS)
