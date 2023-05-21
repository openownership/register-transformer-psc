require 'register_sources_bods/enums/entity_types'
require 'register_sources_bods/enums/statement_types'
require 'register_sources_bods/structs/address'
require 'register_sources_bods/structs/entity_statement'
require 'register_sources_bods/structs/identifier'
require 'register_sources_bods/structs/jurisdiction'
require 'register_sources_bods/constants/publisher'
require 'register_sources_bods/mappers/resolver_mappings'

require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/object/try'
require 'active_support/core_ext/time'
require 'active_support/core_ext/string/conversions'

require 'register_sources_oc/structs/resolver_request'

module RegisterTransformerPsc
  module BodsMapping
    class ChildEntityStatement
      include RegisterSourcesBods::Mappers::ResolverMappings
 
      ID_PREFIX = 'openownership-register-'.freeze

      def self.call(company_number, **kwargs)
        new(company_number, **kwargs).call
      end

      def initialize(company_number, entity_resolver: nil)
        @company_number = company_number
        @entity_resolver = entity_resolver
      end

      def call
        RegisterSourcesBods::EntityStatement[{
          statementID: statement_id,
          statementType: RegisterSourcesBods::StatementTypes['entityStatement'],
          isComponent: false,
          entityType: RegisterSourcesBods::EntityTypes['registeredEntity'],
          incorporatedInJurisdiction: incorporated_in_jurisdiction,
          identifiers: [
            RegisterSourcesBods::Identifier.new(
              scheme: 'GB-COH',
              schemeName: 'Companies House',
              id: company_number,
            ),
            open_corporates_identifier,
          ].compact,
          name: name,
          addresses: addresses,
          foundingDate: founding_date,
          dissolutionDate: dissolution_date,
          publicationDetails: publication_details,
          # replacesStatements, statementDate, source
          # annotations, unspecifiedEntityDetails, alternateNames, uri
        }.compact]
      end

      private

      attr_reader :company_number, :entity_resolver

      def resolver_response
        return @resolver_response if @resolver_response

        @resolver_response = entity_resolver.resolve(
          RegisterSourcesOc::ResolverRequest.new(
            company_number:,
            jurisdiction_code: 'gb',
          ),
        )
      end

      def statement_id
        'TODO'
      end

      def publication_details
        # UNIMPLEMENTED IN REGISTER
        RegisterSourcesBods::PublicationDetails.new(
          publicationDate: Time.now.utc.to_date.to_s, # TODO: fix publication date
          bodsVersion: RegisterSourcesBods::BODS_VERSION,
          license: RegisterSourcesBods::BODS_LICENSE,
          publisher: RegisterSourcesBods::PUBLISHER,
        )
      end
    end
  end
end
