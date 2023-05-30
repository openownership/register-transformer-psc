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

      def process(psc_record)
        child_entity = map_child_entity(psc_record)
        child_entity &&= bods_publisher.publish(child_entity)

        parent_entity = map_parent_entity(psc_record)
        parent_entity &&= bods_publisher.publish(parent_entity)

        relationship = map_relationship(psc_record, child_entity, parent_entity)
        relationship && bods_publisher.publish(relationship)
      end

      def process_many(psc_records)
        child_entities = psc_records.to_h { |psc_record| [psc_record.data.etag, map_child_entity(psc_record)] }
        parent_entities = psc_records.to_h { |psc_record| [psc_record.data.etag, map_parent_entity(psc_record)] }

        parent_and_child_entities = child_entities.values.compact + parent_entities.values.compact
        published_entities = bods_publisher.publish_many parent_and_child_entities

        relationships = psc_records.map do |psc_record|
          etag = psc_record.data.etag

          unpublished_child_entity = child_entities[etag]
          unpublished_parent_entity = parent_entities[etag]

          published_child_entity = unpublished_child_entity &&
                                   published_entities.select { |entity| entity.identifiers.intersect?(unpublished_child_entity.identifiers) }.last

          published_parent_entity = unpublished_parent_entity &&
                                    published_entities.select { |entity| entity.identifiers.intersect?(unpublished_parent_entity.identifiers) }.last

          map_relationship(psc_record, published_child_entity, published_parent_entity)
        end.compact

        bods_publisher.publish_many(relationships)
      end

      private

      attr_reader :entity_resolver, :interest_parser, :person_statement_mapper,
                  :entity_statement_mapper, :child_entity_statement_mapper,
                  :ownership_or_control_statement_mapper, :bods_publisher

      def map_child_entity(psc_record)
        BodsMapping::ChildEntityStatement.call(
          psc_record.company_number,
          entity_resolver:,
        )
      end

      def map_parent_entity(psc_record)
        case psc_record.data.kind
        when /individual/
          person_statement_mapper.call(psc_record)
        when /corporate-entity/
          entity_statement_mapper.call(psc_record, entity_resolver:)
        when /legal-person/
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
          RegisterSourcesPsc::LegalPersonBeneficialOwnerKinds['legal-person-beneficial-owner'],
        ].include?(psc_record.data.kind)

        ownership_or_control_statement_mapper.call(
          psc_record,
          entity_resolver:,
          source_statement: parent_entity,
          target_statement: child_entity,
          interest_parser:,
        )
      end
    end
  end
end
