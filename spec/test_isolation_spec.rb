# frozen_string_literal: true

require 'net/http'

# Guards set up in spec_helper.rb; if these fail, specs could reach OpenAI.
RSpec.describe 'Test isolation' do # rubocop:disable RSpec/DescribeClass
  it 'uses a fake OpenAI API key' do
    expect(ENV.fetch('OPENAI_API_KEY')).to eq('test-openai-api-key')
  end

  it 'blocks real HTTP requests' do
    expect { Net::HTTP.get(URI('https://api.openai.com/v1/models')) }
      .to raise_error(WebMock::NetConnectNotAllowedError)
  end
end
