require 'active_support/testing/time_helpers'

require 'register_transformer_psc/bods_mapping/ownership_or_control_statement'
require 'register_sources_psc/structs/company_record'

RSpec.describe RegisterTransformerPsc::BodsMapping::OwnershipOrControlStatement do
  include ActiveSupport::Testing::TimeHelpers

  subject do
    described_class.new(
      psc_record,
      entity_resolver: entity_resolver,
      source_statement: source_statement,
      target_statement: target_statement
    )
  end

  let(:entity_resolver) { double 'entity_resolver' }

  before { travel_to Time.at(1663187854) }
  after { travel_back }

  let(:psc_record) do
    data = {
      "etag": "36c99208e0c14294355583c965e4c3f3",
      "kind": "individual-person-with-significant-control",
      "name_elements": {
        "forename": "Joe",
        "surname": "Bloggs"
      },
      "nationality": "British",
      "country_of_residence": "United Kingdom",
      "notified_on": "2016-04-06",
      "address": {
        "premises": "123 Main Street",
        "locality": "Example Town",
        "region": "Exampleshire",
        "postal_code": "EX4 2MP"
      },
      "date_of_birth": {
        "month": 10,
        "year": 1955
      },
      "natures_of_control": [
        "ownership-of-shares-25-to-50-percent",
        "voting-rights-25-to-50-percent"
      ],
      "links": {
        "self": "/company/01234567/persons-with-significant-control/individual/abcdef123456789"
      }
    }
    RegisterSourcesPsc::CompanyRecord[{ company_number: "123456", data: data }]
  end
  let(:source_statement) do
    double 'source_statement', statementID: 'sourceID', statementType: 'entityStatement', entityType: 'legalEntity'
  end
  let(:target_statement) do
    double 'target_statement', statementID: 'targetID'
  end

  it 'maps successfully' do
    result = subject.call

    expect(result).to be_a RegisterSourcesBods::OwnershipOrControlStatement
    expect(result.to_h).to eq({
      interestedParty: {
        describedByEntityStatement: "sourceID"
      },
      interests: [
        {
          details: "ownership-of-shares-25-to-50-percent",
          share: {
            exclusiveMaximum: false,
            exclusiveMinimum: true,
            maximum: 50.0,
            minimum: 25.0
          },
          startDate: "2016-04-06",
          type: "shareholding"
        },
        {
          details: "voting-rights-25-to-50-percent",
          share: {
            exclusiveMaximum: false,
            exclusiveMinimum: true,
            maximum: 50.0,
            minimum: 25.0
          },
          startDate: "2016-04-06",
          type: "voting-rights"
        }
      ],
      isComponent: false,
      statementDate: "2016-04-06",
      statementID: "openownership-register-1727100534341507451",
      statementType: "ownershipOrControlStatement",
      subject: {
        describedByEntityStatement: "targetID"
      },
      publicationDetails: {
        bodsVersion: "0.2", 
        license: "https://register.openownership.org/terms-and-conditions",
        publicationDate: "2022-09-14",
        publisher: {
          name: "OpenOwnership Register",
          url: "https://register.openownership.org"
        }
      },
      source: {
        assertedBy: nil,
        description: "GB Persons Of Significant Control Register",
        retrievedAt: "2022-09-14",
        type: "officialRegister",
        url: "http://download.companieshouse.gov.uk/en_pscdata.html"
      },
    })
  end
end
