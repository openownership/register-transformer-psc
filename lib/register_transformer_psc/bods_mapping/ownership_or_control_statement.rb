require 'xxhash'

require 'register_bods_v2/structs/interest'
require 'register_bods_v2/structs/ownership_or_control_statement'
require 'register_bods_v2/structs/entity_statement'
require 'register_bods_v2/structs/entity_statement'
require 'register_bods_v2/structs/share'
require 'register_bods_v2/constants/publisher'
require 'register_bods_v2/structs/publication_details'
require 'register_bods_v2/structs/source'
require 'register_bods_v2/structs/subject'

require_relative 'interest_parser'

module RegisterTransformerPsc
  module BodsMapping
    class OwnershipOrControlStatement
      UnsupportedSourceStatementTypeError = Class.new(StandardError)

      ID_PREFIX = 'openownership-register-'.freeze

      def self.call(psc_record, **kwargs)
        new(psc_record, **kwargs).call
      end

      def initialize(
        psc_record,
        entity_resolver: nil,
        source_statement: nil,
        target_statement: nil,
        interest_parser: nil
      )
        @psc_record = psc_record
        @source_statement = source_statement
        @target_statement = target_statement
        @interest_parser = interest_parser || InterestParser.new
        @entity_resolver = entity_resolver
      end

      def call
        RegisterBodsV2::OwnershipOrControlStatement[{
          statementID: statement_id,
          statementType: statement_type,
          statementDate: statement_date,
          isComponent: false,
          subject: subject,
          interestedParty: interested_party,
          interests: interests,
          publicationDetails: publication_details,
          source: source,
        }.compact]
      end

      private

      attr_reader :interest_parser, :entity_resolver, :source_statement, :target_statement, :psc_record

      def data
        psc_record.data
      end

      def statement_id #when Structs::Relationship
        ID_PREFIX + hasher(
          {
            id: 'TODO_ID', # obj.id,
            updated_at: statement_date,
            source_id: source_statement.statementID,
            target_id: target_statement.statementID,
          }.to_json
        )
      end

      def statement_type
        RegisterBodsV2::StatementTypes['ownershipOrControlStatement']
      end

      def statement_date
        data.notified_on.presence.try(:to_s) # ISO8601::Date
      end

      def subject
        RegisterBodsV2::Subject.new(
          describedByEntityStatement: target_statement.statementID
        )
      end

      def interested_party
        case source_statement.statementType
        when RegisterBodsV2::StatementTypes['personStatement']
          RegisterBodsV2::InterestedParty[{
            describedByPersonStatement: source_statement.statementID
          }]
        when RegisterBodsV2::StatementTypes['entityStatement']
          case source_statement.entityType
          when RegisterBodsV2::EntityTypes['unknownEntity']
            RegisterBodsV2::InterestedParty[{
              unspecified: source_statement.unspecifiedEntityDetails
            }.compact]
          when RegisterBodsV2::EntityTypes['legalEntity']
            RegisterBodsV2::InterestedParty[{
              describedByEntityStatement: source_statement.statementID
            }]
          else
            RegisterBodsV2::InterestedParty[{}] # TODO: raise error
          end
        else
          raise UnsupportedSourceStatementTypeError
        end
      end

      def interests
        (data.natures_of_control || []).map do |i|
          entry = interest_parser.call(i)
          next unless entry

          RegisterBodsV2::Interest[{
            type: entry.type,
            details: entry.details,
            share: entry.share,
            startDate: data.notified_on.presence.try(:to_s),
            endDate: data.ceased_on.presence.try(:to_s)
          }.compact]
        end.compact
      end

      def publication_details
        # UNIMPLEMENTED IN REGISTER
        RegisterBodsV2::PublicationDetails.new(
          publicationDate: Time.now.utc.to_date.to_s, # TODO: fix publication date
          bodsVersion: RegisterBodsV2::BODS_VERSION,
          license: RegisterBodsV2::BODS_LICENSE,
          publisher: RegisterBodsV2::PUBLISHER
        )
      end

      def source
        # UNIMPLEMENTED IN REGISTER
        # implemented for relationships
        RegisterBodsV2::Source.new(
          type: RegisterBodsV2::SourceTypes['officialRegister'],
          description: 'GB Persons Of Significant Control Register',
          url: "http://download.companieshouse.gov.uk/en_pscdata.html", # TODO: link to snapshot?
          retrievedAt: Time.now.utc.to_date.to_s, # TODO: fix publication date, # TODO: add retrievedAt to record iso8601
          assertedBy: nil # TODO: if it is a combination of sources (PSC and OpenCorporates), is it us?
        )
      end

      def hasher(data)
        XXhash.xxh64(data).to_s
      end
    end
  end
end
