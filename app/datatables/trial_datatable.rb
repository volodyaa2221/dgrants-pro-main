class TrialDatatable
  delegate :params, :h, :link_to, :number_to_currency, to: :@view

  def initialize(view, user, vpd)
    @view = view
    @user = user
    @vpd = vpd
  end

  def as_json(options = {})
    {
      sEcho: params[:sEcho].to_i,
      iTotalRecords: trials.count,
      iTotalDisplayRecords: trials.total_entries,
      aaData: data.compact
    }
  end

private

  def data
    if @vpd.blank? && @user.super_admin?
      trials.map do |trial|
        [ 
          link_to(trial.trial_id.truncate(12), "/dashboard/trial/trials/#{trial.id}/dashboard", title: trial.trial_id),
          link_to(trial.title.truncate(44), "/dashboard/trial/trials/#{trial.id}/dashboard", title: trial.title),
          link_to(trial.vpd.name.truncate(12), "/dashboard/vpd/vpds/#{trial.vpd.id}/trials", title: trial.vpd.name),
          link_to(trial.sponsor_name.truncate(15), "#", title: trial.sponsor_name),
          trial.role_name_by_user(@user),
          "<div class='btn-group btn-toggle' data-update-url='/dashboard/update_status'>
            <button class='btn btn-xs #{trial.status==1 ? 'btn-success active' : 'btn-default'}' style='padding:1px 5px' data-id='#{trial.id}' data-status='1' data-type='#{trial.class.name}'>Yes</button>
            <button class='btn btn-xs #{trial.status==0 ? 'btn-warning active' : 'btn-default'}' style='padding:1px 5px' data-id='#{trial.id}' data-status='0' data-type='#{trial.class.name}'>No</button>
          </div>".html_safe,
          "row_#{trial.id}"
        ]
      end
    elsif @vpd.present? && @user.vpd_level_user?
      trials.map do |trial|
        [ 
          link_to(trial.trial_id.truncate(12), "/dashboard/trial/trials/#{trial.id}/dashboard?vpd_id=#{@vpd.id}", title:trial.trial_id),
          link_to(trial.title.truncate(44), "/dashboard/trial/trials/#{trial.id}/dashboard?vpd_id=#{@vpd.id}", title:trial.title),
          link_to(trial.sponsor_name.truncate(15), "#", title:trial.sponsor_name),
          trial.role_name_by_user(@user),
          "<div class='btn-group btn-toggle' data-update-url='/dashboard/update_status'>
            <button class='btn btn-xs #{trial.status==1 ? 'btn-success active' : 'btn-default'}' style='padding:1px 5px' data-id='#{trial.id}' data-status='1' data-type='#{trial.class.name}'>Yes</button>
            <button class='btn btn-xs #{trial.status==0 ? 'btn-warning active' : 'btn-default'}' style='padding:1px 5px' data-id='#{trial.id}' data-status='0' data-type='#{trial.class.name}'>No</button>
          </div>".html_safe,
          "row_#{trial.id}"
        ]
      end
    else
      trials.map do |trial|
        trial_id = ""
        trial_name = ""
        if @user.trial_level_user?(trial)
          trial_id   = link_to(trial.trial_id.truncate(12), "/dashboard/trial/trials/#{trial.id}/dashboard", title:trial.trial_id)
          trial_name = link_to(trial.title.truncate(55), "/dashboard/trial/trials/#{trial.id}/dashboard", title:trial.title)
        else
          user_sites = @user.sites_of_trial(trial)
          if user_sites.count > 1
            trial_id   = link_to(trial.trial_id.truncate(12), "/dashboard/trial/trials/#{trial.id}/sites", title:trial.trial_id)
            trial_name = link_to(trial.title.truncate(55), "/dashboard/trial/trials/#{trial.id}/sites", title:trial.title)
          else
            site = user_sites.first
            if site.present?
              trial_id   = link_to(trial.trial_id.truncate(12), "/dashboard/site/sites/#{site.id}/dashboard", title:trial.trial_id)
              trial_name = link_to(trial.title.truncate(55), "/dashboard/site/sites/#{site.id}/dashboard", title:trial.title)
            end
          end
        end
        switch_label = "<div class='btn-group btn-toggle' data-update-url='/dashboard/update_status'>
                    <button class='btn btn-xs #{trial.status==1 ? 'btn-success active' : 'btn-default'}' style='padding:1px 5px' data-id='#{trial.id}' data-status='1' data-type='#{trial.class.name}'>Yes</button>
                    <button class='btn btn-xs #{trial.status==0 ? 'btn-warning active' : 'btn-default'}' style='padding:1px 5px' data-id='#{trial.id}' data-status='0' data-type='#{trial.class.name}'>No</button>
                  </div>".html_safe
        status_label = trial.status == 1 ? "Yes" : "No"
        [
          trial_id,
          trial_name,
          link_to(trial.sponsor_name.truncate(15), "#", title:trial.sponsor_name),
          trial.role_name_by_user(@user),
          @user.trial_editable?(trial) ? switch_label : status_label,
          "row_#{trial.id}"
        ]
      end
    end
  end

  def trials
    @trials ||= fetch_trials
  end

  def fetch_trials
    status = params[:show_option].strip == "Include disabled"  ?  false : true
    search = params[:sSearch].present? ? params[:sSearch] : nil

    trials = []
    if search.present?
      if @vpd.present?
        where_case = "(trial_id LIKE :search_param OR title LIKE :search_param) AND vpd_id = #{@vpd.id}"
        trials = status ? Trial.where(where_case, search_param: "%#{params[:sSearch]}%")
                        : Trial.where("#{where_case} AND status = 1", search_param: "%#{params[:sSearch]}%")
      else
        trial_ids = @user.trials(include_disabled=status).map(&:id)
        if trial_ids.present?
          trials = Trial.where("(trial_id LIKE :search_param OR title LIKE :search_param) AND id IN (#{trial_ids.join(",")})", 
                                search_param: "%#{params[:sSearch]}%")
        end
      end
    else
      if @vpd.present?
        trials = status ? @vpd.trials : Trial.where(vpd: @vpd, status: 1)
      else
        trials = @user.trials(include_disabled=status)
      end
    end

    trials.order("#{sort_column} #{sort_direction}").paginate(page: page, :per_page => per_page)
  end

  def page
    params[:iDisplayStart].to_i/per_page + 1
  end

  def per_page
    params[:iDisplayLength].to_i > 0 ? params[:iDisplayLength].to_i : 15
  end

  def sort_column
    columns = %w[trial_id title]
    columns[params[:iSortCol_0].to_i]
  end

  def sort_direction
    params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end
end