class Tts::DispatcherJob < ApplicationJob
  queue_as :default
  
  def perform(speech_request_id)
    speech_request = SpeechRequest.find(speech_request_id)
    
    # Update status to processing
    speech_request.update!(status: 'processing')
    
    # Dispatch to each provider
    providers = %w[resemble elevenlabs openai]
    
    providers.each do |provider|
      if Rails.env.development? && !has_real_api_keys?
        # Use mock jobs in development without real API keys
        Tts::DevelopmentProviderJob.perform_later(speech_request_id, provider)
      else
        # Use real API jobs
        case provider
        when 'resemble'
          Tts::ResembleJob.perform_later(speech_request_id)
        when 'elevenlabs'
          Tts::ElevenlabsJob.perform_later(speech_request_id)
        when 'openai'
          Tts::OpenaiJob.perform_later(speech_request_id)
        end
      end
    end
    
    Rails.logger.info "Dispatched TTS jobs for SpeechRequest #{speech_request_id} to #{providers.join(', ')}"
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "SpeechRequest #{speech_request_id} not found: #{e.message}"
  rescue => e
    Rails.logger.error "Error dispatching TTS jobs for SpeechRequest #{speech_request_id}: #{e.message}"
    speech_request&.update(status: 'failed')
    raise
  end
  
  private
  
  def has_real_api_keys?
    ENV['RESEMBLE_API_KEY'].present? && ENV['RESEMBLE_API_KEY'] != 'your_resemble_api_key_here' &&
    ENV['ELEVENLABS_API_KEY'].present? && ENV['ELEVENLABS_API_KEY'] != 'your_elevenlabs_api_key_here' &&
    ENV['OPENAI_API_KEY'].present? && ENV['OPENAI_API_KEY'] != 'your_openai_api_key_here'
  end
end
