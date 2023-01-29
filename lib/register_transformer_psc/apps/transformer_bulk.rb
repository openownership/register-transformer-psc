require 'redis'

require 'register_transformer_psc/config/settings'
require 'register_transformer_psc/config/adapters'
require 'register_sources_bods/services/publisher'
require 'register_transformer_psc/bods_mapping/record_processor'
require 'register_sources_psc/structs/company_record'
require 'register_sources_oc/services/resolver_service'
require 'register_common/services/file_reader'

$stdout.sync = true

module RegisterTransformerPsc
  module Apps
    class TransformerBulk
      BATCH_SIZE = 25
      NAMESPACE = 'PSC_TRANSFORMER_BULK'

      def self.bash_call(args)
        s3_prefix = args.last

        TransformerBulk.new.call(s3_prefix)
      end

      def initialize(s3_adapter: nil, bods_publisher: nil, entity_resolver: nil, bods_mapper: nil, redis: nil, s3_bucket: nil, file_reader: nil)
        @s3_adapter = s3_adapter || RegisterTransformerPsc::Config::Adapters::S3_ADAPTER
        bods_publisher ||= RegisterSourcesBods::Services::Publisher.new
        entity_resolver ||= RegisterSourcesOc::Services::ResolverService.new
        @bods_mapper = bods_mapper || RegisterTransformerPsc::BodsMapping::RecordProcessor.new(
          entity_resolver: entity_resolver,
          bods_publisher: bods_publisher
        )
        @redis = redis || Redis.new(host: ENV['REDIS_HOST'], port: ENV['REDIS_PORT'])
        @s3_bucket = s3_bucket || ENV.fetch('BODS_S3_BUCKET_NAME')
        @file_reader = file_reader || RegisterCommon::Services::FileReader.new(s3_adapter: @s3_adapter, batch_size: BATCH_SIZE)
      end

      def call(s3_prefix)
        print("Calling with s3_prefix: ", s3_prefix, "FOR BUCKET: ", s3_bucket, "\n")
        s3_paths = s3_adapter.list_objects(s3_bucket: s3_bucket, s3_prefix: s3_prefix)
        print("GOT #{s3_paths.length} S3 Paths: ", s3_paths, "\n")

        s3_paths.each do |s3_path|
          print "Trying #{s3_path}\n"
          if file_processed?(s3_path)
            print "Skipping #{s3_path}\n"
          end

          file_reader.read_from_s3(s3_bucket: s3_bucket, s3_path: s3_path) do |rows|
            process_rows rows
          end

          mark_file_complete(s3_path)
          print "Completed #{s3_path}\n"
        end
      end

      private

      attr_reader :bods_mapper, :redis, :s3_bucket, :s3_adapter, :file_reader

      def process_rows(rows)
        records = rows.map do |record_data|
          record = JSON.parse(record_data, symbolize_names: true)
          RegisterSourcesPsc::CompanyRecord[**record]
        end

        bods_mapper.process_many records
      end

      def file_processed?(s3_path)
        redis.sismember(NAMESPACE, s3_path)
      end

      def mark_file_complete(s3_path)
        redis.sadd(NAMESPACE, [s3_path])
      end
    end
  end
end
