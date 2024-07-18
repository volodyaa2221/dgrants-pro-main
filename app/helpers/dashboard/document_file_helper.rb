module Dashboard::DocumentFileHelper

  def file_icon(file_name, view=nil)
    ext = File.extname(file_name.downcase)
    case ext
      when ".pdf"
        "<img src='#{view.present? ? view.asset_path("pdf16.png") : asset_path("pdf16.png")}'>"
      when ".doc", ".docx"
        "<img src='#{view.present? ? view.asset_path("word16.png") : asset_path("word16.png")}'>"
      when ".xls", ".xlsx"
        "<img src='#{view.present? ? view.asset_path("excel16.png") : asset_path("excel16.png")}'>"
      else
        return "<i class='fa fa-file-image-o' style='color:black;'></i>"
    end
  end

  def invoice_file_link_with_icon(invoice_file, color=nil, view=nil, show_file_name = true)
    file_size = view.present? ? view.number_to_human_size(invoice_file.size) : number_to_human_size(invoice_file.size)
    file_name = show_file_name ? invoice_file.name : ""
    if color.present?
      "<a href='#{invoice_file.url}' target='_blank' title='Size: #{file_size}' style='color:#{color};'>#{file_icon(invoice_file.name, view)} #{file_name}</a>".html_safe
    else
      "<a href='#{invoice_file.url}' target='_blank' title='Size: #{file_size}'>#{file_icon(invoice_file.name, view)} #{file_name}</a>".html_safe
    end
  end
end