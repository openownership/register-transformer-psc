require 'dotenv'

if ENV['TEST'].to_i == 1
  Dotenv.load('.test.env')
else
  Dotenv.load('.env')
end

module RegisterTransformerPsc
  module Config
    AwsCredentialsStruct = Struct.new(
      :AWS_REGION,
      :AWS_ACCESS_KEY_ID,
      :AWS_SECRET_ACCESS_KEY,
    )

    AWS_CREDENTIALS = AwsCredentialsStruct.new(
      ENV.fetch('BODS_AWS_REGION'),
      ENV.fetch('BODS_AWS_ACCESS_KEY_ID'),
      ENV.fetch('BODS_AWS_SECRET_ACCESS_KEY'),
    )
  end
end
