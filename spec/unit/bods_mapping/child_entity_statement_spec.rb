# frozen_string_literal: true

require 'active_support/testing/time_helpers'

require 'register_transformer_psc/bods_mapping/child_entity_statement'
require 'register_sources_psc/structs/company_record'
require 'register_sources_oc/structs/resolver_response'

RSpec.describe RegisterTransformerPsc::BodsMapping::ChildEntityStatement do
  include ActiveSupport::Testing::TimeHelpers

  subject { described_class.new(company_number, entity_resolver:) }

  let(:entity_resolver) { double 'entity_resolver' }
  let(:company_number) { '89101112' }

  before { travel_to Time.at(1_663_187_854) }
  after { travel_back }

  it 'maps successfully' do
    expect(entity_resolver).to receive(:resolve).with(
      RegisterSourcesOc::ResolverRequest[{
        company_number:,
        jurisdiction_code: 'gb'
      }.compact]
    ).and_return RegisterSourcesOc::ResolverResponse[{
      resolved: true,
      reconciliation_response: nil,
      company_number: '89101112',
      jurisdiction_code: 'gb',
      company: {
        company_number: '89101112',
        jurisdiction_code: 'gb',
        name: 'Foo Bar Limited',
        company_type: 'company_type',
        incorporation_date: '2020-01-09',
        dissolution_date: '2021-09-07',
        restricted_for_marketing: nil,
        registered_address_in_full: 'registered address',
        registered_address_country: 'United Kingdom'
      },
      add_ids: [
        {
          company_number: '89101112',
          jurisdiction_code: 'gb',
          uid: '123456789',
          identifier_system_code: 'gb_vat'
        },
        {
          company_number: '89101112',
          jurisdiction_code: 'gb',
          uid: 'XXXXXXXXXXXX89101112',
          identifier_system_code: 'lei'
        }
      ]
    }]

    result = subject.call

    expect(result).to be_a RegisterSourcesBods::EntityStatement
    expect(result.to_h).to eq(
      addresses: [
        {
          address: 'registered address',
          country: 'GB',
          type: 'registered'
        }
      ],
      dissolutionDate: '2021-09-07',
      entityType: 'registeredEntity',
      foundingDate: '2020-01-09',
      identifiers: [
        { id: '89101112', scheme: 'GB-COH', schemeName: 'Companies House' },
        { id: 'https://opencorporates.com/companies/gb/89101112', schemeName: 'OpenCorporates',
          uri: 'https://opencorporates.com/companies/gb/89101112' },
        { id: 'XXXXXXXXXXXX89101112', scheme: 'XI-LEI', schemeName: 'Global Legal Entity Identifier Index (2)',
          uri: 'https://search.gleif.org/#/record/XXXXXXXXXXXX89101112' }
      ],
      incorporatedInJurisdiction: { code: 'GB', name: 'United Kingdom of Great Britain and Northern Ireland' },
      isComponent: false,
      name: 'Foo Bar Limited',
      statementType: 'entityStatement'
    )
  end
end
