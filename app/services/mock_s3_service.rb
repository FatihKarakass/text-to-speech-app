class MockS3Service
  def self.upload_file(audio_data, speech_request_id, provider_name, format)
    # Create mock S3 key
    key = "speech_requests/#{speech_request_id}/#{provider_name}_#{Time.current.to_i}.#{format}"
    
    # Create local storage for development
    storage_path = Rails.root.join('tmp', 'mock_s3', key)
    FileUtils.mkdir_p(storage_path.dirname)
    
    # Write audio data to local file
    File.open(storage_path, 'wb') do |file|
      file.write(audio_data)
    end
    
    Rails.logger.info "Mock S3: Uploaded #{audio_data.bytesize} bytes to #{key}"
    
    key
  end
  
  def self.generate_presigned_url(key)
    # Generate mock download URL for development
    "http://localhost:3000/mock_s3/#{key}"
  end
end
