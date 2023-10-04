# frozen_string_literal: true

require 'register_common/structs/aws_credentials'

module RegisterTransformerPsc
  module Config
    AWS_CREDENTIALS = RegisterCommon::AwsCredentials.new(
      ENV.fetch('BODS_AWS_REGION'),
      ENV.fetch('BODS_AWS_ACCESS_KEY_ID'),
      ENV.fetch('BODS_AWS_SECRET_ACCESS_KEY')
    )
  end
end
