require 'xxhash'

require 'register_sources_bods/enums/entity_types'
require 'register_sources_bods/enums/statement_types'
require 'register_sources_bods/structs/address'
require 'register_sources_bods/structs/entity_statement'
require 'register_sources_bods/structs/jurisdiction'
require 'register_sources_bods/constants/publisher'
require 'register_sources_bods/structs/publication_details'
require 'register_sources_bods/structs/source'

require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/object/try'
require 'active_support/core_ext/time'
require 'active_support/core_ext/string/conversions'

require 'register_sources_oc/structs/resolver_request'

module RegisterTransformerPsc
  module BodsMapping
    class EntityStatement
      ID_PREFIX = 'openownership-register-'.freeze
      OPEN_CORPORATES_SCHEME_NAME = 'OpenCorporates'

      def self.call(psc_record, **kwargs)
        new(psc_record, **kwargs).call
      end

      def initialize(psc_record, entity_resolver: nil)
        @psc_record = psc_record
        @entity_resolver = entity_resolver
      end

      def call
        RegisterSourcesBods::EntityStatement[{
          statementID: statement_id,
          statementType: statement_type,
          statementDate: nil,
          isComponent: false,
          entityType: entity_type,
          # unspecifiedEntityDetails: unspecified_entity_details,
          name: name,
          # alternateNames: alternate_names,
          incorporatedInJurisdiction: incorporated_in_jurisdiction,
          identifiers: identifiers,
          foundingDate: founding_date,
          dissolutionDate: dissolution_date,
          addresses: addresses,
          # uri: uri,
          # replacesStatements: replaces_statements,
          publicationDetails: publication_details,
          source: source,
          # annotations: annotations
        }.compact]
      end

      private

      attr_reader :psc_record, :entity_resolver

      def data
        psc_record.data
      end

      def resolver_response
        return @resolver_response if @resolver_response

        return unless data.kind == RegisterSourcesPsc::CorporateEntityKinds['corporate-entity-person-with-significant-control']

        begin
          address = (data.respond_to?(:principal_office_address) && data.principal_office_address) || data.address

          @resolver_response = entity_resolver.resolve(
            RegisterSourcesOc::ResolverRequest[{
              company_number: data.identification.registration_number || psc_record.company_number,
              country: data.identification.country_registered,
              region: address&.region,
              name: data.name,
            }.compact]
          )
        rescue => e
          print "FAILURE FOR RECORD #{psc_record.to_h}\n"
          raise
        end
      end

      def statement_id
        id = 'register_entity_id' # TODO: implement
        self_updated_at = publication_details.publicationDate # TODO: use statement retrievedAt?
        ID_PREFIX + hasher("openownership-register/entity/#{id}/#{self_updated_at}")
      end

      def statement_type
        RegisterSourcesBods::StatementTypes['entityStatement']
      end

      def entity_type
         # TODO: Legacy - this is hard-coded to registeredEntity in exporter
        RegisterSourcesBods::EntityTypes['registeredEntity']
      end

      def identifiers
        psc_self_link_identifiers + [open_corporates_identifier].compact
      end

      def open_corporates_identifier
        return unless resolver_response && resolver_response.resolved

        jurisdiction = resolver_response.jurisdiction_code
        company_number = resolver_response.company_number
        oc_url = "https://opencorporates.com/companies/#{jurisdiction}/#{company_number}"

        RegisterSourcesBods::Identifier[{
          id: oc_url,
          schemeName: OPEN_CORPORATES_SCHEME_NAME,
          uri: oc_url
        }]
      end

      def name
        data.name
      end

      def incorporated_in_jurisdiction
        return unless resolver_response
        jurisdiction_code = resolver_response.jurisdiction_code
        return unless jurisdiction_code
      
        code, = jurisdiction_code.split('_')
        country = ISO3166::Country[code]
        return nil if country.blank?

        RegisterSourcesBods::Jurisdiction.new(name: country.name, code: country.alpha2)
      end

      def founding_date
        return unless resolver_response && resolver_response.company
        date = resolver_response.company.incorporation_date&.to_date
        return unless date
        date.try(:iso8601)
      rescue Date::Error
        LOGGER.warn "Entity has invalid incorporation_date: #{date}"
        nil
      end

      def dissolution_date
        return unless resolver_response && resolver_response.company
        date = resolver_response.company.dissolution_date&.to_date
        return unless date
        date.try(:iso8601)
      rescue Date::Error
        LOGGER.warn "Entity has invalid dissolution_date: #{date}"
        nil
      end

      ADDRESS_KEYS = %i[premises address_line_1 address_line_2 locality region postal_code].freeze
      def addresses
        return [] unless data.address.presence

        address = ADDRESS_KEYS.map { |key| data.address.send(key) }.map(&:presence).compact.join(', ')
        return [] if address.blank?

        country_code = incorporated_in_jurisdiction ? incorporated_in_jurisdiction.code : nil

        [
          RegisterSourcesBods::Address[{
            type: RegisterSourcesBods::AddressTypes['registered'],
            address: address,
            postcode: data.address.postal_code,
            country: country_code
          }.compact]
        ]
      end

      def publication_details
        # UNIMPLEMENTED IN REGISTER
        RegisterSourcesBods::PublicationDetails.new(
          publicationDate: Time.now.utc.to_date.to_s, # TODO: fix publication date
          bodsVersion: RegisterSourcesBods::BODS_VERSION,
          license: RegisterSourcesBods::BODS_LICENSE,
          publisher: RegisterSourcesBods::PUBLISHER
        )
      end

      def source
        # UNIMPLEMENTED IN REGISTER
        # implemented for relationships
        RegisterSourcesBods::Source.new(
          type: RegisterSourcesBods::SourceTypes['officialRegister'],
          description: 'GB Persons Of Significant Control Register',
          url: "http://download.companieshouse.gov.uk/en_pscdata.html", # TODO: link to snapshot?
          retrievedAt: Time.now.utc.to_date.to_s, # TODO: fix publication date, # TODO: add retrievedAt to record iso8601
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
      def psc_self_link_identifiers # if entity.legal_entity?
        identifier_link = data.links[:self]
        return unless identifier_link.present?

        identifiers = [
          RegisterSourcesBods::Identifier.new(id: identifier_link, schemeName: DOCUMENT_ID)
        ]

        return identifiers unless data.respond_to?(:identification)

        company_number = data.identification.registration_number
        if company_number.present? # this depends on if corporate entity
          identifiers << RegisterSourcesBods::Identifier.new(
            id: company_number,
            schemeName: "#{DOCUMENT_ID} - Registration numbers",
          )
        end
        identifiers
      end

      def hasher(data)
        XXhash.xxh64(data).to_s
      end
    end
  end
end
