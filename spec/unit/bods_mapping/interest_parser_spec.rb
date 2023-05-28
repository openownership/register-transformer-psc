require 'register_transformer_psc/bods_mapping/interest_parser'

RSpec.describe RegisterTransformerPsc::BodsMapping::InterestParser do
  subject { described_class.new(error_adapter:) }

  let(:error_adapter) { double 'error_adapter' }

  describe '#call' do
    context 'when given a Hash' do
      let(:interest_type) { 'shareholding' }
      let(:share_min) { 50 }
      let(:share_max) { 50 }

      let(:interest) do
        {
          'type' => interest_type,
          'share_min' => share_min,
          'share_max' => share_max,
        }
      end

      context 'with share_min equal to share_min' do
        it 'returns mapped interest' do
          expect(subject.call(interest).to_h).to eq(
            {
              type: interest_type,
              share: {
                exact: share_min,
                minimum: share_min,
                maximum: share_max,
              },
            },
          )
        end
      end

      context 'with share_min not equal to share_min' do
        let(:share_max) { share_min + 10 }

        it 'returns mapped interest' do
          expect(subject.call(interest).to_h).to eq(
            {
              type: interest_type,
              share: {
                minimum: share_min,
                maximum: share_max,
                exclusiveMinimum: false,
                exclusiveMaximum: false,
              },
            },
          )
        end
      end

      context 'with params including exclusive_min' do
        let(:share_max) { share_min + 10 }

        let(:interest) do
          {
            'type' => interest_type,
            'share_min' => share_min,
            'share_max' => share_max,
            'exclusive_min' => 10,
          }
        end

        it 'raises Rollbar error and ignores exclusive_min' do
          expect(error_adapter).to receive(:error).and_return(nil)

          expect(subject.call(interest).to_h).to eq(
            {
              type: interest_type,
              share: {
                minimum: share_min,
                maximum: share_max,
                exclusiveMinimum: false,
                exclusiveMaximum: false,
              },
            },
          )
        end
      end
    end

    context 'when given a String' do
      context 'with ownership-of-shares-25-to-50-percent*' do
        it 'returns correct interest' do
          %w[
            ownership-of-shares-25-to-50-percent
            ownership-of-shares-25-to-50-percent-as-trust
            ownership-of-shares-25-to-50-percent-as-firm
          ].each do |value|
            expect(subject.call(value).to_h).to eq(
              {
                type: 'shareholding',
                details: value,
                share: { minimum: 25, maximum: 50, exclusiveMinimum: true, exclusiveMaximum: false },
              },
            )
          end
        end
      end

      context 'with ownership-of-shares-50-to-75-percent*' do
        it 'returns correct interest' do
          %w[
            ownership-of-shares-50-to-75-percent
            ownership-of-shares-50-to-75-percent-as-trust
            ownership-of-shares-50-to-75-percent-as-firm
          ].each do |value|
            expect(subject.call(value).to_h).to eq(
              {
                type: 'shareholding',
                details: value,
                share: { minimum: 50, maximum: 75, exclusiveMinimum: true, exclusiveMaximum: true },
              },
            )
          end
        end
      end

      context 'with ownership-of-shares-75-to-100-percent*' do
        it 'returns correct interest' do
          %w[
            ownership-of-shares-75-to-100-percent
            ownership-of-shares-75-to-100-percent-as-trust
            ownership-of-shares-75-to-100-percent-as-firm
          ].each do |value|
            expect(subject.call(value).to_h).to eq(
              {
                type: 'shareholding',
                details: value,
                share: { minimum: 75, maximum: 100, exclusiveMinimum: false, exclusiveMaximum: false },
              },
            )
          end
        end
      end

      context 'with voting-rights-25-to-50-percent*' do
        it 'returns correct interest' do
          %w[
            voting-rights-25-to-50-percent
            voting-rights-25-to-50-percent-as-trust
            voting-rights-25-to-50-percent-as-firm
            voting-rights-25-to-50-percent-limited-liability-partnership
            voting-rights-25-to-50-percent-as-trust-limited-liability-partnership
            voting-rights-25-to-50-percent-as-firm-limited-liability-partnership
          ].each do |value|
            expect(subject.call(value).to_h).to eq(
              {
                type: 'voting-rights',
                details: value,
                share: { minimum: 25, maximum: 50, exclusiveMinimum: true, exclusiveMaximum: false },
              },
            )
          end
        end
      end

      context 'with voting-rights-50-to-75-percent*' do
        it 'returns correct interest' do
          %w[
            voting-rights-50-to-75-percent
            voting-rights-50-to-75-percent-as-trust
            voting-rights-50-to-75-percent-as-firm
            voting-rights-50-to-75-percent-limited-liability-partnership
            voting-rights-50-to-75-percent-as-trust-limited-liability-partnership
            voting-rights-50-to-75-percent-as-firm-limited-liability-partnership
          ].each do |value|
            expect(subject.call(value).to_h).to eq(
              {
                type: 'voting-rights',
                details: value,
                share: { minimum: 50, maximum: 75, exclusiveMinimum: true, exclusiveMaximum: true },
              },
            )
          end
        end
      end

      context 'with voting-rights-75-to-100-percent*' do
        it 'returns correct interest' do
          %w[
            voting-rights-75-to-100-percent
            voting-rights-75-to-100-percent-as-trust
            voting-rights-75-to-100-percent-as-firm
            voting-rights-75-to-100-percent-limited-liability-partnership
            voting-rights-75-to-100-percent-as-trust-limited-liability-partnership
            voting-rights-75-to-100-percent-as-firm-limited-liability-partnership
          ].each do |value|
            expect(subject.call(value).to_h).to eq(
              {
                type: 'voting-rights',
                details: value,
                share: { minimum: 75, maximum: 100, exclusiveMinimum: false, exclusiveMaximum: false },
              },
            )
          end
        end
      end

      context 'with right-to-appoint-and-remove*' do
        it 'returns correct interest' do
          %w[
            right-to-appoint-and-remove-directors
            right-to-appoint-and-remove-directors-as-trust
            right-to-appoint-and-remove-directors-as-firm
            right-to-appoint-and-remove-members-limited-liability-partnership
            right-to-appoint-and-remove-members-as-trust-limited-liability-partnership
            right-to-appoint-and-remove-members-as-firm-limited-liability-partnership
          ].each do |value|
            expect(subject.call(value).to_h).to eq(
              {
                type: 'appointment-of-board',
                details: value,
              },
            )
          end
        end
      end

      context 'with right-to-share-surplus-assets*' do
        it 'returns correct interest' do
          %w[
            right-to-share-surplus-assets-25-to-50-percent-limited-liability-partnership
            right-to-share-surplus-assets-50-to-75-percent-limited-liability-partnership
            right-to-share-surplus-assets-75-to-100-percent-limited-liability-partnership
            right-to-share-surplus-assets-25-to-50-percent-as-trust-limited-liability-partnership
            right-to-share-surplus-assets-50-to-75-percent-as-trust-limited-liability-partnership
            right-to-share-surplus-assets-75-to-100-percent-as-trust-limited-liability-partnership
            right-to-share-surplus-assets-25-to-50-percent-as-firm-limited-liability-partnership
            right-to-share-surplus-assets-50-to-75-percent-as-firm-limited-liability-partnership
            right-to-share-surplus-assets-75-to-100-percent-as-firm-limited-liability-partnership
          ].each do |value|
            expect(subject.call(value).to_h).to eq(
              {
                type: 'rights-to-surplus-assets-on-dissolution',
                details: value,
              },
            )
          end
        end
      end

      context 'with any other value' do
        it 'returns correct interest' do
          [
            'significant-influence-or-control',
            'a different value',
          ].each do |value|
            expect(subject.call(value).to_h).to eq(
              {
                type: 'other-influence-or-control',
                details: value,
              },
            )
          end
        end
      end
    end

    context 'when given an unknown type' do
      let(:interest) { 123 }

      it 'raises an error' do
        expect { subject.call(interest).to_h }.to raise_error(described_class::UnexpectedInterestTypeError)
      end
    end
  end
end
