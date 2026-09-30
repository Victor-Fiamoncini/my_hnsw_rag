# frozen_string_literal: true

require 'bundler/setup'
Bundler.require(:default)

if ENV.fetch('APP_ENV', 'development') != 'production'
  require 'dotenv'
  Dotenv.load(File.expand_path('../.env.local', __dir__))
end

require_relative 'my_hnsw_rag/assistant'
require_relative 'my_hnsw_rag/web'

module MyHnswRag
end
