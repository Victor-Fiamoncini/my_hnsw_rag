# frozen_string_literal: true

require 'rack/test'

RSpec.describe MyFaissRag::Web do
  include Rack::Test::Methods

  let(:app) { described_class }
  let(:assistant) { instance_double(MyFaissRag::Assistant, ask: '8 horas diárias.') }

  before { described_class.assistant = assistant }
  after { described_class.assistant = nil }

  def ask(body)
    post '/ask', body, 'CONTENT_TYPE' => 'application/json'
  end

  it 'renders the chat page' do
    get '/'

    expect(last_response.body).to include('Assistente RAG')
  end

  it 'serves the stylesheet' do
    get '/styles.css'

    expect(last_response.content_type).to start_with('text/css')
  end

  it 'serves the script' do
    get '/app.js'

    expect(last_response.content_type).to start_with('text/javascript')
  end

  it 'links the favicons' do
    get '/'

    expect(last_response.body).to include('href="/favicon.svg"', 'href="/favicon.ico"', 'href="/apple-touch-icon.png"')
  end

  {
    '/favicon.svg' => 'image/svg+xml',
    '/favicon.ico' => 'image/vnd.microsoft.icon',
    '/apple-touch-icon.png' => 'image/png'
  }.each do |path, type|
    it "serves #{path}" do
      get path

      expect(last_response.content_type).to start_with(type)
    end
  end

  it 'answers a question' do
    ask({ question: 'Qual a jornada?' }.to_json)

    expect(JSON.parse(last_response.body)).to eq('answer' => '8 horas diárias.')
  end

  it 'rejects a blank question' do
    ask({ question: '  ' }.to_json)

    expect(last_response.status).to eq(422)
  end

  it 'rejects a malformed body' do
    ask('not json')

    expect(last_response.status).to eq(400)
  end

  it 'returns a friendly error when the assistant fails' do
    allow(assistant).to receive(:ask).and_raise(Faraday::ConnectionFailed, 'offline')

    ask({ question: 'Qual a jornada?' }.to_json)

    expect(last_response.status).to eq(502)
  end
end
