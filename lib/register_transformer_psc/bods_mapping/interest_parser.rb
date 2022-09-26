require 'register_bods_v2/structs/interest'

module RegisterTransformerPsc
  module BodsMapping
    class InterestParser
      def initialize(error_adapter: nil)
        @error_adapter = error_adapter
      end

      UnexpectedInterestTypeError = Class.new(StandardError)

      def call(i)
        case i
        when Hash
          if i['exclusive_min'] || i['exclusive_max']
            error_adapter && error_adapter.error('Exporting interests with exclusivity set will overwrite it to false')
          end
          RegisterBodsV2::Interest[{
            type: i['type'],
            share: (
              if i['share_min'] == i['share_max']
                {
                  exact: i['share_min'],
                  minimum: i['share_min'],
                  maximum: i['share_max'],
                }
              else
                {
                  minimum: i['share_min'],
                  maximum: i['share_max'],
                  exclusiveMinimum: false,
                  exclusiveMaximum: false,
                }
              end
            )
          }]
        when String
          parse_string i
        else
          raise UnexpectedInterestTypeError.new(
            "Unexpected value for interest - class: #{i.class.name}, value: #{i.inspect}"
          )
        end
      end

      private

      attr_reader :error_adapter

      def parse_string(interest)
        case interest
        when 'ownership-of-shares-25-to-50-percent',
            'ownership-of-shares-25-to-50-percent-as-trust',
            'ownership-of-shares-25-to-50-percent-as-firm'
          RegisterBodsV2::Interest[{
            type: 'shareholding',
            details: interest,
            share: {
              minimum: 25,
              maximum: 50,
              exclusiveMinimum: true,
              exclusiveMaximum: false,
            },
          }]
        when 'ownership-of-shares-50-to-75-percent',
            'ownership-of-shares-50-to-75-percent-as-trust',
            'ownership-of-shares-50-to-75-percent-as-firm'
          RegisterBodsV2::Interest[{
            type: 'shareholding',
            details: interest,
            share: {
              minimum: 50,
              maximum: 75,
              exclusiveMinimum: true,
              exclusiveMaximum: true,
            },
          }]
        when 'ownership-of-shares-75-to-100-percent',
            'ownership-of-shares-75-to-100-percent-as-trust',
            'ownership-of-shares-75-to-100-percent-as-firm'
          RegisterBodsV2::Interest[{
            type: 'shareholding',
            details: interest,
            share: {
              minimum: 75,
              maximum: 100,
              exclusiveMinimum: false,
              exclusiveMaximum: false,
            },
          }]
        when 'voting-rights-25-to-50-percent',
            'voting-rights-25-to-50-percent-as-trust',
            'voting-rights-25-to-50-percent-as-firm',
            'voting-rights-25-to-50-percent-limited-liability-partnership',
            'voting-rights-25-to-50-percent-as-trust-limited-liability-partnership',
            'voting-rights-25-to-50-percent-as-firm-limited-liability-partnership'
          RegisterBodsV2::Interest[{
            type: 'voting-rights',
            details: interest,
            share: {
              minimum: 25,
              maximum: 50,
              exclusiveMinimum: true,
              exclusiveMaximum: false,
            },
          }]
        when 'voting-rights-50-to-75-percent',
            'voting-rights-50-to-75-percent-as-trust',
            'voting-rights-50-to-75-percent-as-firm',
            'voting-rights-50-to-75-percent-limited-liability-partnership',
            'voting-rights-50-to-75-percent-as-trust-limited-liability-partnership',
            'voting-rights-50-to-75-percent-as-firm-limited-liability-partnership'
          RegisterBodsV2::Interest[{
            type: 'voting-rights',
            details: interest,
            share: {
              minimum: 50,
              maximum: 75,
              exclusiveMinimum: true,
              exclusiveMaximum: true,
            },
          }]
        when 'voting-rights-75-to-100-percent',
            'voting-rights-75-to-100-percent-as-trust',
            'voting-rights-75-to-100-percent-as-firm',
            'voting-rights-75-to-100-percent-limited-liability-partnership',
            'voting-rights-75-to-100-percent-as-trust-limited-liability-partnership',
            'voting-rights-75-to-100-percent-as-firm-limited-liability-partnership'
          RegisterBodsV2::Interest[{
            type: 'voting-rights',
            details: interest,
            share: {
              minimum: 75,
              maximum: 100,
              exclusiveMinimum: false,
              exclusiveMaximum: false,
            },
          }]
        when 'right-to-appoint-and-remove-directors',
            'right-to-appoint-and-remove-directors-as-trust',
            'right-to-appoint-and-remove-directors-as-firm',
            'right-to-appoint-and-remove-members-limited-liability-partnership',
            'right-to-appoint-and-remove-members-as-trust-limited-liability-partnership',
            'right-to-appoint-and-remove-members-as-firm-limited-liability-partnership'
          RegisterBodsV2::Interest[{
            type: 'appointment-of-board',
            details: interest,
          }]
        when 'right-to-share-surplus-assets-25-to-50-percent-limited-liability-partnership',
            'right-to-share-surplus-assets-50-to-75-percent-limited-liability-partnership',
            'right-to-share-surplus-assets-75-to-100-percent-limited-liability-partnership',
            'right-to-share-surplus-assets-25-to-50-percent-as-trust-limited-liability-partnership',
            'right-to-share-surplus-assets-50-to-75-percent-as-trust-limited-liability-partnership',
            'right-to-share-surplus-assets-75-to-100-percent-as-trust-limited-liability-partnership',
            'right-to-share-surplus-assets-25-to-50-percent-as-firm-limited-liability-partnership',
            'right-to-share-surplus-assets-50-to-75-percent-as-firm-limited-liability-partnership',
            'right-to-share-surplus-assets-75-to-100-percent-as-firm-limited-liability-partnership'
          # See issue: https://github.com/openownership/data-standard/issues/10
          RegisterBodsV2::Interest[{
            type: 'rights-to-surplus-assets-on-dissolution',
            details: interest,
          }]
        else # 'significant-influence-or-control'
          RegisterBodsV2::Interest[{
            type: 'other-influence-or-control',
            details: interest,
          }]
        end
      end
    end
  end
end
