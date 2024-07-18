module ApplicationHelper

  # Devise related methods
  #----------------------------------------------------------------------
  def resource_name
    :user    
  end

  def resource
    @resource ||= User.new    
  end

  def devise_mapping
    @devise_mapping ||= Devise.mappings[:user]
  end

  # Utility methods
  #----------------------------------------------------------------------
  def dev?;   Rails.env == "development"; end
  def prod?;  Rails.env == "production";  end
  def stage?; Rails.env == "staging";     end
  def test?;  Rails.new == "test";        end

  def ajax_url_suffix; "?type=ajax"       end
  def to_b(string);    string == "true"   end

end