class Users::ConfirmationsController < Devise::ConfirmationsController
  def show
    self.resource = resource_class.confirm_by_token(params[:confirmation_token])

    if resource.errors.empty?
      set_flash_message!(:notice, :confirmed)
      sign_in(resource)
      redirect_to after_confirmation_path_for(resource_name, resource)
    else
      redirect_to new_confirmation_path(resource_name),
                  alert: resource.errors.full_messages.to_sentence
    end
  end

  protected

  def after_confirmation_path_for(_resource_name, _resource)
    root_path
  end
end
