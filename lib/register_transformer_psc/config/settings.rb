require 'dotenv'

if ENV['TEST'].to_i == 1
  print "LOADING TEST\n"
  Dotenv.load('.test.env')
else
  print "LOADING REAL ENV:\n\n#{File.read(".env")}\n"
  Dotenv.load('.env')
end

print "GOT ENV", ENV.to_h, "\n\n"

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
