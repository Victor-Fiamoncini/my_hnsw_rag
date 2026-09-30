# frozen_string_literal: true

require 'json'
require 'sinatra/base'

module MyHnswRag
  class Web < Sinatra::Base
    set :views, File.expand_path('views', __dir__)
    set :public_folder, File.expand_path('public', __dir__)

    class << self
      attr_writer :assistant

      def assistant
        @assistant ||= Assistant.new
      end
    end

    get '/' do
      erb :index
    end

    post '/ask' do
      content_type :json

      question = JSON.parse(request.body.read)['question'].to_s.strip
      halt 422, { error: 'Digite uma pergunta.' }.to_json if question.empty?

      { answer: self.class.assistant.ask(question) }.to_json
    rescue JSON::ParserError
      halt 400, { error: 'Requisição inválida.' }.to_json
    rescue StandardError => e
      logger.error("#{e.class}: #{e.message}")
      halt 502, { error: 'Não foi possível gerar a resposta. Tente novamente.' }.to_json
    end
  end
end
