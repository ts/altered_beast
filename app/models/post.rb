class Post < ActiveRecord::Base
  include User::Editable
  
  formats_attributes :body

  # author of post
  belongs_to :user, :counter_cache => true
  
  belongs_to :topic, :counter_cache => true
  
  # topic's forum (set by callback)
  belongs_to :forum, :counter_cache => true
  
  # topic's site (set by callback)
  belongs_to :site, :counter_cache => true
  
  validates_presence_of :user_id, :site_id, :topic_id, :forum_id, :body
  validate :topic_is_not_locked

  after_create  :update_cached_fields
  after_create  :save_file
  after_destroy :update_cached_fields
  after_destroy  :delete_attachment

  attr_accessible :body

  def delete_attachment
    if File.exists?(self.file_name)
      File.delete(self.file)
      Dir.rmdir(File.dirname(self.file))
    end
  end
  
  def file=(uploaded_file)  
    return unless uploaded_file
    @uploaded_file = uploaded_file
    self.file_name = sanitize_filename(@uploaded_file.original_filename)
    self.content_type =  @uploaded_file.content_type
    self.file_size = @uploaded_file.size
  end
  
  def save_file
    return true unless @uploaded_file
    if !File.exists?(File.dirname(self.path_to_file))
      Dir.mkdir(File.dirname(self.path_to_file))
    end
    if @uploaded_file.instance_of?(Tempfile)
      FileUtils.copy(@uploaded_file.local_path, self.path_to_file)
      return true
    else
      File.open(self.path_to_file, "wb") { |f| f.write(@uploaded_file.read) }
      return true
    end
    return false
  end
  
  def path_to_file
    path = "#{RAILS_ROOT}/public/images/attachments/#{self.file_name}"
    File.expand_path(path)
  end
  
  def file_url
    "#{ActionController::Base.asset_host}/images/attachments/#{self.file_name}"
  end
  
  def forum_name
    forum.name
  end

  def self.search(query, options = {})
  # had to change the other join string since it conflicts when we bring parents in
    options[:conditions] ||= ["LOWER(#{Post.table_name}.body) LIKE ?", "%#{query}%"] unless query.blank?
    options[:select]     ||= "#{Post.table_name}.*, #{Topic.table_name}.title as topic_title, f.name as forum_name"
    options[:joins]      ||= "inner join #{Topic.table_name} on #{Post.table_name}.topic_id = #{Topic.table_name}.id " + 
                             "inner join #{Forum.table_name} as f on #{Topic.table_name}.forum_id = f.id"
    options[:order]      ||= "#{Post.table_name}.created_at DESC"
    options[:count]      ||= {:select => "#{Post.table_name}.id"}
    paginate options
  end

protected
  def sanitize_filename(file_name)
    # get only the filename, not the whole path (from IE)
    just_filename = File.basename(file_name) 
    # replace all none alphanumeric, underscore or perioids with underscore
    just_filename.gsub(/[^\w\.\_]/,'_') 
  end


  def update_cached_fields
    topic.update_cached_post_fields(self)
  end
  
  def topic_is_not_locked
    errors.add_to_base("Topic is locked") if topic && topic.locked? && topic.posts_count > 0
  end
end
