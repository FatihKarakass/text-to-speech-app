class CreateSpeechRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :speech_requests do |t|
      t.text :text, null: false
      t.string :text_hash, null: false
      t.string :status, default: 'pending', null: false
      t.json :provider_results, default: []
      
      t.timestamps
    end
    
    add_index :speech_requests, :text_hash, unique: true
    add_index :speech_requests, :status
    add_index :speech_requests, :created_at
  end
end
