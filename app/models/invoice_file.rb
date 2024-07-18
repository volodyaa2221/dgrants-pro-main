class InvoiceFile < ActiveRecord::Base

  # Paperclip Associations & Validations
  #----------------------------------------------------------------------
  # upload using paperclip
  has_attached_file :file,
      :path           => ':attachment/:id/:style/:custom_filename',
      :storage        => :s3,
      :url            => 's3-us-west-2.amazonaws.com',
      :s3_host_alias  => 'something.cloudfront.net'

  # validates_attachment :file, content_type: { content_type: [ "application/pdf",
  #                                                             "application/msword",
  #                                                             "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  #                                                             "application/vnd.openxmlformats-officedocument.wordprocessingml.document" ] }
  validates_attachment_presence :file  
  validates_attachment_size :file, less_than: 10.megabytes
  do_not_validate_attachment_file_type :file

  # Associations
  #----------------------------------------------------------------------
  belongs_to :passthrough
  belongs_to :invoice
  
  # Attributes methods
  #----------------------------------------------------------------------
  def name
    file_file_name.present? ? file_file_name : ""
  end
  
  def url
    file.present? ? file.url : ""
  end

  def size
    file.present? ? file.size : nil
  end
end