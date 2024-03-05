# Register Transformer PSC

Register Transformer PSC is a data transformer for the [OpenOwnership](https://www.openownership.org/en/) [Register](https://github.com/openownership/register) project.
It processes bulk data published to [AWS S3](https://aws.amazon.com/s3/), such as emitted from [AWS Kinesis Data Firehose](https://aws.amazon.com/kinesis/data-firehose/), converts them into the [Beneficial Ownership Data Standard (BODS)](https://www.openownership.org/en/topics/beneficial-ownership-data-standard/) format, and stores records in [Elasticsearch](https://www.elastic.co/elasticsearch/). Optionally, it can also use [AWS Kinesis](https://aws.amazon.com/kinesis/) for processing streamed data (rather than bulk data published to AWS S3), or for publishing newly-transformed records to a different stream.

The transformation schema is [BODS 0.2](https://standard.openownership.org/en/0.2.0/schema/schema-browser.html).

## Installation

Install and boot [Register](https://github.com/openownership/register).

Configure your environment using the example file:

```sh
cp .env.example .env
```

Create the Elasticsearch indexes:

```sh
docker compose run transformer-psc create-indexes
docker compose run transformer-psc create-indexes-companies
```

## Testing

Run the tests:

```sh
docker compose run transformer-psc test
```

## Usage

To transform the bulk data from a prefix in AWS S3:

```sh
docker compose run transformer-psc transform-bulk raw_data/source=PSC/year=2023/month=10/
```
