require 'register_transformer_psc/config/settings'
require 'register_sources_bods/services/publisher'
require 'register_transformer_psc/bods_mapping/record_processor'
require 'register_sources_psc/structs/company_record'
require 'register_sources_oc/services/resolver_service'
require 'register_common/services/stream_client_kinesis'

$stdout.sync = true

module RegisterTransformerPsc
  module Apps
    class Transformer
      def initialize(bods_publisher: nil, entity_resolver: nil, bods_mapper: nil)
        bods_publisher ||= RegisterSourcesBods::Services::Publisher.new
        entity_resolver ||= RegisterSourcesOc::Services::ResolverService.new
        @bods_mapper = bods_mapper || RegisterTransformerPsc::BodsMapping::RecordProcessor.new(
          entity_resolver:,
          bods_publisher:,
        )
        @stream_client = RegisterCommon::Services::StreamClientKinesis.new(
          credentials: RegisterTransformerPsc::Config::AWS_CREDENTIALS,
          stream_name: ENV.fetch('PSC_STREAM'),
        )
        @consumer_id = "RegisterTransformerPsc"
      end

      def call
        stream_client.consume(consumer_id) do |record_data|
          record = JSON.parse(record_data, symbolize_names: true)
          psc_record = RegisterSourcesPsc::CompanyRecord[**record]
          bods_mapper.process(psc_record)
        end
      end

      private

      attr_reader :bods_mapper, :stream_client, :consumer_id

      def handle_records(records)
        records.each do |_record|
          bods_mapper.process psc_record
        end
      end
    end
  end
end
