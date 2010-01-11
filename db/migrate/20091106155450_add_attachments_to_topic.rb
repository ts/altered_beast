class AddAttachmentsToTopic < ActiveRecord::Migration
  def self.up
    add_column :posts, :file_name, :string
    add_column :posts, :content_type, :string
    add_column :posts, :file_size, :integer
  end

  def self.down
    remove_column :topics, :file_size
    remove_column :topics, :content_type
    remove_column :topics, :file_name
  end
end
