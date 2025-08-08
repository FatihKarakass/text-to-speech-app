class TtsController < ApplicationController
  def index
    @recent_requests = SpeechRequest.recent.limit(10)
  end
  
  def create
    @speech_request = SpeechRequest.new(speech_request_params)
    
    if @speech_request.save
      # Dispatch to background job
      Tts::DispatcherJob.perform_later(@speech_request.id)
      
      redirect_to speech_request_path(@speech_request), 
                  notice: 'TTS request submitted successfully! Processing in background.'
    else
      @recent_requests = SpeechRequest.recent.limit(10)
      render :index, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "Error creating TTS request: #{e.message}"
    redirect_to root_path, alert: 'An error occurred while submitting your request.'
  end
  
  def show
    @speech_request = SpeechRequest.find(params[:id])
  end
  
  def download
    @speech_request = SpeechRequest.find(params[:speech_request_id])
    provider = params[:provider]
    
    result = @speech_request.provider_result_for(provider)
    
    if result && result['status'] == 'completed'
      if Rails.env.development? && result['s3_key'].present?
        # Development mock download
        file_path = Rails.root.join('tmp', 'mock_s3', result['s3_key'])
        
        if File.exist?(file_path)
          send_file file_path, 
                    filename: result['filename'], 
                    type: "audio/#{result['format']}"
        else
          redirect_to speech_request_path(@speech_request), 
                      alert: 'Mock audio file not found.'
        end
      else
        # Production S3 download using S3Service
        if has_real_aws_keys?
          presigned_url = S3Service.generate_presigned_url(result['s3_key'], expires_in: 300)
        else
          # Fallback to mock service
          presigned_url = MockS3Service.generate_presigned_url(result['s3_key'])
        end
        
        redirect_to presigned_url, allow_other_host: true
      end
    else
      redirect_to speech_request_path(@speech_request), 
                  alert: 'Audio file not available for this provider.'
    end
  end
  
  def cancel
    @speech_request = SpeechRequest.find(params[:id])
    
    # Update status to cancelled
    @speech_request.update!(status: 'cancelled')
    
    # Cancel any pending jobs in Sidekiq
    cancel_pending_jobs(@speech_request.id)
    
    redirect_to speech_request_path(@speech_request), 
                notice: 'TTS request cancelled successfully.'
  rescue => e
    Rails.logger.error "Error cancelling TTS request #{params[:id]}: #{e.message}"
    redirect_to speech_request_path(@speech_request), 
                alert: 'Failed to cancel the request.'
  end
  
  def retry_request
    @speech_request = SpeechRequest.find(params[:id])
    
    # Reset failed/cancelled providers and restart
    @speech_request.provider_results.each do |result|
      if result['status'].in?(%w[failed cancelled])
        result['status'] = 'pending'
        result['error_message'] = nil
      end
    end
    
    @speech_request.update!(status: 'processing')
    
    # Dispatch jobs for failed providers only
    failed_providers = @speech_request.provider_results
                                     .select { |r| r['status'] == 'pending' }
                                     .map { |r| r['provider'] }
    
    failed_providers.each do |provider|
      if Rails.env.development? && !has_real_api_keys?
        Tts::DevelopmentProviderJob.perform_later(@speech_request.id, provider)
      else
        dispatch_provider_job(@speech_request.id, provider)
      end
    end
    
    redirect_to speech_request_path(@speech_request), 
                notice: "Retrying failed providers: #{failed_providers.join(', ')}"
  rescue => e
    Rails.logger.error "Error retrying TTS request #{params[:id]}: #{e.message}"
    redirect_to speech_request_path(@speech_request), 
                alert: 'Failed to retry the request.'
  end
  
  private
  
  def speech_request_params
    params.require(:speech_request).permit(:text)
  end
  
  def cancel_pending_jobs(speech_request_id)
    begin
      require 'sidekiq/api'
      
      # Find and cancel pending jobs for this speech request
      Sidekiq::Queue.new.each do |job|
        if job.args.include?(speech_request_id) || job.args.include?(speech_request_id.to_s)
          job.delete
          Rails.logger.info "Cancelled job #{job.jid} for SpeechRequest #{speech_request_id}"
        end
      end
      
      # Also check retry and scheduled sets
      Sidekiq::RetrySet.new.each do |job|
        if job.args.include?(speech_request_id) || job.args.include?(speech_request_id.to_s)
          job.delete
        end
      end
    rescue LoadError => e
      Rails.logger.error "Sidekiq not available: #{e.message}"
    rescue => e
      Rails.logger.error "Error cancelling jobs: #{e.message}"
    end
  end
  
  def has_real_api_keys?
    ENV['RESEMBLE_API_KEY'].present? && ENV['RESEMBLE_API_KEY'] != 'your_resemble_api_key_here' &&
    ENV['ELEVENLABS_API_KEY'].present? && ENV['ELEVENLABS_API_KEY'] != 'your_elevenlabs_api_key_here' &&
    ENV['OPENAI_API_KEY'].present? && ENV['OPENAI_API_KEY'] != 'your_openai_api_key_here'
  end
  
  def dispatch_provider_job(speech_request_id, provider)
    case provider
    when 'resemble'
      Tts::ResembleJob.perform_later(speech_request_id)
    when 'elevenlabs'
      Tts::ElevenlabsJob.perform_later(speech_request_id)
    when 'openai'
      Tts::OpenaiJob.perform_later(speech_request_id)
    end
  end
  
  def has_real_aws_keys?
    ENV['AWS_ACCESS_KEY_ID'].present? && ENV['AWS_ACCESS_KEY_ID'] != 'your_aws_access_key_here' &&
    ENV['AWS_SECRET_ACCESS_KEY'].present? && ENV['AWS_SECRET_ACCESS_KEY'] != 'your_aws_secret_key_here' &&
    ENV['AWS_S3_BUCKET'].present? && ENV['AWS_S3_BUCKET'] != 'your-tts-bucket-name'
  end
  
  def serve_mock_s3
    # Serve mock S3 files for development
    file_path = Rails.root.join('tmp', 'mock_s3', params[:path])
    
    if File.exist?(file_path)
      send_file file_path, 
                type: 'audio/mpeg',
                filename: File.basename(file_path),
                disposition: 'attachment'
    else
      render plain: 'Mock file not found', status: 404
    end
  end
end


