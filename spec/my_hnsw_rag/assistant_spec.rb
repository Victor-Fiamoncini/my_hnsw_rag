# frozen_string_literal: true

RSpec.describe MyHnswRag::Assistant do
  it 'points to the sample document in data/' do
    expect(described_class::PDF_PATH).to end_with('/data/document_sample.pdf')
  end

  it 'keeps the vector index in data/' do
    expect(described_class::INDEX_PATH).to end_with('/data/index.ann')
  end

  describe '.pdf_text' do
    let(:loader) { instance_double(Langchain::Loader, load: pdf_data) }
    let(:pdf_data) { instance_double(Langchain::Data) }

    before do
      allow(File).to receive(:exist?).with(described_class::PDF_PATH).and_return(true)
      allow(Langchain::Loader).to receive(:new).and_return(loader)
    end

    it 'loads the PDF with the recursive text chunker' do
      described_class.pdf_text

      expect(Langchain::Loader).to have_received(:new)
        .with(described_class::PDF_PATH, chunker: Langchain::Chunker::RecursiveText)
    end

    it 'returns the loaded data' do
      expect(described_class.pdf_text).to eq(pdf_data)
    end

    it 'fails with a clear message when the PDF is missing' do
      allow(File).to receive(:exist?).with(described_class::PDF_PATH).and_return(false)

      expect { described_class.pdf_text }.to raise_error(ArgumentError, /PDF not found at .*document_sample\.pdf/)
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

  describe '.create_vector_database' do
    let(:llm) { instance_double(Langchain::LLM::OpenAI) }
    let(:vector_store) { instance_double(Langchain::Vectorsearch::Hnswlib, add_texts: true) }
    let(:path) { '/index/test.ann' }

    before { allow(Langchain::Vectorsearch::Hnswlib).to receive(:new).and_return(vector_store) }

    context 'when the index file does not exist' do
      before { allow(File).to receive(:exist?).with(path).and_return(false) }

      it 'builds an Hnswlib store at the given path' do
        described_class.create_vector_database(%w[a b], llm:, path:)

        expect(Langchain::Vectorsearch::Hnswlib).to have_received(:new).with(llm:, path_to_index: path)
      end

      it 'embeds the chunks, using their positions as ids' do
        described_class.create_vector_database(%w[a b], llm:, path:)

        expect(vector_store).to have_received(:add_texts).with(texts: %w[a b], ids: [0, 1])
      end

      it 'returns the store' do
        expect(described_class.create_vector_database(%w[a b], llm:, path:)).to eq(vector_store)
      end
    end

    context 'when the index file already exists' do
      before { allow(File).to receive(:exist?).with(path).and_return(true) }

      it 'reuses the saved index without embedding again' do
        described_class.create_vector_database(%w[a b], llm:, path:)

        expect(vector_store).not_to have_received(:add_texts)
      end
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
      vector_store = instance_double(Langchain::Vectorsearch::Hnswlib, similarity_search: [[0], [0.1]])
      allow(llm).to receive(:chat)
        .and_return(instance_double(Langchain::LLM::OpenAIResponse, chat_completion: '8 horas diárias.'))

      expect(described_class.new(chunks: ['Jornada'], vector_store:).ask('Qual a jornada?')).to eq('8 horas diárias.')
    end
  end

  describe '#ask' do
    subject(:assistant) { described_class.new(llm:, chunks:, vector_store:) }

    let(:llm) { instance_double(Langchain::LLM::OpenAI) }
    let(:chunks) { ['Férias de 30 dias.', 'Jornada de 8 horas.', 'Home office às sextas.'] }
    let(:vector_store) { instance_double(Langchain::Vectorsearch::Hnswlib, similarity_search: [[1, 2], [0.1, 0.3]]) }

    before do
      allow(llm).to receive(:chat)
        .and_return(instance_double(Langchain::LLM::OpenAIResponse, chat_completion: '8 horas diárias.'))
    end

    it 'answers with the chat completion' do
      expect(assistant.ask('Qual a jornada?')).to eq('8 horas diárias.')
    end

    it 'searches the store with the question' do
      assistant.ask('Qual a jornada?')

      expect(vector_store).to have_received(:similarity_search).with(query: 'Qual a jornada?', k: 3)
    end

    it 'sends the retrieved chunks and the question in the prompt' do
      assistant.ask('Qual a jornada?')

      prompt = a_string_including(
        "Contexto: Jornada de 8 horas.\n\nHome office às sextas.", 'Pergunta: Qual a jornada?'
      )

      expect(llm).to have_received(:chat).with(messages: [{ role: 'user', content: prompt }])
    end

    context 'with more chunks than the context size' do
      let(:chunks) { Array.new(10) { |i| "Trecho #{i}" } }

      it 'asks for the configured number of chunks' do
        assistant.ask('Qual a jornada?')

        expect(vector_store).to have_received(:similarity_search)
          .with(query: 'Qual a jornada?', k: described_class::CONTEXT_CHUNKS)
      end
    end

    context 'without an injected store' do
      subject(:assistant) { described_class.new(llm:) }

      let(:pdf_data) { instance_double(Langchain::Data) }

      before do
        allow(described_class).to receive_messages(pdf_text: pdf_data, split_pdf_text: chunks,
                                                   create_vector_database: vector_store)
      end

      it 'builds the store from the PDF chunks once' do
        2.times { assistant.ask('Qual a jornada?') }

        expect(described_class).to have_received(:create_vector_database).once.with(chunks, llm:)
      end

      it 'splits the loaded PDF' do
        assistant.ask('Qual a jornada?')

        expect(described_class).to have_received(:split_pdf_text).with(pdf_data)
      end
    end
  end
end
