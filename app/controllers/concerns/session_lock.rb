module SessionLock
  extend ActiveSupport::Concern

  included do
    before_action :redirect_to_lock_if_locked, if: :lock_gate_applies?
  end

  private
    def redirect_to_lock_if_locked
      return unless session[:session_locked]
      redirect_to lock_path
    end

    def lock_gate_applies?
      return false if controller_path == "locks"
      authenticated?
    end
end
