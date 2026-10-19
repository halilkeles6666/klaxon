class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :current_user

  # A stale link to a deleted incident should not blow up with a 404 page.
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  private

  def current_user
    Current.user
  end

  def record_not_found
    redirect_to root_path, alert: "Kayıt bulunamadı — silinmiş ya da taşınmış olabilir."
  end
end
