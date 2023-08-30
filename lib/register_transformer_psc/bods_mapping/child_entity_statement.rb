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
        # standardise with leading zeros
        while company_number.present? && (company_number.length < 8)
          company_number = "0#{company_number}"
        end

        @company_number = company_number
        @entity_resolver = entity_resolver
      end

      def call
        RegisterSourcesBods::EntityStatement[{
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
            lei_identifier,
          ].compact,
          name:,
          addresses:,
          foundingDate: founding_date,
          dissolutionDate: dissolution_date,
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
    end
  end
end
