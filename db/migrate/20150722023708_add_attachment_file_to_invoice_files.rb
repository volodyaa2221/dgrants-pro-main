class AddAttachmentFileToInvoiceFiles < ActiveRecord::Migration[7.1]
  def change
      add_column :invoice_files, :attachment, :binary
  end
end
