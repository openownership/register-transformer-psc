# frozen_string_literal: true

require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/object/try'
require 'active_support/core_ext/string/conversions'
require 'active_support/core_ext/time'
require 'register_sources_bods/constants/publisher'
require 'register_sources_bods/enums/entity_types'
require 'register_sources_bods/enums/statement_types'
require 'register_sources_bods/mappers/resolver_mappings'
require 'register_sources_bods/structs/address'
require 'register_sources_bods/structs/entity_statement'
require 'register_sources_bods/structs/jurisdiction'
require 'register_sources_bods/structs/publication_details'
require 'register_sources_bods/structs/source'
require 'register_sources_oc/structs/resolver_request'
require 'uri'
require 'xxhash'

module RegisterTransformerPsc
  module BodsMapping
    class EntityStatement
      include RegisterSourcesBods::Mappers::ResolverMappings

      def self.call(psc_record, **kwargs)
        new(psc_record, **kwargs).call
      end

      def initialize(psc_record, entity_resolver: nil)
        @psc_record = psc_record
        @entity_resolver = entity_resolver
      end

      def call
        RegisterSourcesBods::EntityStatement[{
          statementType: statement_type,
          statementDate: nil,
          isComponent: false,
          entityType: entity_type,
          name:,
          alternateNames: alternate_names,
          incorporatedInJurisdiction: incorporated_in_jurisdiction,
          identifiers:,
          foundingDate: founding_date,
          dissolutionDate: dissolution_date,
          addresses:,
          source:
        }.compact]
      end

      private

      attr_reader :psc_record, :entity_resolver

      def data
        psc_record.data
      end

      # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      def resolver_response
        return @resolver_response if @resolver_response

        unless data.kind == RegisterSourcesPsc::CorporateEntityKinds['corporate-entity-person-with-significant-control']
          return
        end

        begin
          address = (data.respond_to?(:principal_office_address) && data.principal_office_address) || data.address

          @resolver_response = entity_resolver.resolve(
            RegisterSourcesOc::ResolverRequest[{
              company_number:,
              country: data.identification&.country_registered || data.address&.country,
              region: address&.region,
              name: data.name
            }.compact]
          )
        rescue StandardError
          print "FAILURE FOR RECORD #{psc_record.to_h}\n"
          raise
        end
      end
      # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

      def company_number
        return @company_number if @company_number

        @company_number = data.identification&.registration_number

        return unless @company_number.present?

        # standardise with leading zeros
        @company_number = "0#{@company_number}" while @company_number.length < 8

        @company_number
      end

      def statement_type
        RegisterSourcesBods::StatementTypes['entityStatement']
      end

      def entity_type
        # TODO: Legacy - this is hard-coded to registeredEntity in exporter
        RegisterSourcesBods::EntityTypes['registeredEntity']
      end

      def identifiers
        psc_self_link_identifiers + [
          open_corporates_identifier,
          lei_identifier
        ].compact
      end

      def name
        data.name || super
      end

      ADDRESS_KEYS = %i[premises address_line_1 address_line_2 locality region postal_code].freeze # rubocop:disable Naming/VariableNumber
      def addresses
        return super unless data.address.presence

        address = ADDRESS_KEYS.map { |key| data.address.send(key) }.map(&:presence).compact.join(', ')
        return super if address.blank?

        country_code = incorporated_in_jurisdiction&.code

        [
          RegisterSourcesBods::Address[{
            type: RegisterSourcesBods::AddressTypes['registered'],
            address:,
            postcode: data.address.postal_code,
            country: country_code
          }.compact]
        ]
      end

      def source
        url = 'http://download.companieshouse.gov.uk/en_pscdata.html'

        identifier_link = data.links[:self]
        if identifier_link.present?
          url = URI.join('https://api.company-information.service.gov.uk', identifier_link).to_s
        end

        RegisterSourcesBods::Source.new(
          type: RegisterSourcesBods::SourceTypes['officialRegister'],
          description: 'GB Persons Of Significant Control Register',
          url:,
          retrievedAt: Time.now.utc.to_date.to_s, # TODO: fix publication date, # TODO: add retrievedAt to record iso8601 # rubocop:disable Layout/LineLength
          assertedBy: nil # TODO: if it is a combination of sources (PSC and OpenCorporates), is it us?
        )
      end

      # When we import PSC data containing RLEs (intermediate company owners) we
      # give them a weird three-part identifier including their company number and
      # the original identifier from the data called a "self link". When we output
      # this we want to output two BODS identifiers, one for the link and one for the
      # company number. This allows us to a) link the statement back to the specific
      # parts of the PSC data it came from and b) share the company number we
      # figured out from an OC lookup, but make the provenance clearer.
      DOCUMENT_ID = 'GB Persons Of Significant Control Register'
      # if entity.legal_entity?
      def psc_self_link_identifiers
        if company_number.present?
          [
            RegisterSourcesBods::Identifier.new(
              id: company_number,
              schemeName: "#{DOCUMENT_ID} - Registration numbers"
            )
          ]
        else
          []
        end
      end
    end
  end
end
