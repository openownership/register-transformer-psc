require 'register_transformer_psc/config/settings'
require 'register_sources_bods/services/publisher'
require 'register_transformer_psc/bods_mapping/record_processor'
require 'register_sources_psc/structs/company_record'
require 'register_sources_oc/services/resolver_service'

$stdout.sync = true

module RegisterTransformerPsc
  module Apps
    class TransformerLocal
      def self.bash_call(args)
        filename = args.last

        TransformerLocal.new.call(filename)
      end

      def initialize(bods_publisher: nil, entity_resolver: nil, bods_mapper: nil)
        bods_publisher ||= RegisterSourcesBods::Services::Publisher.new
        entity_resolver ||= RegisterSourcesOc::Services::ResolverService.new
        @bods_mapper = bods_mapper || RegisterTransformerPsc::BodsMapping::RecordProcessor.new(
          entity_resolver:,
          bods_publisher:,
        )
      end

      def call(filename)
        rows = File.read(filename).split("\n")

        records = rows.map do |record_data|
          record = JSON.parse(record_data, symbolize_names: true)
          RegisterSourcesPsc::CompanyRecord[**record]
        end

        print "Processing these records: ", records, "\n\n"

        bods_mapper.process_many records
      end

      private

      attr_reader :bods_mapper
    end
  end
end
