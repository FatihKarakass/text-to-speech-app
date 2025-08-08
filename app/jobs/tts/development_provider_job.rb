require_relative '../../services/mock_s3_service'

class Tts::DevelopmentProviderJob < ApplicationJob
  queue_as :tts_providers
  
  def perform(speech_request_id, provider_name)
    speech_request = SpeechRequest.find(speech_request_id)
    
    Rails.logger.info "Starting MOCK #{provider_name} TTS for SpeechRequest #{speech_request_id}"
    
    # Check if already processed
    existing_result = speech_request.provider_result_for(provider_name)
    if existing_result&.dig('status') == 'completed'
      Rails.logger.info "#{provider_name} already completed for SpeechRequest #{speech_request_id}"
      return
    end
    
    # Simulate processing time
    sleep(rand(2..5))
    
    # Generate mock audio data
    audio_data = generate_mock_audio(speech_request.text, provider_name)
    
    # Upload to mock S3
    s3_key = ::MockS3Service.upload_file(audio_data, speech_request.id, provider_name, 'mp3')
    
    # Update speech request with success
    speech_request.add_provider_result(provider_name, {
      status: 'completed',
      s3_key: s3_key,
      filename: "#{speech_request.id}_#{provider_name}.mp3",
      format: 'mp3',
      size: audio_data.bytesize,
      duration: estimate_duration(speech_request.text),
      error_message: nil
    })
    
    speech_request.save!
    
    Rails.logger.info "MOCK #{provider_name} TTS completed for SpeechRequest #{speech_request_id}"
    
  rescue => e
    Rails.logger.error "MOCK #{provider_name} TTS failed for SpeechRequest #{speech_request_id}: #{e.message}"
    
    # Update speech request with failure
    speech_request&.add_provider_result(provider_name, {
      status: 'failed',
      s3_key: nil,
      filename: nil,
      format: nil,
      size: nil,
      duration: nil,
      error_message: e.message
    })
    
    speech_request&.save
    raise
  end
  
  private
  
  def generate_mock_audio(text, provider_name)
    # Generate realistic mock MP3 with proper format and varying sizes
    
    duration_seconds = estimate_duration(text)
    
    # Provider-specific characteristics
    provider_config = case provider_name
    when 'openai'
      { bitrate: 128, quality: 0.9, base_size: 16000 }  # High quality
    when 'elevenlabs'  
      { bitrate: 192, quality: 0.95, base_size: 24000 } # Premium quality
    when 'resemble'
      { bitrate: 96, quality: 0.85, base_size: 12000 }  # Optimized
    else
      { bitrate: 128, quality: 0.9, base_size: 16000 }
    end
    
    # Calculate realistic file size based on provider
    estimated_size = (duration_seconds * provider_config[:base_size] * provider_config[:quality]).to_i
    
    # Create more realistic MP3-like structure
    # ID3v2 header (simplified)
    id3_header = [
      0x49, 0x44, 0x33, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  # ID3v2.3
    ].pack('C*')
    
    # MP3 frame header (MPEG-1 Layer III)
    mp3_frame_header = [0xFF, 0xFB, 0x90, 0x00].pack('C*')
    
    # Generate audio frames with realistic patterns
    frames = []
    frame_count = estimated_size / 417  # ~417 bytes per frame for 128kbps
    
    frame_count.times do |frame_num|
      # Create frame with some audio-like patterns
      frame_data = (0..413).map do |i|
        # Mix of patterns to simulate compressed audio
        base = (Math.sin((frame_num * 413 + i) * 0.001) * 127).to_i
        noise = rand(-10..10)
        provider_signature = case provider_name
        when 'openai'
          (Math.cos(i * 0.02) * 20).to_i
        when 'elevenlabs'
          (Math.sin(i * 0.03) * 30).to_i  
        when 'resemble'
          (Math.tan(i * 0.01) * 15).to_i rescue 0
        else
          0
        end
        
        ((base + noise + provider_signature) & 0xFF)
      end.pack('C*')
      
      frames << mp3_frame_header + frame_data
    end
    
    # Combine all parts
    id3_header + frames.join
  end
  
  def estimate_duration(text)
    # Rough estimation: ~150 words per minute, ~5 characters per word
    words = text.length / 5.0
    minutes = words / 150.0
    (minutes * 60).round(2)
  end
end
