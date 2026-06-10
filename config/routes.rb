Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end

  # Public web — City Board
  get '/stpete', to: 'cities#show', defaults: { city_slug: 'stpete' }, as: :city_board
  get '/host-with-us', to: 'pages#host_inquiry', as: :host_inquiry

  # Attendee profile / settings
  get  '/profile', to: 'profiles#show', as: :user_profile

  # Public web — Totem Board + Host Page
  get  "/h/:host_slug",                               to: "hosts#show",                        as: :host_page
  get  "/about",                                      to: "pages#about",                       as: :about
  get  "/t/:slug",                                    to: "totems/boards#show",                as: :totem_board
  get  "/t/:slug/e/:event_slug",                      to: "totems/events#show",                as: :totem_event
  get  "/t/:slug/e/:event_slug/calendar.ics",         to: "totems/events#calendar",            as: :event_calendar
  post "/t/:slug/e/:event_slug/check_ins",            to: "totems/check_ins#create",           as: :totem_event_check_ins
  get  "/t/:slug/e/:event_slug/check_ins/success",   to: "totems/check_ins#success",          as: :totem_event_check_in_success
  post "/empty_totem_email_captures",                 to: "empty_totem_email_captures#create", as: :empty_totem_email_captures

  # Public web — Bulletin Board (standalone, anonymous, reached via QR)
  get  "/stpeteboards",            to: "bulletin_boards#index",  as: :bulletin_boards_directory
  get  "/board/:totem_slug",       to: "bulletin_boards#show",   as: :bulletin_board
  post "/board/:totem_slug/posts", to: "bulletin_boards#create", as: :bulletin_board_posts

  # Web totem favorite toggle and host follow (session auth)
  resources :totem_favorites, only: [:create, :destroy]
  resources :host_follows,    only: [:create, :destroy]

  # Client-side analytics proxy
  post "/analytics/track", to: "analytics#track"

  # Regular user auth (web, magic link)
  get    "/sign_up",           to: "auth/user_registrations#new",    as: :sign_up
  post   "/sign_up",           to: "auth/user_registrations#create"
  get    "/sign_in",               to: "auth/user_sessions#new",            as: :sign_in
  post   "/sign_in",               to: "auth/user_sessions#create"
  get    "/sign_in/magic_link",    to: "auth/user_sessions#new_magic_link", as: :sign_in_magic_link
  delete "/sign_out",          to: "auth/user_sessions#destroy",     as: :sign_out
  get    "/magic_link/verify", to: "auth/user_magic_links#verify",   as: :verify_magic_link

  # Google OAuth (GET /auth/google_oauth2 is handled by OmniAuth middleware)
  get "/auth/google_oauth2/callback", to: "auth/sessions#google_callback"

  root to: redirect("/stpete")
  get "/admin", to: redirect("/admin/totems"), as: :admin_root

  # Host dashboard (Chunk 4)
  get "/host", to: redirect("/host/dashboard"), as: :host_root
  namespace :host do
    get "dashboard", to: "dashboard#show", as: :dashboard
    get "insights/:event_slug", to: "insights#show", as: :insights
    resources :events do
      member { patch :cancel, to: "events/cancellations#update" }
    end
    # AI description assist (JSON, no persistence) — backs description_assist Stimulus controller.
    post "events/description/enhance",   to: "events/descriptions#enhance",   as: :event_description_enhance
    post "events/description/summarize", to: "events/descriptions#summarize", as: :event_description_summarize
    get   "profile",          to: "profiles#edit",             as: :profile
    patch "profile",          to: "profiles#update"
    get   "profile/password", to: "profiles/passwords#edit",   as: :profile_password
    patch "profile/password", to: "profiles/passwords#update"
    resources :totems, only: [:index]
  end

  # Clean URL in production: host.signalfire.live/insights/:event_slug
  constraints(subdomain: "host") do
    scope module: :host do
      get "insights/:event_slug", to: "insights#show"
    end
  end

  # Host auth
  scope "/host", as: :host do
    get    "login",          to: "auth/host/sessions#new",          as: :login
    post   "login",          to: "auth/host/sessions#create"
    delete "logout",         to: "auth/host/sessions#destroy",      as: :logout
    get    "accept_invite",  to: "auth/host/invitations#edit",      as: :accept_invite
    patch  "accept_invite",  to: "auth/host/invitations#update"
    get    "magic_link",        to: "auth/host/magic_links#new",    as: :magic_link
    post   "magic_link",        to: "auth/host/magic_links#create"
    get    "magic_link/sent",   to: "auth/host/magic_links#sent",   as: :magic_link_sent
    get    "magic_link/verify", to: "auth/host/magic_links#verify", as: :magic_link_verify
  end

  # Admin auth
  scope "/admin", as: :admin do
    get    "login",  to: "auth/admin/sessions#new",    as: :login
    post   "login",  to: "auth/admin/sessions#create"
    delete "logout", to: "auth/admin/sessions#destroy", as: :logout
  end

  # Admin console
  namespace :admin do
    resources :totems do
      member do
        get :qr
        get :board_qr
      end
    end
    resources :hosts, only: [:index, :new, :create, :edit, :update, :destroy] do
      member do
        patch :deactivate
        patch :activate
      end
    end
    resources :events do
      member { patch :publish }
    end
    resources :bulletin_posts, only: [:index, :edit, :update, :destroy] do
      member do
        patch :approve
      end
    end
    # Admin-only AI "polish" for bulletin descriptions (summarize keeps the ≤160 cap).
    post "bulletin_posts/description/summarize", to: "bulletin_posts/descriptions#summarize", as: :bulletin_post_description_summarize

    # AI Event Scout (2A): find real events via web search → review queue → promote.
    resources :scouts, only: [:new, :create, :show] do
      member { get :status }
    end
    resources :scout_candidates, only: [] do
      member do
        post :add_to_totem
        post :add_to_bulletin
        post :ignore
      end
    end
  end

  # Mobile API
  namespace :api do
    namespace :v1 do
      namespace :auth do
        post "sign_up",  to: "registrations#create"
        post "sign_in",  to: "sessions#create"
        delete "sign_out", to: "sessions#destroy"
        post "google",   to: "google#create"
        post "apple",    to: "apple#create"
      end

      # Public — optional auth
      resources :totems, param: :slug, only: [:show] do
        resources :events, param: :event_slug, only: [:show] do
          resources :anonymous_check_ins, only: [:create]
        end
        resources :email_captures, only: [:create]
      end

      # Authenticated check-in by event ID
      resources :events, only: [] do
        resources :check_ins, only: [:create]
      end

      # Public host page — optional auth
      get "hosts/:host_slug", to: "hosts#show"

      # Authenticated follow management
      resources :host_follows, only: [:create, :destroy, :update]
      resources :totem_favorites, only: [:create, :destroy, :update]

      # Authenticated home feed
      get "home", to: "home#index"

      # Authenticated user profile
      resource :me, controller: "me", only: [:show, :update, :destroy] do
        get  :check_ins
        get  :subscriptions
        post :push_token
      end
    end
  end
end
