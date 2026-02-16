# NBA Daily Data Pipeline

A serverless, event-driven data pipeline on AWS that ingests daily NBA game results into a secure, cost-optimized S3 data lake. All infrastructure is defined as code with Terraform.

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────────┐
│  AWS Cloud                                                       │
│                                                                  │
│  ┌─────────────┐    ┌─────────────────────────────────────────┐  │
│  │ EventBridge │    │         Lambda (Python 3.12)            │  │
│  │ (daily cron)│───▸│                                         │  │
│  └─────────────┘    │  1. Retrieve API key from SSM           │  │
│                     │  2. Call BallDontLie API                 │  │
│                     │  3. Write JSON to S3                     │  │
│                     └────┬──────────┬──────────┬──────────────┘  │
│                          │          │          │                  │
│                     ┌────▼───┐ ┌────▼───┐ ┌───▼──────────────┐  │
│                     │  SSM   │ │   S3   │ │ CloudWatch Logs  │  │
│                     │ Param  │ │  Data  │ │ (30-day retain)  │  │
│                     │ Store  │ │  Lake  │ └───┬──────────────┘  │
│                     │ (KMS)  │ │ (KMS)  │     │                  │
│                     └────────┘ └────────┘ ┌───▼──────────────┐  │
│                                           │ CloudWatch Alarm │  │
│  ┌──────────────────┐                     │   (error >= 1)   │  │
│  │  BallDontLie API │                     └───┬──────────────┘  │
│  │ (external, HTTPS)│                         │                  │
│  └──────────────────┘                     ┌───▼──────────────┐  │
│                                           │   SNS (email)    │  │
│                                           └──────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

## Data Flow

1. **Trigger** — EventBridge fires a cron rule daily at 8:00 AM UTC.
2. **Credential Retrieval** — Lambda fetches the API key from SSM Parameter Store, which decrypts the SecureString value via KMS at runtime.
3. **Data Ingestion** — Lambda calls the [BallDontLie API](https://www.balldontlie.io/) (`/v1/games`) over HTTPS for yesterday's game results.
4. **Storage** — Game data is serialized as JSON and written to S3 at a date-partitioned key path:
   ```
   games/YYYY/MM/DD/games.json
   ```
5. **Observability** — Every execution is logged to CloudWatch Logs (30-day retention). If the Lambda errors, a CloudWatch Alarm triggers an SNS email notification.

## Security Architecture

| Layer | Mechanism | Detail |
|---|---|---|
| **Secrets** | SSM Parameter Store (SecureString) | API key encrypted at rest with KMS — never in source code or env vars |
| **IAM** | Least-privilege Lambda role | Can only `s3:PutObject` to one bucket and `ssm:GetParameter` for one parameter |
| **Data at rest** | SSE-KMS with bucket key | All S3 objects encrypted; bucket key reduces KMS API call costs by ~99% |
| **Data in transit** | HTTPS | All external API calls and AWS SDK calls use TLS |
| **Access control** | S3 Block Public Access | All four block-public-access settings enabled |
| **Versioning** | S3 versioning | Protects against accidental overwrites or deletions |
| **Source control** | `.gitignore` | `terraform.tfvars`, state files, and build artifacts excluded from git |

## Infrastructure as Code

The entire stack is defined in **~250 lines of Terraform HCL** across modular files:

```
├── main.tf              # AWS provider, version constraints (>= 1.5), default tags
├── variables.tf         # Input variables: region, schedule, Lambda config, API key (sensitive)
├── outputs.tf           # Exported resource identifiers (ARNs, bucket name)
│
├── s3.tf                # S3 bucket, SSE-KMS encryption, versioning, Glacier lifecycle
├── lambda.tf            # Lambda function, IAM role + policy, CloudWatch log group
├── eventbridge.tf       # Scheduled rule (cron), Lambda target, invoke permission
├── secrets.tf           # SSM Parameter Store entry (SecureString)
├── cloudwatch.tf        # CloudWatch alarm + SNS topic + email subscription
│
└── lambda/
    └── handler.py       # Python function: fetch API → transform → upload to S3
```

Lambda packaging is handled automatically — Terraform's `archive_file` data source zips `handler.py` at plan time, so there is no external build step.

## Key Design Decisions

| Decision | Alternative Considered | Rationale |
|---|---|---|
| **Terraform** | CloudFormation | Cloud-agnostic, cleaner HCL syntax, stronger ecosystem and module registry |
| **SSM Parameter Store** | Environment variables, Secrets Manager | KMS-encrypted SecureString at no cost (standard tier); avoids plaintext secrets |
| **`urllib` (stdlib)** | `requests` library | Zero external dependencies — no Lambda layer, no packaging complexity, minimal cold start |
| **Date-partitioned S3 keys** | Flat key structure | Enables partition pruning with Athena/Glue without full-bucket scans |
| **KMS with bucket key** | SSE-S3 | Stronger key management with reduced per-object KMS API costs |
| **128 MB / 30s Lambda** | Higher memory | Workload is I/O-bound (one API call + one S3 put); minimal compute needed |

## Cost Optimization

The pipeline runs entirely within the **AWS Free Tier** at $0.00/month:

- **Lambda** — 1 invocation/day is well within 1M free invocations
- **S3** — Daily JSON files (~2 KB each) are negligible against the 5 GB free tier
- **Glacier lifecycle** — Objects automatically transition after 90 days, reducing long-term storage costs by ~94%
- **KMS bucket key** — Reduces encryption API calls from per-object to per-bucket, cutting KMS costs by ~99%
- **EventBridge, SSM, SNS, CloudWatch** — All free at this usage level

## Future Enhancements

- **Athena integration** — SQL queries over the date-partitioned data lake
- **CI/CD pipeline** — GitHub Actions for `terraform plan` on PR, `terraform apply` on merge
- **Player statistics** — Expand ingestion to player-level box scores
- **Daily digest** — SNS-based email/SMS summary of scores
