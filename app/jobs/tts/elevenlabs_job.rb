class Tts::ElevenlabsJob < Tts::BaseProviderJob
  def perform(speech_request_id)
    perform_tts_request(speech_request_id, 'elevenlabs')
  end
  
  private
  
  def call_provider_api(text)
    # ElevenLabs API implementation
    # https://docs.elevenlabs.io/
    
    api_key = ENV['ELEVENLABS_API_KEY']
    raise "ELEVENLABS_API_KEY not configured" unless api_key
    
    # Character limit check
    if text.length > 2500
      raise "Text too long for ElevenLabs (max 2500 characters)"
    end
    
    voice_id = 'pNInz6obpgDQGcFmaJgB' # Default voice (Adam)
    
    response = HTTParty.post(
      "https://api.elevenlabs.io/v1/text-to-speech/#{voice_id}",
      headers: {
        'Accept' => 'audio/mpeg',
        'Content-Type' => 'application/json',
        'xi-api-key' => api_key
      },
      body: {
        text: text,
        model_id: 'eleven_monolingual_v1',
        voice_settings: {
          stability: 0.5,
          similarity_boost: 0.5
        }
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
        parsed['detail'] || parsed['message'] || 'Unknown error'
      rescue
        response.body
      end
      
      raise "ElevenLabs API error: #{response.code} - #{error_message}"
    end
  end
  
  def estimate_duration(text)
    # Rough estimation: ~150 words per minute, ~5 characters per word
    words = text.length / 5.0
    minutes = words / 150.0
    (minutes * 60).round(2)
  end
end
