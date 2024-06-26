# frozen_string_literal: true

require 'active_support/testing/time_helpers'

require 'register_transformer_psc/bods_mapping/entity_statement'
require 'register_sources_psc/structs/company_record'
require 'register_sources_oc/structs/resolver_response'

RSpec.describe RegisterTransformerPsc::BodsMapping::EntityStatement do
  include ActiveSupport::Testing::TimeHelpers

  subject { described_class.new(psc_record, entity_resolver:) }

  let(:entity_resolver) { double 'entity_resolver' }

  before { travel_to Time.at(1_663_187_854) }
  after { travel_back }

  context 'when record is corporate_entity' do
    let(:psc_record) do
      data = {
        etag: '36c99208e0c14294355583c965e4c3f1',
        kind: 'corporate-entity-person-with-significant-control',
        name: 'Foo Bar Limited',
        address: {
          premises: '123 Main Street',
          locality: 'Example Town',
          region: 'Exampleshire',
          postal_code: 'EX4 2MP'
        },
        identification: {
          country_registered: 'United Kingdom',
          registration_number: '89101112'
        },
        links: {
          self: '/company/01234567/persons-with-significant-control/corporate-entity/abcdef123456789'
        }
      }
      RegisterSourcesPsc::CompanyRecord[{ company_number: '123456', data: }]
    end

    it 'maps successfully' do # rubocop:disable RSpec/ExampleLength
      expect(entity_resolver).to receive(:resolve).with(
        RegisterSourcesOc::ResolverRequest[{
          company_number: '89101112',
          name: 'Foo Bar Limited',
          country: 'United Kingdom',
          region: 'Exampleshire'
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
        {
          addresses: [
            {
              address: '123 Main Street, Example Town, Exampleshire, EX4 2MP',
              country: 'GB',
              type: 'registered'
            }
          ],
          dissolutionDate: '2021-09-07',
          entityType: 'registeredEntity',
          foundingDate: '2020-01-09',
          identifiers: [
            {
              id: '89101112',
              schemeName: 'GB Persons Of Significant Control Register - Registration numbers'
            },
            {
              id: 'https://opencorporates.com/companies/gb/89101112',
              schemeName: 'OpenCorporates',
              uri: 'https://opencorporates.com/companies/gb/89101112'
            },
            {
              id: 'XXXXXXXXXXXX89101112',
              scheme: 'XI-LEI',
              schemeName: 'Global Legal Entity Identifier Index (2)',
              uri: 'https://search.gleif.org/#/record/XXXXXXXXXXXX89101112'
            }
          ],
          incorporatedInJurisdiction: { code: 'GB', name: 'United Kingdom of Great Britain and Northern Ireland' },
          isComponent: false,
          name: 'Foo Bar Limited',
          source: {
            assertedBy: nil,
            description: 'GB Persons Of Significant Control Register',
            retrievedAt: '2022-09-14',
            type: 'officialRegister',
            url: 'https://api.company-information.service.gov.uk/company/01234567/persons-with-significant-control/corporate-entity/abcdef123456789'
          },
          statementType: 'entityStatement'
        }
      )
    end
  end
end
