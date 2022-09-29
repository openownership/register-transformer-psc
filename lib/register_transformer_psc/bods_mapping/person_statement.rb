require 'xxhash'
require 'register_sources_bods/constants/publisher'
require 'register_sources_bods/structs/person_statement'
require 'register_sources_bods/structs/publication_details'
require 'register_sources_bods/structs/source'

require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/object/try'
require 'countries'
require 'iso8601'

module RegisterTransformerPsc
  module BodsMapping
    class PersonStatement
      ID_PREFIX = 'openownership-register-'.freeze

      def self.call(psc_record)
        new(psc_record).call
      end

      def initialize(psc_record)
        @psc_record = psc_record
      end

      def call
        RegisterSourcesBods::PersonStatement[{
          statementID: statement_id,
          statementType: statement_type,
          # statementDate: statement_date,
          isComponent: is_component,
          personType: person_type,
          unspecifiedPersonDetails: unspecified_person_details,
          names: names,
          identifiers: identifiers,
          nationalities: nationalities,
          placeOfBirth: place_of_birth,
          birthDate: birth_date,
          deathDate: death_date,
          placeOfResidence: place_of_residence,
          taxResidencies: tax_residencies,
          addresses: addresses,
          hasPepStatus: has_pep_status,
          pepStatusDetails: pep_status_details,
          publicationDetails: publication_details,
          source: source,
          annotations: annotations,
          replacesStatements: replaces_statements
        }.compact]
      end

      private

      attr_reader :psc_record

      def statement_id
        obj_id = "TODO" # TODO: implement object id
        self_updated_at = "something" # TODO: implement self_updated_at
        ID_PREFIX + hasher("openownership-register/entity/#{obj_id}/#{self_updated_at}")
      end

      def statement_type
        RegisterSourcesBods::StatementTypes['personStatement']
      end

      def statement_date
        # NOT IMPLEMENTED
      end

      def person_type
        RegisterSourcesBods::PersonTypes['knownPerson'] # TODO: KNOWN_PERSON, ANONYMOUS_PERSON, UNKNOWN_PERSON
      end
      #def unknown_ps_person_type(unknown_person)
      #  case unknown_person.unknown_reason_code
      #  when 'super-secure-person-with-significant-control'
      #    'anonymousPerson'
      #  else
      #    'unknownPerson'
      #  end
      #end

      def identifiers
        psc_self_link_identifiers # TODO: include Register identifier
      end

      def unspecified_person_details
        #{
        #  reason,
        #  description
        #}
      end

      def names
        if data.name_elements.presence 
          [
            RegisterSourcesBods::Name.new(
              type: RegisterSourcesBods::NameTypes['individual'],
              fullName: name_string(data.name_elements),
              familyName: data.name_elements.surname,
              givenName: data.name_elements.forename,
              # patronymicName: nil
            )
          ]
        else
          [
            RegisterSourcesBods::Name.new(
              type: RegisterSourcesBods::NameTypes['individual'],
              fullName: data.name,
            )
          ]
        end
      end
      NAME_KEYS = %i[forename other_forenames surname].freeze # TODO: title?
      def name_string(name_elements)
        NAME_KEYS.map { |key| name_elements.send(key) }.map(&:presence).compact.join(' ')
      end

      def nationalities
        nationality = country_from_nationality(data.nationality).try(:alpha2)
        return unless nationality
        country = ISO3166::Country[nationality]
        return nil if country.blank?
        [
          RegisterSourcesBods::Country.new(
            name: country.name,
            code: country.alpha2
          )
        ]
      end
      def country_from_nationality(nationality)
        countries = ISO3166::Country.find_all_countries_by_nationality(nationality)
        return if countries.count > 1 # too ambiguous
        countries[0]
      end

      def place_of_birth
        # NOT IMPLEMENTED IN REGISTER
      end

      def birth_date
        dob_elements = entity_dob(data.date_of_birth)
        begin
          dob_elements&.to_date&.iso8601 # TODO - log exceptions but process as nil
        rescue Date::Error
          begin
            new_dob = "#{dob_elements}-01" # TODO: properly handle missing day
            new_dob&.to_date&.iso8601
          rescue Date::Error
            LOGGER.warn "Entity #{id} has invalid dob: #{dob_elements} - trying #{new_dob} also failed"
            nil
          end
        end
      end
      def entity_dob(elements)
        return unless elements
        parts = [elements.year]
        parts << format('%02d', elements.month) if elements.month
        parts << format('%02d', elements.day) if elements.month && elements.day
        ISO8601::Date.new(parts.join('-'))
      end

      def death_date
        # NOT IMPLEMENTED IN REGISTER
      end

      def place_of_residence
        # NOT IMPLEMENTED IN REGISTER
        # TODO: SUGGESTION: data['country_of_residence'].presence,
      end

      def tax_residencies
        # NOT IMPLEMENTED IN REGISTER
      end

      ADDRESS_KEYS = %i[premises address_line_1 address_line_2 locality region postal_code].freeze
      def addresses
        return unless data.address.presence

        address = ADDRESS_KEYS.map { |key| data.address.send(key) }.map(&:presence).compact.join(', ')

        return [] if address.blank?

        country_of_residence = data.country_of_residence.presence
        country = try_parse_country_name_to_code(country_of_residence)

        return [] if country.blank? # TODO: check this

        [
          RegisterSourcesBods::Address.new(
            type: RegisterSourcesBods::AddressTypes['registered'], # TODO: check this
            address: address,
            # postCode: nil,
            country: country
          )
        ]
      end
      def try_parse_country_name_to_code(name)
        return nil if name.blank?
        return ISO3166::Country[name].try(:alpha2) if name.length == 2
        country = ISO3166::Country.find_country_by_name(name)  
        return country.alpha2 if country
        country = ISO3166::Country.find_country_by_alpha3(name)
        return country.alpha2 if country
      end

      def has_pep_status
        # NOT IMPLEMENTED IN REGISTER
      end

      def pep_status_details
        # NOT IMPLEMENTED IN REGISTER
      end

      def data
        psc_record.data
      end

      def statement_date
        # UNIMPLEMENTED IN REGISTER (only for ownership or control statements)
      end

      def is_component
        false
      end

      def replaces_statements
        # UNIMPLEMENTED IN REGISTER
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

      def annotations
        # UNIMPLEMENTED IN REGISTER
      end

      def replaces_statements
        # UNIMPLEMENTED IN REGISTER
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

      # TODO!
      def register_identifier
        RegisterSourcesBods::Identifier.new(
          id: url,
          schemeName: 'OpenOwnership Register',
          uri: URI.join(url_base, "/entities/#{entity.id}").to_s
        )
      end

      def hasher(data)
        XXhash.xxh64(data).to_s
      end
    end
  end
end    
