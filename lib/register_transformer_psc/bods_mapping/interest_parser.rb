# frozen_string_literal: true

require 'register_sources_bods/structs/interest'

module RegisterTransformerPsc
  module BodsMapping
    class InterestParser
      def initialize(error_adapter: nil)
        @error_adapter = error_adapter
      end

      UnexpectedInterestTypeError = Class.new(StandardError)

      def call(interest)
        case interest
        when Hash
          if interest['exclusive_min'] || interest['exclusive_max']
            error_adapter&.error('Exporting interests with exclusivity set will overwrite it to false')
          end
          RegisterSourcesBods::Interest[{
            type: interest['type'],
            share: (
              if interest['share_min'] == interest['share_max']
                {
                  exact: interest['share_min'],
                  minimum: interest['share_min'],
                  maximum: interest['share_max']
                }
              else
                {
                  minimum: interest['share_min'],
                  maximum: interest['share_max'],
                  exclusiveMinimum: false,
                  exclusiveMaximum: false
                }
              end
            )
          }]
        when String
          parse_string interest
        else
          raise UnexpectedInterestTypeError,
                "Unexpected value for interest - class: #{interest.class.name}, value: #{interest.inspect}"
        end
      end

      private

      attr_reader :error_adapter

      # rubocop:disable Metrics/CyclomaticComplexity
      def parse_string(interest)
        case interest
        when /ownership-of-shares-25-to-50-percent/
          RegisterSourcesBods::Interest[{
            type: 'shareholding',
            details: interest,
            share: {
              minimum: 25,
              maximum: 50,
              exclusiveMinimum: true,
              exclusiveMaximum: false
            }
          }]
        when /ownership-of-shares-50-to-75-percent/
          RegisterSourcesBods::Interest[{
            type: 'shareholding',
            details: interest,
            share: {
              minimum: 50,
              maximum: 75,
              exclusiveMinimum: true,
              exclusiveMaximum: true
            }
          }]
        when /ownership-of-shares-75-to-100-percent/, /ownership-of-shares-more-than-25-percent/
          RegisterSourcesBods::Interest[{
            type: 'shareholding',
            details: interest,
            share: {
              minimum: 75,
              maximum: 100,
              exclusiveMinimum: false,
              exclusiveMaximum: false
            }
          }]
        when /voting-rights-25-to-50-percent/
          RegisterSourcesBods::Interest[{
            type: 'voting-rights',
            details: interest,
            share: {
              minimum: 25,
              maximum: 50,
              exclusiveMinimum: true,
              exclusiveMaximum: false
            }
          }]
        when /voting-rights-50-to-75-percent/
          RegisterSourcesBods::Interest[{
            type: 'voting-rights',
            details: interest,
            share: {
              minimum: 50,
              maximum: 75,
              exclusiveMinimum: true,
              exclusiveMaximum: true
            }
          }]
        when /voting-rights-75-to-100-percent/
          RegisterSourcesBods::Interest[{
            type: 'voting-rights',
            details: interest,
            share: {
              minimum: 75,
              maximum: 100,
              exclusiveMinimum: false,
              exclusiveMaximum: false
            }
          }]
        when /voting-rights-more-than-25-percent/
          RegisterSourcesBods::Interest[{
            type: 'voting-rights',
            details: interest,
            share: {
              minimum: 25,
              exclusiveMinimum: false
            }
          }]
        when /right-to-appoint-and-remove-directors/, /right-to-appoint-and-remove-members/
          RegisterSourcesBods::Interest[{
            type: 'appointment-of-board',
            details: interest
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
          RegisterSourcesBods::Interest[{
            type: 'rights-to-surplus-assets-on-dissolution',
            details: interest
          }]
        else # 'significant-influence-or-control'
          RegisterSourcesBods::Interest[{
            type: 'other-influence-or-control',
            details: interest
          }]
        end
      end
      # rubocop:enable Metrics/CyclomaticComplexity
    end
  end
end
