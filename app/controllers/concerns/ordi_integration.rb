module OrdiIntegration
  extend ActiveSupport::Concern

  included do
    before_action :handle_embedded_mode
    helper_method :embedded_mode?
  end

  private

  def handle_embedded_mode
    # Set embedded mode from URL param
    if params[:embedded] == "true"
      session[:embedded_mode] = true
    elsif params[:embedded] == "false"
      session[:embedded_mode] = nil
    end

    # If accessing root URL directly (standalone), clear embedded mode
    # This detects when user navigates to Sure directly vs via iframe
    if request.path == "/" && !params[:embedded].present? && !request.referer&.include?("localhost:3000")
      session[:embedded_mode] = nil
    end
  end

  # Available in views and controllers to check current embed state
  def embedded_mode?
    session[:embedded_mode] == true
  end
end
