class Tts::OpenaiJob < Tts::BaseProviderJob
  def perform(speech_request_id)
    perform_tts_request(speech_request_id, 'openai')
  end
  
  private
  
  def call_provider_api(text)
    # OpenAI TTS API implementation
    # https://platform.openai.com/docs/guides/text-to-speech
    
    api_key = ENV['OPENAI_API_KEY']
    raise "OPENAI_API_KEY not configured" unless api_key
    
    # Character limit check
    if text.length > 4096
      raise "Text too long for OpenAI TTS (max 4096 characters)"
    end
    
    response = HTTParty.post(
      'https://api.openai.com/v1/audio/speech',
      headers: {
        'Authorization' => "Bearer #{api_key}",
        'Content-Type' => 'application/json'
      },
      body: {
        model: 'tts-1',
        input: text,
        voice: 'alloy',
        response_format: 'mp3',
        speed: 1.0
      }.to_json,
      timeout: 60
    )
    
    if response.success?
      {
        audio_data: response.body,
        format: 'mp3',
        duration: estimate_duration(text)
      }
    else
      error_message = begin
        parsed = JSON.parse(response.body)
        parsed.dig('error', 'message') || 'Unknown error'
      rescue
        response.body
      end
      
      raise "OpenAI API error: #{response.code} - #{error_message}"
    end
  end
  
  def estimate_duration(text)
    # OpenAI TTS: roughly 150 words per minute, ~5 characters per word
    words = text.length / 5.0
    minutes = words / 150.0
    (minutes * 60).round(2)
  end
end
