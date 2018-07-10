class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  after_action :allow_iframe
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    # Permit the `subscribe_newsletter` parameter along with the other
    # sign up parameters.
    devise_parameter_sanitizer.permit(:sign_up, keys: [:nickname, :token])
  end

  private

  def allow_iframe
    response.headers.except! 'X-Frame-Options'
  end
end
