# frozen_string_literal: true

require 'active_support/testing/time_helpers'

require 'register_transformer_psc/bods_mapping/person_statement'
require 'register_sources_psc/structs/company_record'

RSpec.describe RegisterTransformerPsc::BodsMapping::PersonStatement do
  include ActiveSupport::Testing::TimeHelpers

  subject { described_class.new(psc_record) }

  before { travel_to Time.at(1_663_187_854) }
  after { travel_back }

  let(:psc_record) do
    data = {
      etag: '36c99208e0c14294355583c965e4c3f3',
      kind: 'individual-person-with-significant-control',
      name_elements: {
        forename: 'Joe',
        surname: 'Bloggs'
      },
      nationality: 'British',
      country_of_residence: 'United Kingdom',
      notified_on: '2016-04-06',
      address: {
        premises: '123 Main Street',
        locality: 'Example Town',
        region: 'Exampleshire',
        postal_code: 'EX4 2MP'
      },
      date_of_birth: {
        month: 10,
        year: 1955
      },
      natures_of_control: %w[
        ownership-of-shares-25-to-50-percent
        voting-rights-25-to-50-percent
      ],
      links: {
        self: '/company/01234567/persons-with-significant-control/individual/abcdef123456789'
      }
    }
    RegisterSourcesPsc::CompanyRecord[{ company_number: '123456', data: }]
  end

  it 'maps successfully' do
    result = subject.call

    expect(result).to be_a RegisterSourcesBods::PersonStatement
    expect(result.to_h).to eq(
      {
        addresses: [
          {
            address: '123 Main Street, Example Town, Exampleshire, EX4 2MP',
            country: 'GB',
            type: 'registered'
          }
        ],
        birthDate: '1955-10-01',
        identifiers: [],
        isComponent: false,
        names: [
          { familyName: 'Bloggs', fullName: 'Joe Bloggs', givenName: 'Joe', type: 'individual' }
        ],
        nationalities: [
          { code: 'GB', name: 'United Kingdom of Great Britain and Northern Ireland' }
        ],
        personType: 'knownPerson',
        source: {
          assertedBy: nil,
          description: 'GB Persons Of Significant Control Register',
          retrievedAt: '2022-09-14',
          type: 'officialRegister',
          url: 'https://api.company-information.service.gov.uk/company/01234567/persons-with-significant-control/individual/abcdef123456789'
        },
        statementType: 'personStatement'
      }
    )
  end
end
