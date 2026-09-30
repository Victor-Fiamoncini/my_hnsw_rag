# frozen_string_literal: true

module MyHnswRag
  class Assistant
    PDF_PATH = File.expand_path('../../data/document_sample.pdf', __dir__)
    INDEX_PATH = File.expand_path('../../data/index.ann', __dir__)

    CHUNK_OPTIONS = {
      chunk_size: 1000,
      chunk_overlap: 200,
      separators: ["\n\n", "\n", ' ', '']
    }.freeze

    CONTEXT_CHUNKS = 4

    PROMPT_TEMPLATE = <<~PROMPT
      Você é um assistente de RH que responde perguntas sobre políticas internas da empresa.
      Use APENAS as informações do contexto abaixo para responder.
      Se não encontrar a resposta, diga claramente que não sabe responder.
      Responda em português do Brasil, de forma clara e objetiva.

      Contexto: %<context>s

      Pergunta: %<question>s

      Resposta:
    PROMPT

    def self.default_llm
      Langchain::LLM::OpenAI.new(
        api_key: ENV.fetch('OPENAI_API_KEY'),
        default_options: { chat_model: 'gpt-4o-mini' }
      )
    end

    def self.pdf_text(path = PDF_PATH)
      raise ArgumentError, "PDF not found at #{path}" unless File.exist?(path)

      Langchain::Loader.new(path, chunker: Langchain::Chunker::RecursiveText).load
    end

    def self.split_pdf_text(pdf_text)
      pdf_text.chunks(**CHUNK_OPTIONS).map(&:text)
    end

    # Embeds the chunks only when the index file doesn't exist yet; otherwise
    # Hnswlib loads the saved index. Delete the file after changing the PDF.
    def self.create_vector_database(chunks, llm:, path: INDEX_PATH)
      index_exists = File.exist?(path)
      vector_store = Langchain::Vectorsearch::Hnswlib.new(llm:, path_to_index: path)
      vector_store.add_texts(texts: chunks, ids: chunks.each_index.to_a) unless index_exists
      vector_store
    end

    def initialize(llm: self.class.default_llm, chunks: nil, vector_store: nil)
      @llm = llm
      @chunks = chunks
      @vector_store = vector_store
      @setup_lock = Mutex.new
    end

    def ask(question)
      prompt = format(PROMPT_TEMPLATE, context: create_context(question), question:)

      @llm.chat(messages: [{ role: 'user', content: prompt }]).chat_completion
    end

    private

    def create_context(question)
      # hnswlib raises when k is larger than the number of indexed chunks.
      ids, = vector_store.similarity_search(query: question, k: [CONTEXT_CHUNKS, chunks.size].min)

      ids.map { |id| chunks[id] }.join("\n\n")
    end

    # Hnswlib returns only ids, so the chunks are kept to look up their text.
    def chunks
      @chunks ||= self.class.split_pdf_text(self.class.pdf_text)
    end

    # Built on the first question; the lock stops concurrent requests from embedding twice.
    def vector_store
      @setup_lock.synchronize do
        @vector_store ||= self.class.create_vector_database(chunks, llm: @llm)
      end
    end
  end
end
