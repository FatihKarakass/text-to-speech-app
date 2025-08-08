class SpeechRequest < ApplicationRecord
  # Status constants
  STATUSES = %w[pending processing partial completed failed cancelled].freeze
  
  # Validations
  validates :text, presence: true, length: { maximum: 10_000 }
  validates :status, inclusion: { in: STATUSES }
  validates :text_hash, presence: true, uniqueness: true
  
  # Callbacks
  before_validation :generate_text_hash, if: :text_changed?
  
  # Scopes
  scope :pending, -> { where(status: 'pending') }
  scope :processing, -> { where(status: 'processing') }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :recent, -> { order(created_at: :desc) }
  
  # Provider results helpers
  def add_provider_result(provider_name, result)
    self.provider_results ||= []
    
    # Remove existing result for this provider
    self.provider_results.reject! { |r| r['provider'] == provider_name.to_s }
    
    # Add new result
    result_data = {
      'provider' => provider_name.to_s,
      'status' => result[:status],
      's3_key' => result[:s3_key],
      'filename' => result[:filename],
      'format' => result[:format],
      'size' => result[:size],
      'duration' => result[:duration],
      'error_message' => result[:error_message],
      'generated_at' => Time.current.iso8601
    }
    
    self.provider_results << result_data
    update_overall_status
  end
  
  def provider_result_for(provider_name)
    provider_results&.find { |r| r['provider'] == provider_name.to_s }
  end
  
  def successful_results
    provider_results&.select { |r| r['status'] == 'completed' } || []
  end
  
  def failed_results
    provider_results&.select { |r| r['status'] == 'failed' } || []
  end
  
  def pending_providers
    all_providers = %w[resemble elevenlabs openai]
    completed_providers = provider_results&.map { |r| r['provider'] } || []
    all_providers - completed_providers
  end
  
  def all_completed?
    pending_providers.empty?
  end
  
  def any_successful?
    successful_results.any?
  end
  
  private
  
  def generate_text_hash
    # Include any voice options in hash for future extensibility
    content = "#{text}"
    self.text_hash = Digest::SHA256.hexdigest(content)
  end
  
  def update_overall_status
    return unless provider_results.present?
    
    if all_completed?
      self.status = any_successful? ? 'completed' : 'failed'
    elsif any_successful?
      self.status = 'partial'
    end
  end
end
