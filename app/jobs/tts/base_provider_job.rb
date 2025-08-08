require_relative '../../services/mock_s3_service'

class Tts::BaseProviderJob < ApplicationJob
  queue_as :tts_providers
  
  # Retry configuration
  retry_on StandardError, wait: 5.seconds, attempts: 3
  
  protected
  
  def perform_tts_request(speech_request_id, provider_name)
    speech_request = SpeechRequest.find(speech_request_id)
    
    # Check if already processed
    existing_result = speech_request.provider_result_for(provider_name)
    if existing_result&.dig('status') == 'completed'
      Rails.logger.info "#{provider_name} already completed for SpeechRequest #{speech_request_id}"
      return
    end
    
    Rails.logger.info "Starting #{provider_name} TTS for SpeechRequest #{speech_request_id}"
    
    # Call provider-specific implementation
    result = call_provider_api(speech_request.text)
    
    # Upload to S3
    s3_key = upload_to_s3(result[:audio_data], speech_request.id, provider_name, result[:format])
    
    # Update speech request with success
    speech_request.add_provider_result(provider_name, {
      status: 'completed',
      s3_key: s3_key,
      filename: "#{speech_request.id}_#{provider_name}.#{result[:format]}",
      format: result[:format],
      size: result[:audio_data].bytesize,
      duration: result[:duration],
      error_message: nil
    })
    
    speech_request.save!
    
    Rails.logger.info "#{provider_name} TTS completed for SpeechRequest #{speech_request_id}"
    
  rescue => e
    Rails.logger.error "#{provider_name} TTS failed for SpeechRequest #{speech_request_id}: #{e.message}"
    
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
  
  def call_provider_api(text)
    raise NotImplementedError, "Subclasses must implement call_provider_api"
  end
  
  def upload_to_s3(audio_data, speech_request_id, provider_name, format)
    # Check if we should use real S3 or mock service
    if Rails.env.development? && !has_real_aws_keys?
      # Use mock service in development without real AWS keys
      MockS3Service.upload_file(audio_data, speech_request_id, provider_name, format)
    else
      # Use real S3 service
      S3Service.upload_file(audio_data, speech_request_id, provider_name, format)
    end
  end
  
  def has_real_aws_keys?
    ENV['AWS_ACCESS_KEY_ID'].present? && ENV['AWS_ACCESS_KEY_ID'] != 'your_aws_access_key_here' &&
    ENV['AWS_SECRET_ACCESS_KEY'].present? && ENV['AWS_SECRET_ACCESS_KEY'] != 'your_aws_secret_key_here' &&
    ENV['AWS_S3_BUCKET'].present? && ENV['AWS_S3_BUCKET'] != 'your-tts-bucket-name'
  end
end
