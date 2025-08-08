require 'aws-sdk-s3'

class S3Service
  def self.upload_file(audio_data, speech_request_id, provider_name, format)
    # Generate S3 key
    key = "speech_requests/#{speech_request_id}/#{provider_name}_#{Time.current.to_i}.#{format}"
    
    # Upload to S3
    s3_client.put_object(
      bucket: bucket_name,
      key: key,
      body: audio_data,
      content_type: content_type_for(format),
      metadata: {
        'speech_request_id' => speech_request_id.to_s,
        'provider' => provider_name,
        'generated_at' => Time.current.iso8601
      }
    )
    
    Rails.logger.info "S3: Uploaded #{audio_data.bytesize} bytes to #{key}"
    
    key
  end
  
  def self.generate_presigned_url(key, expires_in: 3600)
    # Generate presigned URL for secure download
    signer = Aws::S3::Presigner.new(client: s3_client)
    
    signer.presigned_url(
      :get_object,
      bucket: bucket_name,
      key: key,
      expires_in: expires_in
    )
  end
  
  def self.delete_file(key)
    s3_client.delete_object(
      bucket: bucket_name,
      key: key
    )
    
    Rails.logger.info "S3: Deleted #{key}"
  rescue => e
    Rails.logger.error "S3: Failed to delete #{key}: #{e.message}"
  end
  
  private
  
  def self.s3_client
    @s3_client ||= Aws::S3::Client.new(
      region: ENV['AWS_REGION'] || 'us-east-1',
      access_key_id: ENV['AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
    )
  end
  
  def self.bucket_name
    ENV['AWS_S3_BUCKET'] || raise('AWS_S3_BUCKET not configured')
  end
  
  def self.content_type_for(format)
    case format.downcase
    when 'mp3'
      'audio/mpeg'
    when 'wav'
      'audio/wav'
    when 'ogg'
      'audio/ogg'
    else
      'application/octet-stream'
    end
  end
end
