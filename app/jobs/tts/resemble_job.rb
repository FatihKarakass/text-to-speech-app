class Tts::ResembleJob < Tts::BaseProviderJob
  def perform(speech_request_id)
    perform_tts_request(speech_request_id, 'resemble')
  end
  
  private
  
  def call_provider_api(text)
    # Resemble AI API implementation
    # https://docs.resembleai.com/
    
    api_key = ENV['RESEMBLE_API_KEY']
    raise "RESEMBLE_API_KEY not configured" unless api_key
    
    # Character limit check
    if text.length > 5000
      raise "Text too long for Resemble (max 5000 characters)"
    end
    
    response = HTTParty.post(
      'https://app.resembleai.com/api/v1/projects/YOUR_PROJECT_ID/clips',
      headers: {
        'Authorization' => "Token token=#{api_key}",
        'Content-Type' => 'application/json'
      },
      body: {
        data: {
          type: 'clip',
          attributes: {
            body: text,
            voice_uuid: 'YOUR_VOICE_UUID', # You'll need to configure this
            title: "TTS_#{Time.current.to_i}",
            sample_rate: 44100,
            output_format: 'mp3'
          }
        }
      }.to_json,
      timeout: 60
    )
    
    if response.success?
      clip_data = response.parsed_response['data']
      
      # Poll for completion (Resemble is async)
      audio_url = wait_for_completion(clip_data['id'])
      
      # Download audio
      audio_response = HTTParty.get(audio_url, timeout: 30)
      
      {
        audio_data: audio_response.body,
        format: 'mp3',
        duration: clip_data.dig('attributes', 'duration') || 0
      }
    else
      raise "Resemble API error: #{response.code} - #{response.body}"
    end
  end
  
  def wait_for_completion(clip_id, max_attempts: 30)
    api_key = ENV['RESEMBLE_API_KEY']
    attempts = 0
    
    loop do
      attempts += 1
      
      response = HTTParty.get(
        "https://app.resembleai.com/api/v1/clips/#{clip_id}",
        headers: {
          'Authorization' => "Token token=#{api_key}"
        },
        timeout: 10
      )
      
      if response.success?
        clip_data = response.parsed_response['data']
        status = clip_data.dig('attributes', 'status')
        
        case status
        when 'completed'
          return clip_data.dig('attributes', 'audio_src')
        when 'failed'
          raise "Resemble clip generation failed"
        when 'queued', 'started'
          # Continue polling
          if attempts >= max_attempts
            raise "Resemble clip generation timeout"
          end
          sleep 2
        else
          raise "Unknown Resemble clip status: #{status}"
        end
      else
        raise "Resemble status check failed: #{response.code}"
      end
    end
  end
end
