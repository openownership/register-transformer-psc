# Register Transformer PSC

This is an application for ingesting PSC records from a Kinesis stream (published by register_ingester_psc) and transforming into BODS v0.2 records. These records are then stored in Elasticsearch and optionally emitted into their own Kinesis stream.

## One-time Setup

### Configuration

Create a .env file with the keys populated from the .env.example file.
```
ELASTICSEARCH_HOST=
ELASTICSEARCH_PORT=
ELASTICSEARCH_PROTOCOL=
ELASTICSEARCH_SSL_VERIFY=
ELASTICSEARCH_PASSWORD=

OC_API_TOKEN=
OC_API_TOKEN_PROTECTED=

BODS_S3_BUCKET_NAME=
BODS_AWS_REGION=
BODS_AWS_ACCESS_KEY_ID=
BODS_AWS_SECRET_ACCESS_KEY=

REDIS_HOST=127.0.0.1
REDIS_PORT=6379

PSC_STREAM=psc-test-stream
BODS_STREAM=bods-test-stream
```

### Build

```shell
bin/build
```

### Create ES indexes

```shell
bin/run setup_indexes
```

### Start Redis

An instance of Redis must be accessible. One can be started on localhost by running:

```shell
docker-compose up -d register_transformer_psc_redis
```

### Run Transformer

Redis must be running first. To start the transformer, run:

```shell
bin/run transform
```

## Test

To execute the tests, run:

```
bin/test
```
