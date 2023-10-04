# frozen_string_literal: true

require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/object/try'
require 'countries'
require 'iso8601'
require 'register_sources_bods/constants/publisher'
require 'register_sources_bods/structs/person_statement'
require 'register_sources_bods/structs/publication_details'
require 'register_sources_bods/structs/source'
require 'xxhash'

module RegisterTransformerPsc
  module BodsMapping
    class PersonStatement
      def self.call(psc_record)
        new(psc_record).call
      end

      def initialize(psc_record)
        @psc_record = psc_record
      end

      def call
        RegisterSourcesBods::PersonStatement[{
          statementType: statement_type,
          isComponent: is_component,
          personType: person_type,
          unspecifiedPersonDetails: unspecified_person_details,
          names:,
          identifiers:,
          nationalities:,
          placeOfBirth: place_of_birth,
          birthDate: birth_date,
          deathDate: death_date,
          placeOfResidence: place_of_residence,
          taxResidencies: tax_residencies,
          addresses:,
          hasPepStatus: has_pep_status,
          pepStatusDetails: pep_status_details,
          source:
        }.compact]
      end

      private

      attr_reader :psc_record

      def statement_type
        RegisterSourcesBods::StatementTypes['personStatement']
      end

      def person_type
        RegisterSourcesBods::PersonTypes['knownPerson'] # TODO: KNOWN_PERSON, ANONYMOUS_PERSON, UNKNOWN_PERSON
      end

      def identifiers
        []
      end

      def unspecified_person_details
        # {
        #  reason,
        #  description
        # }
      end

      def names
        full_name = data.name.present? ? data.name : nil

        if data.name_elements.presence
          full_name ||= name_string(data.name_elements)

          # Remove Title from full name to be consistent with previous Register
          split_name = full_name.to_s.split
          if split_name.length >= 1 && (split_name[0].upcase == data.name_elements.title.to_s.upcase)
            full_name = split_name[1..].to_a.join(' ')
          end

          [
            RegisterSourcesBods::Name[{
              type: RegisterSourcesBods::NameTypes['individual'],
              fullName: full_name,
              familyName: data.name_elements.surname,
              givenName: data.name_elements.forename
              # patronymicName: nil
            }.compact]
          ]
        else
          [
            RegisterSourcesBods::Name.new(
              type: RegisterSourcesBods::NameTypes['individual'],
              fullName: data.name
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
          dob_elements&.to_date&.iso8601 # TODO: - log exceptions but process as nil
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

      ADDRESS_KEYS = %i[premises address_line_1 address_line_2 locality region postal_code].freeze # rubocop:disable Naming/VariableNumber
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
            address:,
            # postCode: nil,
            country:
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

      # rubocop:disable Naming/PredicateName
      def has_pep_status
        # NOT IMPLEMENTED IN REGISTER
      end
      # rubocop:enable Naming/PredicateName

      def pep_status_details
        # NOT IMPLEMENTED IN REGISTER
      end

      def data
        psc_record.data
      end

      # rubocop:disable Naming/PredicateName
      def is_component
        false
      end
      # rubocop:enable Naming/PredicateName

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
    end
  end
end
