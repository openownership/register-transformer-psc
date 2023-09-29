# frozen_string_literal: true

require_relative 'interest_parser'

require 'register_sources_psc/enums/corporate_entity_kinds'
require 'register_sources_psc/enums/individual_kinds'
require 'register_sources_psc/enums/legal_person_kinds'
require 'register_sources_psc/enums/statement_kinds'
require 'register_sources_psc/enums/super_secure_kinds'
require 'register_sources_psc/enums/corporate_entity_beneficial_owner_kinds'
require 'register_sources_psc/enums/individual_beneficial_owner_kinds'
require 'register_sources_psc/enums/legal_person_beneficial_owner_kinds'
require 'register_sources_psc/enums/super_secure_beneficial_owner_kinds'

require 'register_transformer_psc/bods_mapping/entity_statement'
require 'register_transformer_psc/bods_mapping/person_statement'
require 'register_transformer_psc/bods_mapping/child_entity_statement'
require 'register_transformer_psc/bods_mapping/ownership_or_control_statement'

module RegisterTransformerPsc
  module BodsMapping
    class RecordProcessor
      # rubocop:disable Metrics/ParameterLists
      def initialize(
        entity_resolver: nil,
        interest_parser: nil,
        person_statement_mapper: BodsMapping::PersonStatement,
        entity_statement_mapper: BodsMapping::EntityStatement,
        child_entity_statement_mapper: BodsMapping::ChildEntityStatement,
        ownership_or_control_statement_mapper: BodsMapping::OwnershipOrControlStatement,
        bods_publisher: nil
      )
        @entity_resolver = entity_resolver
        @bods_publisher = bods_publisher
        @interest_parser = interest_parser || InterestParser.new
        @person_statement_mapper = person_statement_mapper
        @entity_statement_mapper = entity_statement_mapper
        @child_entity_statement_mapper = child_entity_statement_mapper
        @ownership_or_control_statement_mapper = ownership_or_control_statement_mapper
      end
      # rubocop:enable Metrics/ParameterLists

      def process(psc_record)
        process_many([psc_record])
      end

      def process_many(psc_records)
        child_entities = psc_records.to_h do |psc_record|
          ["#{psc_record.data.etag}-child", map_child_entity(psc_record)]
        end
        parent_entities = psc_records.to_h do |psc_record|
          ["#{psc_record.data.etag}-parent", map_parent_entity(psc_record)]
        end

        published_entities = bods_publisher.publish_many child_entities.merge(parent_entities).compact

        relationships = psc_records.map do |psc_record|
          psc_record.data.etag

          published_child_entity = published_entities["#{psc_record.data.etag}-child"]
          published_parent_entity = published_entities["#{psc_record.data.etag}-parent"]

          next unless published_child_entity && published_parent_entity

          ["#{psc_record.data.etag}-rel", map_relationship(psc_record, published_child_entity, published_parent_entity)]
        end.compact.to_h.compact

        bods_publisher.publish_many(relationships)
      end

      private

      attr_reader :entity_resolver, :interest_parser, :person_statement_mapper,
                  :entity_statement_mapper, :child_entity_statement_mapper,
                  :ownership_or_control_statement_mapper, :bods_publisher

      def map_child_entity(psc_record)
        BodsMapping::ChildEntityStatement.call(
          psc_record.company_number,
          entity_resolver:
        )
      end

      def map_parent_entity(psc_record)
        case psc_record.data.kind
        when /individual/
          person_statement_mapper.call(psc_record)
        when /corporate-entity/, /legal-person/
          entity_statement_mapper.call(psc_record, entity_resolver:)
        end
      end

      def map_relationship(psc_record, child_entity, parent_entity)
        return unless child_entity && parent_entity

        return unless [
          RegisterSourcesPsc::IndividualKinds['individual-person-with-significant-control'],
          RegisterSourcesPsc::CorporateEntityKinds['corporate-entity-person-with-significant-control'],
          RegisterSourcesPsc::LegalPersonKinds['legal-person-person-with-significant-control'],
          RegisterSourcesPsc::IndividualBeneficialOwnerKinds['individual-beneficial-owner'],
          RegisterSourcesPsc::CorporateEntityBeneficialOwnerKinds['corporate-entity-beneficial-owner'],
          RegisterSourcesPsc::LegalPersonBeneficialOwnerKinds['legal-person-beneficial-owner']
        ].include?(psc_record.data.kind)

        ownership_or_control_statement_mapper.call(
          psc_record,
          entity_resolver:,
          source_statement: parent_entity,
          target_statement: child_entity,
          interest_parser:
        )
      end
    end
  end
end
