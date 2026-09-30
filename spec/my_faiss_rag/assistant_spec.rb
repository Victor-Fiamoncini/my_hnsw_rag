# frozen_string_literal: true

RSpec.describe MyFaissRag::Assistant do
  it 'points to the sample document in data/' do
    expect(described_class::PDF_PATH).to end_with('/data/document_sample.pdf')
  end

  describe '.pdf_text' do
    let(:loader) { instance_double(Langchain::Loader, load: pdf_data) }
    let(:pdf_data) { instance_double(Langchain::Data) }

    before { allow(Langchain::Loader).to receive(:new).and_return(loader) }

    it 'loads the PDF with the recursive text chunker' do
      described_class.pdf_text

      expect(Langchain::Loader).to have_received(:new)
        .with(described_class::PDF_PATH, chunker: Langchain::Chunker::RecursiveText)
    end

    it 'returns the loaded data' do
      expect(described_class.pdf_text).to eq(pdf_data)
    end
  end

  describe '.split_pdf_text' do
    let(:pdf_data) { instance_double(Langchain::Data, chunks: [chunk('Capítulo 1'), chunk('Capítulo 2')]) }

    def chunk(text) = instance_double(Langchain::Chunk, text:)

    it 'returns the text of each chunk' do
      expect(described_class.split_pdf_text(pdf_data)).to eq(['Capítulo 1', 'Capítulo 2'])
    end

    it 'chunks with the configured size and overlap' do
      described_class.split_pdf_text(pdf_data)

      expect(pdf_data).to have_received(:chunks).with(**described_class::CHUNK_OPTIONS)
    end
  end

  describe '.default_llm' do
    let(:llm) { instance_double(Langchain::LLM::OpenAI) }

    before { allow(Langchain::LLM::OpenAI).to receive(:new).and_return(llm) }

    it 'builds an OpenAI client with the API key and gpt-4o-mini' do
      described_class.default_llm

      expect(Langchain::LLM::OpenAI).to have_received(:new)
        .with(api_key: 'test-openai-api-key', default_options: { chat_model: 'gpt-4o-mini' })
    end

    it 'is used when no LLM is given' do
      allow(llm).to receive(:chat)
        .and_return(instance_double(Langchain::LLM::OpenAIResponse, chat_completion: '8 horas diárias.'))

      expect(described_class.new.ask('Qual a jornada?')).to eq('8 horas diárias.')
    end
  end

  describe '#ask' do
    subject(:assistant) { described_class.new(llm:) }

    let(:llm) { instance_double(Langchain::LLM::OpenAI) }

    before do
      allow(llm).to receive(:chat)
        .and_return(instance_double(Langchain::LLM::OpenAIResponse, chat_completion: '8 horas diárias.'))
    end

    it 'answers with the chat completion' do
      expect(assistant.ask('Qual a jornada?')).to eq('8 horas diárias.')
    end

    it 'sends the context and the question in the prompt' do
      assistant.ask('Qual a jornada?')

      prompt = a_string_including('Contexto: A jornada de trabalho padrão', 'Pergunta: Qual a jornada?')

      expect(llm).to have_received(:chat).with(messages: [{ role: 'user', content: prompt }])
    end
  end
end
