Rails.application.routes.draw do
  # devise actions
  #----------------------------------------------------------------------
  devise_for :users, controllers: { 
                                    registrations:  "users/registrations", 
                                    sessions:       "users/sessions", 
                                    confirmations:  "users/confirmations", 
                                    passwords:      "users/passwords" 
                                  }
  as :user do
    patch "/user/confirmation" => "confirmations#update", via: :patch, as: :update_user_confirmation
  end

  # root
  #----------------------------------------------------------------------
  root "home#index"

  # home pages
  #----------------------------------------------------------------------
  get "terms"           => "home#terms"
  get "privacy"         => "home#privacy"
  get "authorization"   => "home#authorization"
  get "session_expire"  => "home#session_expire"
  get "learn_more"      => "home#learn_more"

  # apis
  #----------------------------------------------------------------------
  get     "api/v1/get_defs"               => "api#get_defs"                       # for Site Event Logs API in Trial
  post    "api/v1/log"                    => "api#log"
  delete  "api/v1/rev"                    => "api#rev"
  get     "api/v1/dump"                   => "api#dump"
  get     "api/v1/get_logged_patient_ids" => "api#get_logged_patient_ids"

  match "/404" => "errors#error404", via: [:get, :post, :patch, :delete]
  
  # DASHBOARD
  #----------------------------------------------------------------------
  get "dashboard"       => "dashboard#index"

  namespace :dashboard do
    post  :update_status
    
    resources :sponsors,            except: [:show, :destroy]               # for Sponsor    
    resources :countries,           only:   :index                          # for Country
    resources :currencies,          except: [:show, :destroy]               # for Currency
    resources :users,               except: [:show, :destroy] do            # for User
      member do
        post  :send_invite                                                  # for VPD Admin Resend Invitation
      end
      collection do
        get   :trial_opts_for_vpd                                           # for ajax call to get trials with vpd
        get   :site_opts_for_trial                                          # for ajax call to get sites with trial
        get   :task_site_opts                                               # for ajax call to get sites with trial (in Tasks filter)
        get   :task_vpd_countries_opts                                      # for ajax call to get countries with trial (in Tasks filter)

        get   :user_info
        get   :profile
        match :update_profile, via: [:put, :patch]
        get   :todo_tasks
      end
    end
    get   "finance"                 => "finance#index"                      # for Finance
    match "save_finance"            => "finance#save_finance", via: [:post, :put, :patch]
    get   "show_finance"            => "finance#show_finance"               # for Finance of Account
    get   "payfile"                 => "payment#payfile"                    # for Payfile from system to tipalti
    get   "new_upload"              => "payment#new_upload"
    post  "reconfile"               => "payment#reconfile"                  # for Reconciliation file from tipalti to system

    # VPD
    #----------------------------------------------------------------------
    namespace :vpd do
      resources :vpds,                except: [:show, :destroy] do
        member do
          get   :trials, :configs, :reports                                 # for trials, config and reports in VPD
        end
      end

      scope ':vpd_id' do
        resources :users,             except: [:show, :destroy] do          # for VPD, Trial and Site Admins
          member do
            post :send_invite                                               # for VPD Admin Resend Invitation
          end
        end

        resources :countries,         only:   :index do                     # for VPD Country
          post  :update_status                                            
          get   :provinces                                                  # for ajax call to get provinces with country code
        end
        resources :sponsors,          only:   [:index, :new, :create] do    # for VPD Sponsor
          post  :update_status                                            
        end
        resources :currencies,        only:   [:index, :new, :create] do    # for VPD Currency
          post  :update_status
        end
        resources :mail_templates,    only:   [:index, :edit, :update]      # for VPD Mail Tempalte
        resources :ledger_categories, except: [:show, :destroy]             # for VPD Ledger Category
        get   "approvals"             => "approvers#approvals"              # for VPD Approval
        resources :approvers,         only:   [:index, :new, :create]       # for VPD Approver
        resources :events,            except: [:show, :destroy] do          # for VPD Event
          collection do  
            get :change_order                                               # for Vpd Event ordering
          end          
        end
        resources :reports,           except: [:edit, :update, :destroy]    # for VPD Report
      end
    end

    # TRIAL
    #----------------------------------------------------------------------
    namespace :trial do
      resources :trials,                except: [:index, :show, :destroy] do
        member do
          get :dashboard                                                  # for Trial Dashboard
          get :sites                                                      # for all sites in Trial with trial_id
          get :should_forecast                                            # for get Trial should_forecast status
          get :sites_list_by_currency                                     # to get all sites with schedules having a vpd_currency
        end
      end

      scope ':trial_id' do
        resources :users,               except: [:show, :destroy] do 
          member do
            post :send_invite                                             # for Trial Admin Resend Invitation
          end
        end

        get   "new_upload"              => "bulk_site#new_upload"
        get   "template"                => "bulk_site#template"
        post  "upload_config"           => "bulk_site#upload_config"

        get   "forecastings"            => "forecastings#forecastings"        # for Trial Forecasting
        match "save_forecastings"       => "forecastings#save_forecastings", via: [:post, :put, :patch]
        post  "create_forecast"         => "forecastings#create_forecast"     # Create Forecast
        get   "sites"                   => "forecastings#sites_for_country"
        get   "report"                  => "report#report"                

        get   "balance"                 => "accounts#balance"                 # for Trial Account Balance
        get   "api_support"             => "api#api_support"                  # for Trial API Support

        resources :events,              except: [:show, :destroy] do          # for Trial Event
          collection do  
            get :change_order                                                 # for Vpd Event ordering
          end
        end
        resources :schedules,           except: [:show, :destroy] do          # for Trial Template Schedules
          collection do
            get :schedules_by_currency
          end
        end

        resources :entries,             except: :show                         # for Trial Payment Entries
        resources :passthrough_budgets, except: :show                         # for Trial Passthrough Budget Entries

        resources :site_events,         except: :show do                      # for Site Event(Event Log)
          post  :update_status
          collection do 
            get "site_options"
          end
        end
      end
    end
    
    # SITE
    #----------------------------------------------------------------------
    namespace :site do
      resources :sites,                 except: [:index, :show, :destroy] do
        member do
          get :dashboard                                                      # for Site Dashboard
        end
      end

      scope ':site_id' do
        resources :users,               except: [:show, :destroy] do          # for Site User
          member do
            post :send_invite                                                 # for Site User Resend Invitation
          end
        end

        resources :events,              except: :show do                      # for Site Event(Event Log)
          collection do
            get :patient_ids
          end          
        end

        get   "schedule"                => "schedules#schedule"               # for Site Payment Schedule
        match "save_schedule"           => "schedules#save_schedule", via: :post
        get   "new_authenticate"        => "schedules#new_authenticate"
        post  "authenticate"            => "schedules#authenticate"

        get   "payment_information"     => "payment#payment_information"            # for Site Payment Information (with Tipalti)
        resources :payment_infos,       except: [:new, :edit, :index, :show, :destroy] do  # for Site Payment Information (without Tipalti)
          collection do
            get :edit_payment_info
          end
        end

        resources :entries,             except: :show                         # for Site Payment Entries
        get   "statement"               => "transactions#statement"           # for Site Statement
        get   "holdback"                => "transactions#new_holdback"        # for Holdback Release
        post  "holdback"                => "transactions#create_holdback"     # for Holdback Release
        get   "withholding"             => "transactions#new_withholding"     # for Withholding Release
        post  "withholding"             => "transactions#create_withholding"  # for Withholding Release

        resources :invoices,            except: :destroy do                   # for Site Invoices
          collection do
            post "switch_transaction"                                         # for Switching transaction hidden or not
          end
        end
        resources :passthrough_budgets, except: :show                         # for Site Passthrough Budget Entries
        resources :passthroughs,        except: [:show, :destroy]             # for Site Passthroughs
      end
    end
  end  
end