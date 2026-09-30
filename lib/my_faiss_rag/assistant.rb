# frozen_string_literal: true

module MyFaissRag
  class Assistant
    PDF_PATH = File.expand_path('../../data/document_sample.pdf', __dir__)

    CHUNK_OPTIONS = {
      chunk_size: 1000,
      chunk_overlap: 200,
      separators: ["\n\n", "\n", ' ', '']
    }.freeze

    PROMPT_TEMPLATE = <<~PROMPT
      Você é um assistente de RH que responde perguntas sobre políticas internas da empresa.
      Use APENAS as informações do contexto abaixo para responder.
      Se não encontrar a resposta, diga claramente que não sabe responder.
      Responda em português do Brasil, de forma clara e objetiva.

      Contexto: %<context>s

      Pergunta: %<question>s

      Resposta:
    PROMPT

    def self.pdf_text(path = PDF_PATH)
      Langchain::Loader.new(path, chunker: Langchain::Chunker::RecursiveText).load
    end

    def self.split_pdf_text(pdf_text)
      pdf_text.chunks(**CHUNK_OPTIONS).map(&:text)
    end

    def self.default_llm
      Langchain::LLM::OpenAI.new(
        api_key: ENV.fetch('OPENAI_API_KEY'),
        default_options: { chat_model: 'gpt-4o-mini' }
      )
    end

    def initialize(llm: self.class.default_llm)
      @llm = llm
    end

    def ask(question)
      prompt = format(PROMPT_TEMPLATE, context: create_context(question), question:)

      @llm.chat(messages: [{ role: 'user', content: prompt }]).chat_completion
    end

    private

    def create_context(_question)
      'A jornada de trabalho padrão da Nexus Tecnologia é de 8 horas diárias e 40 horas semanais, ' \
        'de segunda a sexta-feira. O horário base é das 9h às 18h, com 1 hora de intervalo para almoço ' \
        'entre 12h e 14h, a critério do colaborador.'
    end
  end
end
